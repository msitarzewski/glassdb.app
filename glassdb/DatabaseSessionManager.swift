//
//  DatabaseSessionManager.swift
//  glassdb
//
//  Manages active database sessions and query execution
//

import Foundation
import Observation
import GlasSecretStore
import os
import GlassDBKit

@MainActor
@Observable
class DatabaseSessionManager {
    var sessions: [UUID: DatabaseSession] = [:]

    private var hasLoaded = false

    init(loadImmediately: Bool = true) {
        if loadImmediately {
            loadIfNeeded()
        }
    }

    func loadIfNeeded() {
        guard !hasLoaded else { return }
        hasLoaded = true
    }

    func connect(
        config: DatabaseConnectionConfig,
        password: String,
        sshPassword: String? = nil
    ) async throws -> UUID {
        let sessionID = UUID()
        let session = DatabaseSession(connectionConfig: config)
        sessions[sessionID] = session

        do {
            var dbHost = config.host
            var dbPort = config.port

            // SSH tunnel if needed
            if config.useSSHTunnel,
               let sshHost = config.sshHost,
               let sshUsername = config.sshUsername {
                session.state = .connecting(stage: .establishingSSHTunnel)
                Logger.database.info("Establishing SSH tunnel to \(sshHost)...")

                // Resolve SSH key material if auth method is .sshKey
                var sshPrivateKey: String? = nil
                var sshKeyPassphrase: String? = nil
                if config.sshAuthMethod == .sshKey, let keyID = config.sshKeyID {
                    let material = try KeychainManager.retrieveSSHKey(for: keyID)
                    sshPrivateKey = material.privateKey
                    sshKeyPassphrase = material.passphrase
                }

                let tunnelManager = SSHTunnelManager()
                let tunnelConfig = SSHTunnelConfig(
                    sshHost: sshHost,
                    sshPort: config.sshPort ?? 22,
                    sshUsername: sshUsername,
                    sshPassword: sshPrivateKey == nil ? (sshPassword ?? password) : nil,
                    sshPrivateKey: sshPrivateKey,
                    sshKeyPassphrase: sshKeyPassphrase,
                    remoteHost: config.host,
                    remotePort: config.port
                )
                let tunnel = try await tunnelManager.establish(config: tunnelConfig)
                session.tunnel = tunnel
                session.tunnelManager = tunnelManager

                dbHost = "127.0.0.1"
                dbPort = tunnel.localPort
                Logger.database.info("SSH tunnel established on local port \(tunnel.localPort)")
            }

            // Connect to MySQL (directly or through tunnel)
            session.state = .connecting(stage: .authenticating)
            Logger.database.info("Connecting to MySQL at \(dbHost):\(dbPort) as \(config.username) (config host: \(config.host):\(config.port))")

            let engine = MySQLEngine()
            let connection = try await engine.connect(
                host: dbHost,
                port: dbPort,
                username: config.username,
                password: password,
                database: config.defaultDatabase
            )
            session.engine = engine
            session.connection = connection
            session.state = .connected
            Logger.database.info("Connected to \(config.host):\(config.port)")
        } catch {
            // Clean up on failure
            if let tunnel = session.tunnel {
                try? await tunnel.close()
            }
            session.tunnel = nil
            session.tunnelManager = nil
            session.engine = nil
            session.state = .error(error.localizedDescription)
            sessions.removeValue(forKey: sessionID)
            Logger.database.error("Connection failed: \(error)")
            throw error
        }

        return sessionID
    }

    func disconnect(sessionID: UUID) async {
        guard let session = sessions[sessionID] else { return }
        do {
            try await session.connection?.close()
        } catch {
            Logger.database.error("Disconnect error: \(error)")
        }
        // Close SSH tunnel if active
        if let tunnel = session.tunnel {
            do {
                try await tunnel.close()
            } catch {
                Logger.database.error("Tunnel close error: \(error)")
            }
        }
        session.state = .disconnected
        session.connection = nil
        session.engine = nil
        session.tunnel = nil
        session.tunnelManager = nil
        sessions.removeValue(forKey: sessionID)
        Logger.database.info("Disconnected session \(sessionID)")
    }

    func executeQuery(_ sql: String, sessionID: UUID) async throws -> QueryResult {
        guard let session = sessions[sessionID],
              let connection = session.connection else {
            throw SessionError.notConnected
        }

        let result = try await connection.execute(sql)
        session.queryHistory.append(result)

        // Enforce history limit (reads from UserDefaults, falls back to 500)
        let stored = UserDefaults.standard.integer(forKey: "glassdb.maxQueryHistoryItems")
        let maxHistory = stored > 0 ? stored : 500
        if session.queryHistory.count > maxHistory {
            session.queryHistory.removeFirst(session.queryHistory.count - maxHistory)
        }

        return result
    }

    func session(for id: UUID) -> DatabaseSession? {
        sessions[id]
    }

    enum SessionError: Error, LocalizedError {
        case notConnected

        var errorDescription: String? {
            switch self {
            case .notConnected:
                return "No active database connection."
            }
        }
    }
}

@MainActor
@Observable
class DatabaseSession {
    let connectionConfig: DatabaseConnectionConfig
    var state: SessionState = .disconnected
    var connection: (any DatabaseConnection)?
    var engine: (any DatabaseEngine)?
    var tunnel: SSHTunnel?
    var tunnelManager: SSHTunnelManager?
    var queryHistory: [QueryResult] = []
    var currentDatabase: String?

    init(connectionConfig: DatabaseConnectionConfig) {
        self.connectionConfig = connectionConfig
        self.currentDatabase = connectionConfig.defaultDatabase
    }
}
