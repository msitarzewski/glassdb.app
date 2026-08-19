//
//  Models.swift
//  glassdb
//
//  Core data models for database connections, sessions, and configuration
//

import Foundation
import SwiftUI

// MARK: - Database Connection Configuration

struct DatabaseConnectionConfig: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var engine: DatabaseEngineType
    var host: String
    var port: Int
    var username: String
    var defaultDatabase: String?
    var useSSHTunnel: Bool
    var sshHost: String?
    var sshPort: Int?
    var sshUsername: String?
    var sshAuthMethod: AuthenticationMethod?
    var sshKeyID: UUID?
    var databaseCredentialPolicy: CredentialStoragePolicy
    var sshCredentialPolicy: CredentialStoragePolicy
    var useTLS: Bool
    var isFavorite: Bool
    var colorTag: ConnectionColorTag
    let dateAdded: Date
    var lastConnected: Date?
    var tags: [String]

    init(
        id: UUID = UUID(),
        name: String,
        engine: DatabaseEngineType = .mysql,
        host: String = "127.0.0.1",
        port: Int = 3306,
        username: String = "root",
        defaultDatabase: String? = nil,
        useSSHTunnel: Bool = false,
        sshHost: String? = nil,
        sshPort: Int? = 22,
        sshUsername: String? = nil,
        sshAuthMethod: AuthenticationMethod? = nil,
        sshKeyID: UUID? = nil,
        databaseCredentialPolicy: CredentialStoragePolicy = .glassdbOnly,
        sshCredentialPolicy: CredentialStoragePolicy = .glassdbOnly,
        useTLS: Bool = false,
        isFavorite: Bool = false,
        colorTag: ConnectionColorTag = .none,
        dateAdded: Date = Date(),
        lastConnected: Date? = nil,
        tags: [String] = []
    ) {
        self.id = id
        self.name = name
        self.engine = engine
        self.host = host
        self.port = port
        self.username = username
        self.defaultDatabase = defaultDatabase
        self.useSSHTunnel = useSSHTunnel
        self.sshHost = sshHost
        self.sshPort = sshPort
        self.sshUsername = sshUsername
        self.sshAuthMethod = sshAuthMethod
        self.sshKeyID = sshKeyID
        self.databaseCredentialPolicy = databaseCredentialPolicy
        self.sshCredentialPolicy = sshCredentialPolicy
        self.useTLS = useTLS
        self.isFavorite = isFavorite
        self.colorTag = colorTag
        self.dateAdded = dateAdded
        self.lastConnected = lastConnected
        self.tags = tags
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, engine, host, port, username, defaultDatabase
        case useSSHTunnel, sshHost, sshPort, sshUsername, sshAuthMethod, sshKeyID
        case databaseCredentialPolicy, sshCredentialPolicy
        case useTLS, isFavorite, colorTag, dateAdded, lastConnected, tags
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        name = try values.decode(String.self, forKey: .name)
        engine = try values.decodeIfPresent(DatabaseEngineType.self, forKey: .engine) ?? .mysql
        host = try values.decode(String.self, forKey: .host)
        port = try values.decode(Int.self, forKey: .port)
        username = try values.decode(String.self, forKey: .username)
        defaultDatabase = try values.decodeIfPresent(String.self, forKey: .defaultDatabase)
        useSSHTunnel = try values.decodeIfPresent(Bool.self, forKey: .useSSHTunnel) ?? false
        sshHost = try values.decodeIfPresent(String.self, forKey: .sshHost)
        sshPort = try values.decodeIfPresent(Int.self, forKey: .sshPort)
        sshUsername = try values.decodeIfPresent(String.self, forKey: .sshUsername)
        sshAuthMethod = try values.decodeIfPresent(AuthenticationMethod.self, forKey: .sshAuthMethod)
        sshKeyID = try values.decodeIfPresent(UUID.self, forKey: .sshKeyID)
        // Database passwords are never shared across the Glass family —
        // glas.sh has no use for them. Shared (and legacy-defaulted) database
        // policies normalize to glassdb-only storage on read.
        let decodedDatabasePolicy = try values.decodeIfPresent(
            CredentialStoragePolicy.self,
            forKey: .databaseCredentialPolicy
        ) ?? .sharedWithGlas
        databaseCredentialPolicy = decodedDatabasePolicy == .sharedWithGlas
            ? .glassdbOnly
            : decodedDatabasePolicy
        // SSH records written before G04 were always stored in the shared
        // glas.sh access group. Preserve that location until the user
        // explicitly changes it — SSH identity is the shareable class.
        sshCredentialPolicy = try values.decodeIfPresent(
            CredentialStoragePolicy.self,
            forKey: .sshCredentialPolicy
        ) ?? .sharedWithGlas
        useTLS = try values.decodeIfPresent(Bool.self, forKey: .useTLS) ?? false
        isFavorite = try values.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
        colorTag = try values.decodeIfPresent(ConnectionColorTag.self, forKey: .colorTag) ?? .none
        dateAdded = try values.decodeIfPresent(Date.self, forKey: .dateAdded) ?? Date()
        lastConnected = try values.decodeIfPresent(Date.self, forKey: .lastConnected)
        tags = try values.decodeIfPresent([String].self, forKey: .tags) ?? []
    }

    var displaySubtitle: String {
        if engine == .sqlite {
            let filename = URL(fileURLWithPath: host).lastPathComponent
            return filename.isEmpty ? "Local SQLite database" : filename
        }
        var parts = ["\(username)@\(host):\(port)"]
        if let db = defaultDatabase, !db.isEmpty {
            parts.append(db)
        }
        return parts.joined(separator: " / ")
    }
}

