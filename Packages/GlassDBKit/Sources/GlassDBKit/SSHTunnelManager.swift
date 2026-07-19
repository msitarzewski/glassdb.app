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
@preconcurrency import NIOSSH
import Logging
import Synchronization

public enum SSHHostKeyChallengeReason: String, Sendable, Hashable {
    case unknown
    case changed
}

public struct SSHHostKeyChallenge: Sendable, Hashable {
    public let host: String
    public let port: Int
    public let algorithm: String
    public let fingerprintSHA256: String
    /// Complete SSH wire-format host key data, suitable for PinnedSSHHostKey.
    public let publicKeyData: Data
    public let reason: SSHHostKeyChallengeReason
}

public struct SSHHostKeyTrustRequiredError: Error, LocalizedError, Sendable {
    public let challenge: SSHHostKeyChallenge

    public var errorDescription: String? {
        switch challenge.reason {
        case .unknown:
            return "Verify the first-use SSH host key for \(challenge.host):\(challenge.port) (\(challenge.algorithm), \(challenge.fingerprintSHA256))."
        case .changed:
            return "The SSH host key for \(challenge.host):\(challenge.port) changed. Connection was blocked (\(challenge.algorithm), \(challenge.fingerprintSHA256))."
        }
    }
}

public enum SSHAlgorithmPolicy: Sendable, Hashable {
    /// Current swift-nio-ssh defaults only.
    case modernOnly
}

public enum SSHPrivateKeyAlgorithm: String, Sendable, Hashable {
    case rsa
    case ed25519
    case secureEnclaveP256
}

public struct SSHTunnelConfig: Sendable {
    public let sshHost: String
    public let sshPort: Int
    public let sshUsername: String
    public let sshPassword: String?
    public let sshPrivateKey: String?
    public let sshKeyPassphrase: String?
    public let remoteHost: String
    public let remotePort: Int
    /// Previously confirmed complete SSH wire-format host keys for sshHost:sshPort.
    public let trustedHostKeys: Set<Data>
    public let algorithmPolicy: SSHAlgorithmPolicy

