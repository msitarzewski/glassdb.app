//
//  SSHTunnelManager.swift
//  GlassDBKit
//
//  SSH tunnel for remote database connections via Citadel/swift-nio-ssh.
//  Establishes an SSH connection, then creates a local TCP listener
//  that forwards traffic through a DirectTCPIP channel to the remote
//  database host.
//

import Foundation
@preconcurrency import Citadel
import Crypto
import NIOCore
import NIOPosix
import NIOSSH
import Logging

public struct SSHTunnelConfig: Sendable {
    public let sshHost: String
    public let sshPort: Int
    public let sshUsername: String
    public let sshPassword: String?
    public let sshPrivateKey: String?
    public let sshKeyPassphrase: String?
    public let remoteHost: String
    public let remotePort: Int

    public init(
        sshHost: String,
        sshPort: Int = 22,
        sshUsername: String,
        sshPassword: String? = nil,
        sshPrivateKey: String? = nil,
        sshKeyPassphrase: String? = nil,
        remoteHost: String = "127.0.0.1",
        remotePort: Int = 3306
    ) {
        self.sshHost = sshHost
        self.sshPort = sshPort
        self.sshUsername = sshUsername
        self.sshPassword = sshPassword
        self.sshPrivateKey = sshPrivateKey
        self.sshKeyPassphrase = sshKeyPassphrase
        self.remoteHost = remoteHost
        self.remotePort = remotePort
    }
}

public final class SSHTunnelManager: Sendable {
    private let eventLoopGroup: EventLoopGroup

    public init() {
        self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    }

    /// Establishes an SSH tunnel and returns the local port to connect to.
    /// The MySQL client connects to 127.0.0.1:<localPort> which forwards
    /// through the SSH tunnel to remoteHost:remotePort.
    public func establish(config: SSHTunnelConfig) async throws -> SSHTunnel {
        let authMethod: SSHAuthenticationMethod
        if let privateKey = config.sshPrivateKey {
            let passphrase = config.sshKeyPassphrase?.data(using: .utf8)

            if privateKey.hasPrefix("SECURE_ENCLAVE_P256:") {
                // Secure Enclave P256 — raw key bytes encoded as base64 after the prefix
                let base64 = String(privateKey.dropFirst("SECURE_ENCLAVE_P256:".count))
                guard let keyData = Data(base64Encoded: base64) else {
                    throw SSHTunnelError.noAuthMethod
                }
                let p256Key = try P256.Signing.PrivateKey(rawRepresentation: keyData)
                authMethod = .p256(username: config.sshUsername, privateKey: p256Key)
            } else if privateKey.contains("BEGIN RSA PRIVATE KEY") || privateKey.contains("BEGIN RSA PRIVATE") {
                // RSA PEM key
                let rsaKey = try Insecure.RSA.PrivateKey(
                    sshRsa: privateKey,
                    decryptionKey: passphrase
                )
                authMethod = .rsa(username: config.sshUsername, privateKey: rsaKey)
            } else {
                // Default: try Ed25519 (OpenSSH format or PEM)
                let ed25519Key = try Curve25519.Signing.PrivateKey(
                    sshEd25519: privateKey,
                    decryptionKey: passphrase
                )
                authMethod = .ed25519(username: config.sshUsername, privateKey: ed25519Key)
            }
        } else if let password = config.sshPassword {
            authMethod = .passwordBased(username: config.sshUsername, password: password)
        } else {
            throw SSHTunnelError.noAuthMethod
        }

        // Try modern algorithms first, fall back to .all for legacy servers
        // (matches glas.sh pattern — older OpenSSH needs DH Group 14 / AES128-CTR / RSA)
        let client: SSHClient
        do {
            client = try await SSHClient.connect(
                host: config.sshHost,
                port: config.sshPort,
                authenticationMethod: authMethod,
                hostKeyValidator: .acceptAnything(),
                reconnect: .never,
                algorithms: SSHAlgorithms()
            )
        } catch {
            if Self.isKeyExchangeNegotiationFailure(error) {
                client = try await SSHClient.connect(
                    host: config.sshHost,
                    port: config.sshPort,
                    authenticationMethod: authMethod,
                    hostKeyValidator: .acceptAnything(),
                    reconnect: .never,
                    algorithms: .all
                )
            } else {
                throw error
            }
        }

        // Bind a local TCP server on a random port
        let bootstrap = ServerBootstrap(group: eventLoopGroup)
            .serverChannelOption(.socketOption(.so_reuseaddr), value: 1)
            .childChannelInitializer { childChannel in
                // For each incoming local connection, create a DirectTCPIP
                // channel through SSH and pipe the data
                childChannel.eventLoop.makeCompletedFuture {
                    let forwarder = LocalToSSHForwarder(
                        sshClient: client,
                        remoteHost: config.remoteHost,
                        remotePort: config.remotePort
                    )
                    try childChannel.pipeline.syncOperations.addHandler(forwarder)
                }
            }

        let serverChannel = try await bootstrap.bind(host: "127.0.0.1", port: 0).get()

        guard let localAddress = serverChannel.localAddress,
              let localPort = localAddress.port else {
            throw SSHTunnelError.bindFailed
        }

        return SSHTunnel(
            localPort: localPort,
            serverChannel: serverChannel,
            sshClient: client
        )
    }