// MARK: - Enums

enum DatabaseEngineType: String, Codable, CaseIterable, Identifiable {
    case mysql
    case postgresql
    case sqlite

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .mysql: return "MySQL"
        case .postgresql: return "PostgreSQL"
        case .sqlite: return "SQLite"
        }
    }

    var defaultPort: Int {
        switch self {
        case .mysql: return 3306
        case .postgresql: return 5432
        case .sqlite: return 0
        }
    }

    var iconName: String {
        switch self {
        case .mysql: return "cylinder"
        case .postgresql: return "cylinder.split.1x2"
        case .sqlite: return "externaldrive"
        }
    }

    var defaultHost: String {
        switch self {
        case .mysql, .postgresql: "127.0.0.1"
        case .sqlite: ""
        }
    }

    var defaultUsername: String {
        switch self {
        case .mysql: "root"
        case .postgresql: "postgres"
        case .sqlite: ""
        }
    }

    var supportsNetworkTransport: Bool { self != .sqlite }
    var supportsCredentials: Bool { self != .sqlite }
    var supportsTLS: Bool { self != .sqlite }
    var supportsSSHTunnel: Bool { self != .sqlite }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self).lowercased()
        switch value {
        case "mysql", "mariadb": self = .mysql
        case "postgres", "postgresql", "postgres-nio": self = .postgresql
        case "sqlite", "sqlite3": self = .sqlite
        default:
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported database engine ‘\(value)’"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

enum AuthenticationMethod: String, Codable, CaseIterable {
    case password
    case sshKey

    var displayName: String {
        switch self {
        case .password: return "Password"
        case .sshKey: return "SSH Key"
        }
    }
}

enum CredentialStoragePolicy: String, Codable, CaseIterable, Identifiable, Sendable {
    case sharedWithGlas
    case glassdbOnly
    case requireAuthentication

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .sharedWithGlas: return "Shared with glas.sh"
        case .glassdbOnly: return "glassdb only"
        case .requireAuthentication: return "Require authentication"
        }
    }

    var policyDescription: String {
        switch self {
        case .sharedWithGlas:
            return "Available to glassdb and glas.sh on this device while it is unlocked."
        case .glassdbOnly:
            return "Stored in glassdb's private, device-only Keychain namespace."
        case .requireAuthentication:
            return "Private to glassdb and requires device-owner authentication before every use."
        }
    }

    /// Database passwords are never shared across the Glass family; sharing
    /// is an SSH-credential concept, and glas.sh has no use for database
    /// secrets.
    static var databasePolicies: [CredentialStoragePolicy] {
        [.glassdbOnly, .requireAuthentication]
    }

    /// Manual SSH entry chooses between the private policies; cross-app
    /// sharing is the explicit opt-in resolved by
    /// `sshPolicy(shareWithGlas:manualPolicy:)`.
    static var sshManualPolicies: [CredentialStoragePolicy] {
        [.glassdbOnly, .requireAuthentication]
    }

    /// Resolves the stored SSH policy from the form's share opt-in plus the
    /// manual storage choice. Sharing always wins; a stray shared manual
    /// value without the opt-in collapses to private storage.
    static func sshPolicy(
        shareWithGlas: Bool,
        manualPolicy: CredentialStoragePolicy
    ) -> CredentialStoragePolicy {
        if shareWithGlas { return .sharedWithGlas }
        return manualPolicy == .requireAuthentication ? .requireAuthentication : .glassdbOnly
    }
}