    public init(
        sshHost: String,
        sshPort: Int = 22,
        sshUsername: String,
        sshPassword: String? = nil,
        sshPrivateKey: String? = nil,
        sshKeyPassphrase: String? = nil,
        remoteHost: String = "127.0.0.1",
        remotePort: Int = 3306,
        trustedHostKeys: Set<Data> = [],
        algorithmPolicy: SSHAlgorithmPolicy = .modernOnly
    ) {
        self.sshHost = sshHost
        self.sshPort = sshPort
        self.sshUsername = sshUsername
        self.sshPassword = sshPassword
        self.sshPrivateKey = sshPrivateKey
        self.sshKeyPassphrase = sshKeyPassphrase
        self.remoteHost = remoteHost
        self.remotePort = remotePort
        self.trustedHostKeys = trustedHostKeys
        self.algorithmPolicy = algorithmPolicy
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
        guard !config.sshHost.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !config.sshUsername.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !config.remoteHost.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              (1...65_535).contains(config.sshPort),
              (1...65_535).contains(config.remotePort) else {
            throw SSHTunnelError.invalidConfiguration
        }

        let authMethod: SSHAuthenticationMethod
        if let privateKey = config.sshPrivateKey {
            authMethod = try Self.authenticationMethod(
                username: config.sshUsername,
                privateKey: privateKey,
                passphrase: config.sshKeyPassphrase
            )
        } else if let password = config.sshPassword, !password.isEmpty {
            authMethod = .passwordBased(username: config.sshUsername, password: password)
        } else {
            throw SSHTunnelError.noAuthMethod
        }

        let challengeBox = SSHHostKeyChallengeBox()
        let hostKeyValidator = PinnedSSHHostKeyValidator(
            host: config.sshHost,
            port: config.sshPort,
            trustedKeys: config.trustedHostKeys,
            challengeBox: challengeBox
        )
        let client: SSHClient
        do {
            client = try await SSHClient.connect(
                host: config.sshHost,
                port: config.sshPort,
                authenticationMethod: authMethod,
                hostKeyValidator: .custom(hostKeyValidator),
                reconnect: .never,
                algorithms: Self.algorithms(for: config.algorithmPolicy)
            )
        } catch {
            if let challenge = challengeBox.value.withLock({ $0 }) {
                throw SSHHostKeyTrustRequiredError(challenge: challenge)
            }
            throw error
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

    private static func algorithms(for policy: SSHAlgorithmPolicy) -> SSHAlgorithms {
        switch policy {
        case .modernOnly:
            return SSHAlgorithms()
        }
    }

    public static func detectPrivateKeyAlgorithm(from privateKey: String) throws -> SSHPrivateKeyAlgorithm {
        let normalizedKey = normalizedPrivateKey(privateKey)
        if normalizedKey.hasPrefix("SECURE_ENCLAVE_P256:") {
            return .secureEnclaveP256
        }
        if normalizedKey.contains("-----BEGIN RSA PRIVATE KEY-----")
            || normalizedKey.contains("-----BEGIN PRIVATE KEY-----") {
            throw SSHTunnelError.unsupportedPrivateKeyFormat
        }

        do {
            let keyType = try SSHKeyDetection.detectPrivateKeyType(from: normalizedKey)
            if keyType == .rsa {
                return .rsa
            }
            if keyType == .ed25519 {
                return .ed25519
            }
            throw SSHTunnelError.unsupportedPrivateKeyAlgorithm(keyType.description)
        } catch let error as SSHTunnelError {
            throw error
        } catch {
            throw SSHTunnelError.invalidPrivateKey
        }
    }

    static func authenticationMethod(
        username: String,
        privateKey: String,
        passphrase: String?
    ) throws -> SSHAuthenticationMethod {
        let normalizedKey = normalizedPrivateKey(privateKey)
        do {
            switch try detectPrivateKeyAlgorithm(from: normalizedKey) {
            case .secureEnclaveP256:
                let base64 = String(normalizedKey.dropFirst("SECURE_ENCLAVE_P256:".count))
                guard let keyData = Data(base64Encoded: base64) else {
                    throw SSHTunnelError.invalidPrivateKey
                }
                let key = try P256.Signing.PrivateKey(rawRepresentation: keyData)
                return .p256(username: username, privateKey: key)
            case .rsa:
                let key = try Insecure.RSA.PrivateKey(
                    sshRsa: normalizedKey,
                    decryptionKey: passphrase?.data(using: .utf8)
                )
                return .rsa(username: username, privateKey: key)
            case .ed25519:
                let key = try Curve25519.Signing.PrivateKey(
                    sshEd25519: normalizedKey,
                    decryptionKey: passphrase?.data(using: .utf8)
                )
                return .ed25519(username: username, privateKey: key)
            }
        } catch let error as SSHTunnelError {
            throw error
        } catch {
            throw SSHTunnelError.invalidPrivateKey
        }
    }

    private static func normalizedPrivateKey(_ privateKey: String) -> String {
        privateKey
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    deinit {
        try? eventLoopGroup.syncShutdownGracefully()
    }
}

private final class SSHHostKeyChallengeBox: Sendable {
    let value = Mutex<SSHHostKeyChallenge?>(nil)
}

private final class PinnedSSHHostKeyValidator: NIOSSHClientServerAuthenticationDelegate, Sendable {
    private let host: String
    private let port: Int
    private let trustedKeys: Set<Data>
    private let challengeBox: SSHHostKeyChallengeBox

    init(
        host: String,
        port: Int,
        trustedKeys: Set<Data>,
        challengeBox: SSHHostKeyChallengeBox
    ) {
        self.host = host.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        self.port = port
        self.trustedKeys = trustedKeys
        self.challengeBox = challengeBox
    }

    func validateHostKey(
        hostKey: NIOSSHPublicKey,
        validationCompletePromise: EventLoopPromise<Void>
    ) {
        var buffer = ByteBufferAllocator().buffer(capacity: 512)
        _ = hostKey.write(to: &buffer)
        let keyData = Data(buffer.readableBytesView)
        guard let challenge = SSHHostKeyTrustPolicy.challenge(
            for: keyData,
            host: host,
            port: port,
            trustedKeys: trustedKeys
        ) else {
            validationCompletePromise.succeed(())
            return
        }
        challengeBox.value.withLock { $0 = challenge }
        validationCompletePromise.fail(SSHHostKeyTrustRequiredError(challenge: challenge))
    }
}

enum SSHHostKeyTrustPolicy {
    static func challenge(
        for keyData: Data,
        host: String,
        port: Int,
        trustedKeys: Set<Data>
    ) -> SSHHostKeyChallenge? {
        guard !trustedKeys.contains(keyData) else { return nil }
        return SSHHostKeyChallenge(
            host: host.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            port: port,
            algorithm: algorithm(from: keyData),
            fingerprintSHA256: fingerprint(for: keyData),
            publicKeyData: keyData,
            reason: trustedKeys.isEmpty ? .unknown : .changed
        )
    }

    private static func algorithm(from data: Data) -> String {
        guard data.count >= 4 else { return "unknown" }
        let length = data.prefix(4).reduce(0) { ($0 << 8) | Int($1) }
        guard length > 0, data.count >= 4 + length else { return "unknown" }
        return String(data: data[4..<(4 + length)], encoding: .utf8) ?? "unknown"
    }

    private static func fingerprint(for data: Data) -> String {
        let base64 = Data(SHA256.hash(data: data))
            .base64EncodedString()
            .trimmingCharacters(in: CharacterSet(charactersIn: "="))
        return "SHA256:\(base64)"
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
    private var pendingBufferBudget = PendingTunnelBufferBudget()
    private var isClosing = false

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
                localChannel.eventLoop.execute { [weak self] in
                    guard let self else {
                        channel.close(promise: nil)
                        return
                    }
                    guard localChannel.isActive, !self.isClosing else {
                        channel.close(promise: nil)
                        return
                    }
                    self.sshChannel = channel
                    // Flush anything that arrived while we were connecting
                    for buffer in self.pendingBuffers {
                        channel.writeAndFlush(buffer, promise: nil)
                    }
                    self.pendingBuffers.removeAll()
                    self.pendingBufferBudget.reset()
                }
            } catch {
                localChannel.pipeline.fireErrorCaught(error)
                localChannel.close(promise: nil)
            }
        }
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let buffer = unwrapInboundIn(data)
        guard !isClosing else { return }
        // Forward local data to SSH channel as raw ByteBuffer —
        // Citadel's DataToBufferCodec wraps it in SSHChannelData for us
        if let sshChannel = sshChannel {
            sshChannel.writeAndFlush(buffer, promise: nil)
        } else {
            // SSH channel not ready yet — buffer until it is
            do {
                try pendingBufferBudget.reserve(bytes: buffer.readableBytes)
                pendingBuffers.append(buffer)
            } catch {
                isClosing = true
                pendingBuffers.removeAll()
                pendingBufferBudget.reset()
                context.fireErrorCaught(error)
                context.close(promise: nil)
            }
        }
    }

    func channelInactive(context: ChannelHandlerContext) {
        isClosing = true
        sshChannel?.close(promise: nil)
        pendingBuffers.removeAll()
        pendingBufferBudget.reset()
    }

    func errorCaught(context: ChannelHandlerContext, error: Error) {
        isClosing = true
        pendingBuffers.removeAll()
        pendingBufferBudget.reset()
        context.close(promise: nil)
    }
}

/// Bounds local bytes accepted while the SSH direct-tcpip channel is opening.
/// This state is confined to the local channel's event loop by the forwarder.
struct PendingTunnelBufferBudget {
    static let maximumBytes = 1_048_576

