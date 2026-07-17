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
    private(set) var persistentQueryHistory: [QueryHistoryEntry] = []

    private var hasLoaded = false
    private let defaults: UserDefaults

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

    func connect(
        config: DatabaseConnectionConfig,
        password: String,
        sshPassword: String? = nil
    ) async throws -> UUID {
        let sessionID = UUID()
        let session = DatabaseSession(connectionConfig: config)
        sessions[sessionID] = session

        do {
            let engine = Self.makeEngine(for: config.engine)
            var dbHost = config.host
            var dbPort = config.port

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
                    sshPassword: sshPrivateKey == nil ? (sshPassword ?? password) : nil,
                    sshPrivateKey: sshPrivateKey,
                    sshKeyPassphrase: sshKeyPassphrase,
                    remoteHost: config.host,
                    remotePort: config.port,
                    trustedHostKeys: Set(trustedHostKeys.map(\.publicKeyData))
                )
                let tunnel = try await tunnelManager.establish(config: tunnelConfig)
                session.tunnel = tunnel
                session.tunnelManager = tunnelManager

                dbHost = "127.0.0.1"
                dbPort = tunnel.localPort
                Logger.database.info("SSH tunnel established on local port \(tunnel.localPort)")
            }

            // Connect to the selected network engine (directly or through tunnel)
            session.state = .connecting(stage: .authenticating)
            Logger.database.info("Connecting to \(config.engine.displayName, privacy: .public) at \(dbHost):\(dbPort) as \(config.username) (config host: \(config.host):\(config.port))")

            let tlsPolicy: DatabaseTLSPolicy = if config.useTLS {
                config.useSSHTunnel
                    ? .requiredSystemTrustForHost(config.host)
                    : .requiredSystemTrust
            } else {
                .disabled
            }
            let connection = try await engine.connect(
                host: dbHost,
                port: dbPort,
                username: config.username,
                password: password,
                database: config.defaultDatabase,
                tlsPolicy: tlsPolicy
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

    static func makeEngine(for type: DatabaseEngineType) -> any DatabaseEngine {
        switch type {
        case .mysql: MySQLEngine()
        case .postgresql: PostgreSQLEngine()
        case .sqlite: SQLiteEngine()
        }
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
        guard let session = sessions[sessionID],
              let connection = session.connection else {
            throw SessionError.notConnected
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
            throw error
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
        guard let session = sessions[sessionID],
              let connection = session.connection else {
            throw SessionError.notConnected
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

    enum SessionError: Error, LocalizedError {
        case notConnected
        case invalidConfiguration(String)

        var errorDescription: String? {
            switch self {
            case .notConnected:
                return "No active database connection."
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