enum ConnectionColorTag: String, Codable, CaseIterable {
    case none
    case red
    case orange
    case yellow
    case green
    case blue
    case purple
    case pink

    var color: Color {
        switch self {
        case .none: return .secondary
        case .red: return .red
        case .orange: return .orange
        case .yellow: return .yellow
        case .green: return .green
        case .blue: return .blue
        case .purple: return .purple
        case .pink: return .pink
        }
    }

    var displayName: String {
        rawValue.capitalized
    }
}

// MARK: - Session State

enum SessionState: Equatable {
    case disconnected
    case connecting(stage: ConnectionStage)
    case connected
    case error(String)

    var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }

    var isConnecting: Bool {
        if case .connecting = self { return true }
        return false
    }
}

enum ConnectionStage: String, Equatable {
    case resolvingHost = "Resolving host..."
    case establishingSSHTunnel = "Establishing SSH tunnel..."
    case authenticating = "Authenticating..."
    case selectingDatabase = "Selecting database..."
    case ready = "Connected"
}

// MARK: - Saved Query

struct SavedQuery: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var sql: String
    var connectionID: UUID?
    var lastUsed: Date?
    var useCount: Int
    let createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        sql: String,
        connectionID: UUID? = nil,
        lastUsed: Date? = nil,
        useCount: Int = 0,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.sql = sql
        self.connectionID = connectionID
        self.lastUsed = lastUsed
        self.useCount = useCount
        self.createdAt = createdAt
    }
}

// MARK: - Mutation Audit

enum MutationOutcome: String, Codable, Sendable {
    case committed
    case rolledBack
    case serverStateUnknown
    case notStarted
}

struct MutationAuditRecord: Identifiable, Codable, Sendable {
    let id: UUID
    let connectionID: UUID
    let database: String?
    let object: String?
    let normalizedOperation: String
    let source: String
    let timestamp: Date
    let outcome: MutationOutcome
    let affectedRows: UInt64?

    init(
        id: UUID = UUID(),
        connectionID: UUID,
        database: String?,
        object: String?,
        normalizedOperation: String,
        source: String,
        timestamp: Date = Date(),
        outcome: MutationOutcome,
        affectedRows: UInt64?
    ) {
        self.id = id
        self.connectionID = connectionID
        self.database = database
        self.object = object
        self.normalizedOperation = normalizedOperation
        self.source = source
        self.timestamp = timestamp
        self.outcome = outcome
        self.affectedRows = affectedRows
    }
}

@MainActor
enum MutationAuditStore {
    private static let storageKey = "glassdb.mutationAudit.v1"
    private static let maximumRecords = 1_000

    static func append(_ record: MutationAuditRecord, defaults: UserDefaults = .standard) {
        var records: [MutationAuditRecord] = []
        if let data = defaults.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([MutationAuditRecord].self, from: data) {
            records = decoded
        }
        records.append(record)
        if records.count > maximumRecords {
            records.removeFirst(records.count - maximumRecords)
        }
        if let encoded = try? JSONEncoder().encode(records) {
            defaults.set(encoded, forKey: storageKey)
        }
    }
}