    private(set) var reservedBytes = 0

    mutating func reserve(bytes: Int) throws {
        guard bytes >= 0,
              bytes <= Self.maximumBytes,
              reservedBytes <= Self.maximumBytes - bytes else {
            throw SSHTunnelError.pendingBufferLimitExceeded(maximumBytes: Self.maximumBytes)
        }
        reservedBytes += bytes
    }

    mutating func reset() {
        reservedBytes = 0
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
    case invalidConfiguration
    case invalidPrivateKey
    case unsupportedPrivateKeyAlgorithm(String)
    case unsupportedPrivateKeyFormat
    case bindFailed
    case tunnelClosed
    case pendingBufferLimitExceeded(maximumBytes: Int)

    public var errorDescription: String? {
        switch self {
        case .noAuthMethod:
            return "No SSH authentication method provided (password or key required)."
        case .invalidConfiguration:
            return "SSH host, username, destination, and ports must be valid before connecting."
        case .invalidPrivateKey:
            return "The SSH private key could not be read. Use an OpenSSH-format RSA or Ed25519 key and verify its passphrase."
        case .unsupportedPrivateKeyAlgorithm(let algorithm):
            return "The SSH private key uses unsupported algorithm \(algorithm). Use RSA or Ed25519."
        case .unsupportedPrivateKeyFormat:
            return "Legacy PEM private keys are not supported. Convert or export the key in OpenSSH format."
        case .bindFailed:
            return "Failed to bind local tunnel port."
        case .tunnelClosed:
            return "SSH tunnel was closed unexpectedly."
        case .pendingBufferLimitExceeded(let maximumBytes):
            return "SSH tunnel setup received more than \(maximumBytes) bytes before forwarding was ready. The local connection was closed."
        }
    }
}
