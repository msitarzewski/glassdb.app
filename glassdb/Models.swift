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
        self.useTLS = useTLS
        self.isFavorite = isFavorite
        self.colorTag = colorTag
        self.dateAdded = dateAdded
        self.lastConnected = lastConnected
        self.tags = tags
    }

    var displaySubtitle: String {
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
    // case postgresql  // Phase 2

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .mysql: return "MySQL"
        }
    }

    var defaultPort: Int {
        switch self {
        case .mysql: return 3306
        }
    }

    var iconName: String {
        switch self {
        case .mysql: return "cylinder"
        }
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
