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
    private(set) var workspaceRequests: [UUID: DatabaseWorkspaceWindowRequest] = [:]
    private(set) var persistentQueryHistory: [QueryHistoryEntry] = []

    private var hasLoaded = false
    private let defaults: UserDefaults

    struct TransportPlan: Equatable, Sendable {
        let databaseHost: String
        let databasePort: Int
        let tunnelRemoteHost: String?
        let tunnelRemotePort: Int?
        let tlsPolicy: DatabaseTLSPolicy
    }

    enum ForegroundValidationResult: Equatable, Sendable {
        case connected
        case disconnected
        case missingSession
    }

    init(loadImmediately: Bool = true, defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if loadImmediately {
            loadIfNeeded()
        }
    }

    func loadIfNeeded() {
        guard !hasLoaded else { return }
        hasLoaded = true
        loadQueryHistory()
    }

    /// Registers the richer workspace launch context while keeping the scene's
    /// external value a plain UUID. UUID-valued WindowGroups are the proven
    /// spatial-window contract used by the Vision Pro terminal sibling app.
    @discardableResult
    func registerWorkspace(_ request: DatabaseWorkspaceWindowRequest) -> UUID {
        workspaceRequests[request.id] = request
        return request.id
    }

    /// Supports windows opened by older builds, where the scene UUID was the
    /// database session UUID and the workspace always used its default tab.
    func workspaceRequest(for windowID: UUID) -> DatabaseWorkspaceWindowRequest {
        workspaceRequests[windowID] ?? .primary(sessionID: windowID)
    }

    func releaseWorkspace(_ windowID: UUID) {
        workspaceRequests.removeValue(forKey: windowID)
    }

    func connect(
        config: DatabaseConnectionConfig,
        password: String,
        sshPassword: String?
    ) async throws -> UUID {
        let sessionID = UUID()
        let session = DatabaseSession(connectionConfig: config)
        sessions[sessionID] = session

        do {
            let engine = Self.makeEngine(for: config.engine)
            var tunnelLocalPort: Int?

            if config.engine == .sqlite {
                guard !config.useSSHTunnel, !config.useTLS else {
                    throw SessionError.invalidConfiguration(
                        "SQLite is a local file database and cannot use TLS or an SSH tunnel."
                    )
                }
                let sqliteURL: URL
                do {
                    sqliteURL = try SQLiteFileImporter.validatedURL(forPath: config.host)
                } catch {
                    throw SessionError.invalidConfiguration(error.localizedDescription)
                }
                do {
                    session.state = .connecting(stage: .authenticating)
                    let connection = try await engine.connect(
                        host: sqliteURL.path,
                        port: 0,
                        username: "",
                        password: "",
                        database: nil,
                        tlsPolicy: .disabled
                    )
                    session.engine = engine
                    session.connection = connection
                    session.currentDatabase = "main"
                    session.state = .connected
                    Logger.database.info("Opened SQLite database \(sqliteURL.lastPathComponent, privacy: .public)")
                } catch {
                    throw error
                }
                return sessionID
            }

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
                    sshPrivateKey = material.privateKey.toUTF8String()
                    sshKeyPassphrase = material.passphrase?.toUTF8String()
                }

                let tunnelManager = SSHTunnelManager()
                let sshPort = config.sshPort ?? 22
                let trustedHostKeys = try SSHHostTrustKeychainStore.authorizedRecords(
                    host: sshHost,
                    port: sshPort,
                    config: KeychainManager.config
                )
                let tunnelConfig = SSHTunnelConfig(
                    sshHost: sshHost,
                    sshPort: sshPort,
                    sshUsername: sshUsername,
                    sshPassword: Self.tunnelPassword(
                        sshPassword: sshPassword,
                        hasPrivateKey: sshPrivateKey != nil
                    ),
                    sshPrivateKey: sshPrivateKey,
                    sshKeyPassphrase: sshKeyPassphrase,
                    remoteHost: config.host,
                    remotePort: config.port,
                    trustedHostKeys: Set(trustedHostKeys.map(\.publicKeyData))
                )
                let tunnel = try await tunnelManager.establish(config: tunnelConfig)
                session.tunnel = tunnel
                session.tunnelManager = tunnelManager

                tunnelLocalPort = tunnel.localPort
                Logger.database.info("SSH tunnel established on local port \(tunnel.localPort)")
            }

            // Connect to the selected network engine (directly or through tunnel)
            let transportPlan = try Self.transportPlan(
                for: config,
                tunnelLocalPort: tunnelLocalPort
            )
            session.state = .connecting(stage: .authenticating)
            Logger.database.info("Connecting to \(config.engine.displayName, privacy: .public) at \(transportPlan.databaseHost):\(transportPlan.databasePort) as \(config.username) (config host: \(config.host):\(config.port))")
            let connection = try await engine.connect(
                host: transportPlan.databaseHost,
                port: transportPlan.databasePort,
                username: config.username,
                password: password,
                database: config.defaultDatabase,
                tlsPolicy: transportPlan.tlsPolicy
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
            let propagatedError = Self.actionableConnectionError(error, config: config)
            session.state = .error(propagatedError.localizedDescription)
            sessions.removeValue(forKey: sessionID)
            Logger.database.error("Connection failed: \(propagatedError)")
            throw propagatedError
        }

        return sessionID
    }

    static func makeEngine(for type: DatabaseEngineType) -> any DatabaseEngine {
        switch type {
        case .mysql: MySQLEngine()
        case .postgresql: PostgreSQLEngine()
        case .sqlite: SQLiteEngine()
        }
    }

    /// Keeps database and SSH credentials in separate authentication domains.
    /// Key-based tunnels must not also receive a password, and a missing SSH
    /// password must never fall back to the database password.
    nonisolated static func tunnelPassword(
        sshPassword: String?,
        hasPrivateKey: Bool
    ) -> String? {
        hasPrivateKey ? nil : sshPassword
    }

    nonisolated static func transportPlan(
        for config: DatabaseConnectionConfig,
        tunnelLocalPort: Int? = nil
    ) throws -> TransportPlan {
        if config.engine == .sqlite {
            guard !config.useSSHTunnel, !config.useTLS else {
                throw SessionError.invalidConfiguration(
                    "SQLite is a local file database and cannot use TLS or an SSH tunnel."
                )
            }
            return TransportPlan(
                databaseHost: config.host,
                databasePort: 0,
                tunnelRemoteHost: nil,
                tunnelRemotePort: nil,
                tlsPolicy: .disabled
            )
        }

        let tlsPolicy: DatabaseTLSPolicy = if config.useTLS {
            config.useSSHTunnel
                ? .requiredSystemTrustForHost(config.host)
                : .requiredSystemTrust
        } else {
            .disabled
        }

        if config.useSSHTunnel {
            guard let tunnelLocalPort, tunnelLocalPort > 0 else {
                throw SessionError.invalidConfiguration(
                    "The SSH tunnel did not provide a valid local database port."
                )
            }
            return TransportPlan(
                databaseHost: "127.0.0.1",
                databasePort: tunnelLocalPort,
                tunnelRemoteHost: config.host,
                tunnelRemotePort: config.port,
                tlsPolicy: tlsPolicy
            )
        }

        return TransportPlan(
            databaseHost: config.host,
            databasePort: config.port,
            tunnelRemoteHost: nil,
            tunnelRemotePort: nil,
            tlsPolicy: tlsPolicy
        )
    }

    func testConnection(config: DatabaseConnectionConfig, password: String, sshPassword: String? = nil) async throws {
        let sessionID = try await connect(config: config, password: password, sshPassword: sshPassword)
        await disconnect(sessionID: sessionID)
    }

    func testSSHConnection(config: DatabaseConnectionConfig, sshPassword: String? = nil) async throws {
        guard config.useSSHTunnel,
              let sshHost = config.sshHost,
              let sshUsername = config.sshUsername else {
            throw SSHTunnelError.noAuthMethod
        }

        var sshPrivateKey: String? = nil
        var sshKeyPassphrase: String? = nil
        if config.sshAuthMethod == .sshKey, let keyID = config.sshKeyID {
            let material = try KeychainManager.retrieveSSHKey(for: keyID)
            sshPrivateKey = material.privateKey.toUTF8String()
            sshKeyPassphrase = material.passphrase?.toUTF8String()
        }

        let sshPort = config.sshPort ?? 22
        let trustedHostKeys = try SSHHostTrustKeychainStore.authorizedRecords(
            host: sshHost,
            port: sshPort,
            config: KeychainManager.config
        )
        let tunnelConfig = SSHTunnelConfig(
            sshHost: sshHost,
            sshPort: sshPort,
            sshUsername: sshUsername,
            sshPassword: sshPrivateKey == nil ? sshPassword : nil,
            sshPrivateKey: sshPrivateKey,
            sshKeyPassphrase: sshKeyPassphrase,
            remoteHost: config.host,
            remotePort: config.port,
            trustedHostKeys: Set(trustedHostKeys.map(\.publicKeyData))
        )
        let tunnelManager = SSHTunnelManager()
        let tunnel = try await tunnelManager.establish(config: tunnelConfig)
        try? await tunnel.close()
    }

    /// Re-establishes the transport behind an existing logical session. Keeping
    /// the `DatabaseSession` instance intact means every workspace window over
    /// that session recovers together without losing tabs, history, or AI context.
    func reconnect(sessionID: UUID) async throws {
        guard let session = sessions[sessionID] else {
            throw SessionError.notConnected
        }
        guard !session.state.isConnecting else { return }

        let config = session.connectionConfig
        let selectedDatabase = session.currentDatabase
        session.lastConnectionError = nil
        session.state = .connecting(stage: .resolvingHost)

        do {
            let credentials = try Self.storedCredentials(for: config)
            let replacementID = try await connect(
                config: config,
                password: credentials.database,
                sshPassword: credentials.ssh
            )
            guard let replacement = sessions.removeValue(forKey: replacementID),
                  let connection = replacement.connection else {
                throw SessionError.notConnected
            }

            do {
                // MySQL can change its active database within one connection. Put a
                // reconnected editor back where the user left it before publishing
                // the recovered transport to any sibling workspace windows.
                if config.engine == .mysql,
                   let selectedDatabase,
                   !selectedDatabase.isEmpty,
                   selectedDatabase != config.defaultDatabase {
                    let result = try await connection.execute(
                        "USE \(connection.quotedIdentifier(selectedDatabase))",
                        parameters: []
                    )
                    if let error = result.error {
                        throw DatabaseError.unexpectedResult(error)
                    }
                }
            } catch {
                try? await connection.close()
                try? await replacement.tunnel?.close()
                replacement.connection = nil
                replacement.engine = nil
                replacement.tunnel = nil
                replacement.tunnelManager = nil
                throw error
            }

            session.connection = connection
            session.engine = replacement.engine
            session.tunnel = replacement.tunnel
            session.tunnelManager = replacement.tunnelManager
            session.currentDatabase = config.engine == .sqlite
                ? "main"
                : (selectedDatabase ?? replacement.currentDatabase)
            session.requiresTransportValidation = false
            session.state = .connected

            // Ownership moved to the retained session above.
            replacement.connection = nil
            replacement.engine = nil
            replacement.tunnel = nil
            replacement.tunnelManager = nil
            Logger.database.info("Reconnected session \(sessionID)")
        } catch {
            let message = error.localizedDescription
            session.lastConnectionError = message
            session.state = .error(message)
            Logger.database.error("Reconnect failed for session \(sessionID): \(message, privacy: .public)")
            throw error
        }
    }

    /// Records that the owning scene may be suspended. The transport is not
    /// closed here because another iPad window can still own the same logical
    /// session; every subsequent request performs validation before use.
    func noteSessionSuspended(sessionID: UUID) {
        guard let session = sessions[sessionID], session.state.isConnected else { return }
        session.requiresTransportValidation = true
    }

    /// Revalidates a possibly suspended transport without issuing a query or
    /// silently reconnecting. Reconnect remains one explicit, bounded user action.
    func validateSessionAfterForeground(sessionID: UUID) async -> ForegroundValidationResult {
        guard sessions[sessionID] != nil else { return .missingSession }
        guard await refreshConnectionState(sessionID: sessionID) else { return .disconnected }
        return .connected
    }

    /// Checks the local transport state without issuing a keepalive query. This
    /// catches sockets the driver already knows are closed while respecting the
    /// server's configured idle-timeout policy.
    @discardableResult
    func refreshConnectionState(sessionID: UUID) async -> Bool {
        guard let session = sessions[sessionID],
              session.state.isConnected,
              let connection = session.connection else {
            return false
        }
        guard await connection.isConnected else {
            await invalidateTransport(
                for: session,
                reason: "The database connection timed out or was closed."
            )
            return false
        }
        session.requiresTransportValidation = false
        return true
    }

    /// Lets metadata surfaces that call the driver directly report a terminal
    /// transport error through the same shared session state as query execution.
    func handleConnectionFailure(_ error: any Error, sessionID: UUID) async {
        guard let session = sessions[sessionID],
              let connection = session.connection else { return }
        let isOpen = await connection.isConnected
        guard !isOpen || Self.isTerminalConnectionError(error.localizedDescription) else { return }
        await invalidateTransport(for: session, reason: error.localizedDescription)
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

    func executeQuery(
        _ sql: String,
        parameters: [DatabaseValue] = [],
        sessionID: UUID,
        editorRowLimit: Int? = nil
    ) async throws -> QueryResult {
        guard let session = sessions[sessionID] else {
            throw SessionError.notConnected
        }
        guard session.state.isConnected,
              let connection = session.connection else {
            throw SessionError.connectionLost
        }
        guard await refreshConnectionState(sessionID: sessionID) else {
            throw SessionError.connectionLost
        }

        if let editorRowLimit,
           !SQLHighlighter.validEditorResultRowLimits.contains(editorRowLimit) {
            throw SessionError.invalidConfiguration(
                "Editor result limits must be between 1 and 100,000 rows."
            )
        }

        let boundedPlan = editorRowLimit.flatMap {
            SQLHighlighter.boundedReadPlan(
                for: sql,
                rowLimit: $0,
                dialect: connection.dialect
            )
        }
        let executionSQL = boundedPlan?.executionSQL ?? sql
        let startedAt = Date()
        let result: QueryResult
        do {
            let rawResult = try await connection.execute(executionSQL, parameters: parameters)
            if let boundedPlan {
                let truncated = rawResult.rows.count > boundedPlan.rowLimit
                result = QueryResult(
                    id: rawResult.id,
                    query: sql,
                    columns: rawResult.columns,
                    rows: Array(rawResult.rows.prefix(boundedPlan.rowLimit)),
                    affectedRows: rawResult.affectedRows,
                    lastInsertID: rawResult.lastInsertID,
                    warningCount: rawResult.warningCount,
                    executionTime: rawResult.executionTime,
                    timestamp: rawResult.timestamp,
                    error: rawResult.error,
                    appliedRowLimit: boundedPlan.rowLimit,
                    isTruncated: truncated
                )
            } else {
                result = rawResult
            }
        } catch {
            recordHistory(
                sql: sql,
                session: session,
                timestamp: startedAt,
                duration: Date().timeIntervalSince(startedAt),
                rowCount: nil,
                affectedRows: nil,
                error: error.localizedDescription
            )
            await handleConnectionFailure(error, sessionID: sessionID)
            if !session.state.isConnected {
                throw SessionError.connectionLost
            }
            throw error
        }

        if let error = result.error,
           Self.isTerminalConnectionError(error) {
            await invalidateTransport(for: session, reason: error)
        }

        // Track USE database switches so the UI shows the current database
        let trimmed = sql.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.uppercased().hasPrefix("USE ") && result.error == nil {
            let dbName = trimmed.dropFirst(4)
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "`;"))
                .replacingOccurrences(of: "`", with: "")
            session.currentDatabase = dbName
        }

        session.queryHistory.append(result)
        recordHistory(
            sql: sql,
            session: session,
            timestamp: result.timestamp,
            duration: result.executionTime,
            rowCount: result.rowCount,
            affectedRows: result.affectedRows,
            error: result.error
        )

        return result
    }

    func explainQuery(_ sql: String, sessionID: UUID) async throws -> QueryResult {
        guard let session = sessions[sessionID] else {
            throw SessionError.notConnected
        }
        guard session.state.isConnected,
              let connection = session.connection else {
            throw SessionError.connectionLost
        }
        guard await refreshConnectionState(sessionID: sessionID) else {
            throw SessionError.connectionLost
        }
        guard connection.capabilities.contains(.explain) else {
            throw DatabaseError.unsupportedCapability(
                .explain,
                engine: connection.engineName
            )
        }

        let startedAt = Date()
        do {
            let result = try await connection.explain(sql, parameters: [])
            session.queryHistory.append(result)
            recordHistory(
                sql: "EXPLAIN \(sql)",
                session: session,
                timestamp: result.timestamp,
                duration: result.executionTime,
                rowCount: result.rowCount,
                affectedRows: result.affectedRows,
                error: result.error
            )
            return result
        } catch {
            recordHistory(
                sql: "EXPLAIN \(sql)",
                session: session,
                timestamp: startedAt,
                duration: Date().timeIntervalSince(startedAt),
                rowCount: nil,
                affectedRows: nil,
                error: error.localizedDescription
            )
            await handleConnectionFailure(error, sessionID: sessionID)
            if !session.state.isConnected {
                throw SessionError.connectionLost
            }
            throw error
        }
    }

    func cancelQuery(sessionID: UUID) async throws {
        guard let session = sessions[sessionID],
              let connection = session.connection else {
            throw SessionError.notConnected
        }
        guard connection.capabilities.contains(.cancellation) else {
            throw DatabaseError.unsupportedCapability(
                .cancellation,
                engine: connection.engineName
            )
        }
        try await connection.cancelCurrentQuery()
        guard !(await connection.isConnected) else { return }

        // Drivers without a native cancellation packet abort by closing their
        // transport. Reflect that terminal state immediately and tear down any
        // tunnel so the UI never presents a dead connection as usable.
        if let tunnel = session.tunnel {
            try? await tunnel.close()
        }
        session.state = .disconnected
        session.connection = nil
        session.engine = nil
        session.tunnel = nil
        session.tunnelManager = nil
    }

    // MARK: - Durable Query History

    func queryHistory(
        matching searchText: String = "",
        connectionID: UUID? = nil,
        database: String? = nil,
        status: QueryHistoryStatus = .all
    ) -> [QueryHistoryEntry] {
        let needle = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return persistentQueryHistory.reversed().filter { entry in
            if let connectionID, entry.connectionID != connectionID { return false }
            if let database, entry.database != database { return false }
            if status == .succeeded, entry.error != nil { return false }
            if status == .failed, entry.error == nil { return false }
            guard !needle.isEmpty else { return true }
            return entry.sql.localizedCaseInsensitiveContains(needle)
                || entry.database?.localizedCaseInsensitiveContains(needle) == true
                || entry.error?.localizedCaseInsensitiveContains(needle) == true
        }
    }

    func deleteQueryHistory(id: UUID) {
        persistentQueryHistory.removeAll { $0.id == id }
        saveQueryHistory()
    }

    func deleteAllQueryHistory(connectionID: UUID? = nil) {
        if let connectionID {
            persistentQueryHistory.removeAll { $0.connectionID == connectionID }
        } else {
            persistentQueryHistory.removeAll()
        }
        saveQueryHistory()
    }

    func enforceQueryHistoryLimit() {
        let maxHistory = configuredHistoryLimit
        if persistentQueryHistory.count > maxHistory {
            persistentQueryHistory.removeFirst(persistentQueryHistory.count - maxHistory)
            saveQueryHistory()
        }
        for session in sessions.values where session.queryHistory.count > maxHistory {
            session.queryHistory.removeFirst(session.queryHistory.count - maxHistory)
        }
    }

    private var configuredHistoryLimit: Int {
        let stored = defaults.integer(forKey: UserDefaultsKeys.maxQueryHistoryItems)
        return min(max(stored > 0 ? stored : 500, 1), 10_000)
    }

    func recordHistory(
        sql: String,
        session: DatabaseSession,
        timestamp: Date,
        duration: TimeInterval,
        rowCount: Int?,
        affectedRows: UInt64?,
        error: String?
    ) {
        let redactLiterals = defaults.bool(forKey: UserDefaultsKeys.redactQueryHistoryLiterals)
        let retainedSQL = redactLiterals ? SQLHighlighter.redactingLiterals(in: sql) : sql
        persistentQueryHistory.append(QueryHistoryEntry(
            sql: retainedSQL,
            timestamp: timestamp,
            duration: duration,
            rowCount: rowCount,
            affectedRows: affectedRows,
            error: error,
            database: session.currentDatabase,
            connectionID: session.connectionConfig.id,
            safety: SQLHighlighter.safetyClassification(of: sql)
        ))
        enforceQueryHistoryLimit()
        saveQueryHistory()
    }

    private func loadQueryHistory() {
        guard let data = defaults.data(forKey: UserDefaultsKeys.queryHistory) else {
            persistentQueryHistory = []
            return
        }
        do {
            persistentQueryHistory = try JSONDecoder().decode([QueryHistoryEntry].self, from: data)
            enforceQueryHistoryLimit()
        } catch {
            Logger.database.error("Could not load query history: \(error)")
            persistentQueryHistory = []
        }
    }

    private func saveQueryHistory() {
        do {
            let data = try JSONEncoder().encode(persistentQueryHistory)
            defaults.set(data, forKey: UserDefaultsKeys.queryHistory)
        } catch {
            Logger.database.error("Could not save query history: \(error)")
        }
    }

    func session(for id: UUID) -> DatabaseSession? {
        sessions[id]
    }

    nonisolated static func isTerminalConnectionError(_ message: String) -> Bool {
        let normalized = message.lowercased()
        return [
            "connection closed",
            "connection is closed",
            "connection lost",
            "lost connection",
            "connection reset",
            "connection terminated",
            "server has gone away",
            "broken pipe",
            "channel closed",
            "channel is closed",
            "not connected",
            "timed out or was closed",
        ].contains { normalized.contains($0) }
    }

    nonisolated static func isLocalNetworkPermissionDenied(
        domain: String,
        code: Int,
        message: String
    ) -> Bool {
        let normalizedDomain = domain.lowercased()
        let normalizedMessage = message.lowercased()
        if code == -65_570 { return true } // kDNSServiceErr_PolicyDenied
        if normalizedDomain == NSPOSIXErrorDomain.lowercased(), code == 1 || code == 13 {
            return true
        }
        return normalizedMessage.contains("policy denied")
            || normalizedMessage.contains("local network access")
            || normalizedMessage.contains("local network permission")
    }

    private nonisolated static func actionableConnectionError(
        _ error: any Error,
        config: DatabaseConnectionConfig
    ) -> any Error {
        guard config.engine.supportsNetworkTransport else { return error }
        let nsError = error as NSError
        guard isLocalNetworkPermissionDenied(
            domain: nsError.domain,
            code: nsError.code,
            message: error.localizedDescription
        ) else { return error }
        return SessionError.localNetworkPermissionDenied
    }

    private static func storedCredentials(
        for config: DatabaseConnectionConfig
    ) throws -> (database: String, ssh: String?) {
        let databasePassword: String
        if config.engine.supportsCredentials {
            do {
                databasePassword = try KeychainManager.retrievePassword(for: config)
            } catch SecretStoreError.notFound {
                databasePassword = ""
            }
        } else {
            databasePassword = ""
        }

        var sshPassword: String?
        if config.useSSHTunnel && config.sshAuthMethod != .sshKey {
            do {
                sshPassword = try KeychainManager.retrieveSSHPassword(for: config)
            } catch SecretStoreError.notFound {
                sshPassword = ""
            }
        }
        return (databasePassword, sshPassword)
    }

    private func invalidateTransport(
        for session: DatabaseSession,
        reason: String
    ) async {
        guard session.state.isConnected || session.connection != nil else { return }
        let connection = session.connection
        let tunnel = session.tunnel

        // Publish the terminal state before awaiting cleanup so every window
        // disables database actions immediately.
        session.lastConnectionError = reason
        session.state = .disconnected
        session.requiresTransportValidation = false
        session.connection = nil
        session.engine = nil
        session.tunnel = nil
        session.tunnelManager = nil

        try? await connection?.close()
        try? await tunnel?.close()
        Logger.database.notice("Database transport became unavailable: \(reason, privacy: .public)")
    }

    enum SessionError: Error, LocalizedError {
        case notConnected
        case connectionLost
        case localNetworkPermissionDenied
        case invalidConfiguration(String)

        var errorDescription: String? {
            switch self {
            case .notConnected:
                return "No active database connection."
            case .connectionLost:
                return "The database connection timed out or was closed. Reconnect to continue."
            case .localNetworkPermissionDenied:
                return "Local Network access is off for glassdb. Allow it in Settings, then reconnect."
            case .invalidConfiguration(let message):
                return message
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
    var lastConnectionError: String?
    var requiresTransportValidation = false
    let aiAssistant = AIAssistant()

    init(connectionConfig: DatabaseConnectionConfig) {
        self.connectionConfig = connectionConfig
        self.currentDatabase = connectionConfig.engine == .sqlite
            ? "main"
            : connectionConfig.defaultDatabase
    }
}

enum QueryHistoryStatus: String, CaseIterable, Hashable, Identifiable, Sendable {
    case all
    case succeeded
    case failed

    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }
}

struct QueryHistoryEntry: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let sql: String
    let timestamp: Date
    let duration: TimeInterval
    let rowCount: Int?
    let affectedRows: UInt64?
    let error: String?
    let database: String?
    let connectionID: UUID
    let safety: SQLSafetyClassification

    init(
        id: UUID = UUID(),
        sql: String,
        timestamp: Date,
        duration: TimeInterval,
        rowCount: Int?,
        affectedRows: UInt64?,
        error: String?,
        database: String?,
        connectionID: UUID,
        safety: SQLSafetyClassification
    ) {
        self.id = id
        self.sql = sql
        self.timestamp = timestamp
        self.duration = duration
        self.rowCount = rowCount
        self.affectedRows = affectedRows
        self.error = error
        self.database = database
        self.connectionID = connectionID
        self.safety = safety
    }
}