    /// Detect key exchange negotiation failures to trigger legacy algorithm fallback.
    /// Adapted from glas.sh SSHConnection.isKeyExchangeNegotiationFailure.
    private static func isKeyExchangeNegotiationFailure(_ error: Error) -> Bool {
        let raw = String(describing: error)
        return raw.localizedCaseInsensitiveContains("keyexchangenegotiationfailure")
            || raw.localizedCaseInsensitiveContains("key exchange negotiation failure")
    }

    deinit {
        try? eventLoopGroup.syncShutdownGracefully()
    }
}

public final class SSHTunnel: @unchecked Sendable {
    public let localPort: Int
    private let serverChannel: Channel
    private let sshClient: SSHClient

    init(localPort: Int, serverChannel: Channel, sshClient: SSHClient) {
        self.localPort = localPort
        self.serverChannel = serverChannel
        self.sshClient = sshClient
    }

    public func close() async throws {
        if serverChannel.isActive {
            try await serverChannel.close()
        }
        try await sshClient.close()
    }
}

/// NIO ChannelHandler that forwards local TCP data through an SSH DirectTCPIP channel.
/// Buffers incoming data until the SSH channel is established, then flushes the buffer
/// and forwards subsequent reads directly.
private final class LocalToSSHForwarder: ChannelInboundHandler, @unchecked Sendable {
    typealias InboundIn = ByteBuffer
    typealias OutboundOut = ByteBuffer

    private let sshClient: SSHClient
    private let remoteHost: String
    private let remotePort: Int
    private var sshChannel: Channel?
    private var localChannel: Channel?
    private var pendingBuffers: [ByteBuffer] = []

    init(sshClient: SSHClient, remoteHost: String, remotePort: Int) {
        self.sshClient = sshClient
        self.remoteHost = remoteHost
        self.remotePort = remotePort
    }

    func channelActive(context: ChannelHandlerContext) {
        let localChannel = context.channel
        self.localChannel = localChannel
        let remoteHost = self.remoteHost
        let remotePort = self.remotePort

        // Open DirectTCPIP channel to remote database.
        // Extract all needed values before the Task to avoid capturing non-Sendable context.
        // Data arriving before the channel is ready is buffered in pendingBuffers.
        let sshClient = self.sshClient
        Task { [weak self] in
            do {
                let channel = try await sshClient.createDirectTCPIPChannel(
                    using: .init(
                        targetHost: remoteHost,
                        targetPort: remotePort,
                        originatorAddress: .init(ipAddress: "127.0.0.1", port: 0)
                    )
                ) { channel in
                    channel.eventLoop.makeCompletedFuture {
                        let backForwarder = SSHToLocalForwarder(localChannel: localChannel)
                        try channel.pipeline.syncOperations.addHandler(backForwarder)
                    }
                }
                // Hop back to the local channel's event loop to avoid racing with channelRead
                localChannel.eventLoop.execute {
                    guard let self else { return }
                    self.sshChannel = channel
                    // Flush anything that arrived while we were connecting
                    for buffer in self.pendingBuffers {
                        channel.writeAndFlush(buffer, promise: nil)
                    }
                    self.pendingBuffers.removeAll()
                }
            } catch {
                localChannel.pipeline.fireErrorCaught(error)
                localChannel.close(promise: nil)
            }
        }
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let buffer = unwrapInboundIn(data)
        // Forward local data to SSH channel as raw ByteBuffer —
        // Citadel's DataToBufferCodec wraps it in SSHChannelData for us
        if let sshChannel = sshChannel {
            sshChannel.writeAndFlush(buffer, promise: nil)
        } else {
            // SSH channel not ready yet — buffer until it is
            pendingBuffers.append(buffer)
        }
    }

    func channelInactive(context: ChannelHandlerContext) {
        sshChannel?.close(promise: nil)
        pendingBuffers.removeAll()
    }

    func errorCaught(context: ChannelHandlerContext, error: Error) {
        pendingBuffers.removeAll()
        context.close(promise: nil)
    }
}

/// NIO ChannelHandler that forwards SSH channel data back to the local TCP connection.
/// Receives raw ByteBuffer because Citadel's DataToBufferCodec already unwraps
/// SSHChannelData before this handler in the pipeline.
private final class SSHToLocalForwarder: ChannelInboundHandler, @unchecked Sendable {
    typealias InboundIn = ByteBuffer

    private let localChannel: Channel

    init(localChannel: Channel) {
        self.localChannel = localChannel
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let buffer = unwrapInboundIn(data)
        localChannel.writeAndFlush(buffer, promise: nil)
    }

    func channelInactive(context: ChannelHandlerContext) {
        localChannel.close(promise: nil)
    }
}

public enum SSHTunnelError: Error, LocalizedError {
    case noAuthMethod
    case bindFailed
    case tunnelClosed

    public var errorDescription: String? {
        switch self {
        case .noAuthMethod:
            return "No SSH authentication method provided (password or key required)."
        case .bindFailed:
            return "Failed to bind local tunnel port."
        case .tunnelClosed:
            return "SSH tunnel was closed unexpectedly."
        }
    }
}
