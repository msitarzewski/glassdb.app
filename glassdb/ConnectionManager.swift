//
//  ConnectionManager.swift
//  glassdb
//
//  CRUD for saved database connections with persistence
//  Pattern adapted from glas.sh ServerManager
//

import SwiftUI
import Foundation
import Observation
import os

enum ConnectionPersistenceError: LocalizedError {
    case readbackMismatch
    case rollbackFailed
    case credentialRollbackFailed

    var errorDescription: String? {
        switch self {
        case .readbackMismatch:
            return "The saved connection list could not be verified. No connection or managed database changes were committed."
        case .rollbackFailed:
            return "The connection list could not be saved and its previous persisted state could not be restored. Reopen the app and verify the saved connections before continuing."
        case .credentialRollbackFailed:
            return "The connection list could not be saved and its credentials could not be fully restored. Re-enter the credentials before connecting again."
        }
    }
}

struct ConnectionPersistenceStore: @unchecked Sendable {
    let load: () -> Data?
    let save: (Data) throws -> Void
    let restore: (Data?) throws -> Void

    static let live = ConnectionPersistenceStore(
        load: { UserDefaults.standard.data(forKey: UserDefaultsKeys.connections) },
        save: { data in
            UserDefaults.standard.set(data, forKey: UserDefaultsKeys.connections)
            guard UserDefaults.standard.data(forKey: UserDefaultsKeys.connections) == data else {
                throw ConnectionPersistenceError.readbackMismatch
            }
        },
        restore: { data in
            if let data {
                UserDefaults.standard.set(data, forKey: UserDefaultsKeys.connections)
            } else {
                UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.connections)
            }
            guard UserDefaults.standard.data(forKey: UserDefaultsKeys.connections) == data else {
                throw ConnectionPersistenceError.rollbackFailed
            }
        }
    )
}

enum DatabaseConnectionLibraryMode: String, CaseIterable, Identifiable, Hashable {
    case all
    case favorites
    case recent
    case collections

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "All"
        case .favorites: return "Favorites"
        case .recent: return "Recent"
        case .collections: return "Collections"
        }
    }
}

enum DatabaseConnectionLibraryScope: Hashable, Identifiable {
    case allConnections
    case favorites
    case recent
    case collection(String)

    var id: String {
        switch self {
        case .allConnections: return "all-connections"
        case .favorites: return "favorites"
        case .recent: return "recent"
        case .collection(let id): return "collection-\(id)"
        }
    }
}

struct DatabaseConnectionLibraryCollection: Identifiable, Hashable {
    let id: String
    let name: String
    let connectionIDs: [UUID]

    var count: Int { connectionIDs.count }
}

/// A transient, read-only library view over ConnectionManager's persisted
/// records. Scopes never become a second connection catalog.
struct DatabaseConnectionLibraryProjection {
    let connections: [DatabaseConnectionConfig]
    let favoriteConnectionIDs: [UUID]
    let recentConnectionIDs: [UUID]
    let collections: [DatabaseConnectionLibraryCollection]

    private struct CollectionAccumulator {
        var names: Set<String> = []
        var connectionIDs: [UUID] = []
    }

    init(
        connections: [DatabaseConnectionConfig],
        recentLimit: Int = 10
    ) {
        var seenConnectionIDs = Set<UUID>()
        let uniqueConnections = connections.filter {
            seenConnectionIDs.insert($0.id).inserted
        }
        let orderedConnections = uniqueConnections.sorted(by: Self.connectionOrder)
        self.connections = orderedConnections
        let connectionIndexByID = Dictionary(
            uniqueKeysWithValues: orderedConnections.enumerated().map {
                ($0.element.id, $0.offset)
            }
        )

        favoriteConnectionIDs = uniqueConnections
            .filter(\.isFavorite)
            .sorted(by: Self.activityOrder)
            .map(\.id)

        recentConnectionIDs = uniqueConnections
            .filter { $0.lastConnected != nil }
            .sorted(by: Self.recentOrder)
            .prefix(max(0, recentLimit))
            .map(\.id)

        var collectionsByID: [String: CollectionAccumulator] = [:]
        for connection in uniqueConnections {
            var connectionCollectionIDs = Set<String>()
            for rawTag in connection.tags {
                let name = rawTag.trimmingCharacters(in: .whitespacesAndNewlines)
                guard let id = Self.collectionID(for: name),
                      connectionCollectionIDs.insert(id).inserted else {
                    continue
                }
                var accumulator = collectionsByID[id, default: CollectionAccumulator()]
                accumulator.names.insert(name)
                accumulator.connectionIDs.append(connection.id)
                collectionsByID[id] = accumulator
            }
        }

        collections = collectionsByID.map { id, accumulator in
            DatabaseConnectionLibraryCollection(
                id: id,
                name: accumulator.names.sorted(by: Self.displayOrder).first ?? id,
                connectionIDs: accumulator.connectionIDs.sorted {
                    (connectionIndexByID[$0] ?? .max)
                        < (connectionIndexByID[$1] ?? .max)
                }
            )
        }
        .sorted { Self.displayOrder($0.name, $1.name) }
    }

    func connections(
        in scope: DatabaseConnectionLibraryScope,
        searchQuery: String = ""
    ) -> [DatabaseConnectionConfig] {
        let candidates: [DatabaseConnectionConfig]
        switch scope {
        case .allConnections:
            candidates = connections
        case .favorites:
            candidates = connections(withIDs: favoriteConnectionIDs)
        case .recent:
            candidates = connections(withIDs: recentConnectionIDs)
        case .collection(let collectionID):
            candidates = connections(
                withIDs: collections.first { $0.id == collectionID }?.connectionIDs ?? []
            )
        }

        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return candidates }
        return candidates.filter { connection in
            connection.name.localizedCaseInsensitiveContains(query)
                || connection.engine.displayName.localizedCaseInsensitiveContains(query)
                || connection.host.localizedCaseInsensitiveContains(query)
                || connection.username.localizedCaseInsensitiveContains(query)
                || (connection.defaultDatabase ?? "").localizedCaseInsensitiveContains(query)
                || connection.tags.contains {
                    $0.localizedCaseInsensitiveContains(query)
                }
        }
    }

    func resolvedSelection(
        preferredConnectionID: UUID?,
        in scope: DatabaseConnectionLibraryScope,
        searchQuery: String = ""
    ) -> UUID? {
        guard let preferredConnectionID else { return nil }
        return connections(in: scope, searchQuery: searchQuery)
            .contains { $0.id == preferredConnectionID }
            ? preferredConnectionID
            : nil
    }

    func itemCount(in scope: DatabaseConnectionLibraryScope) -> Int {
        connections(in: scope).count
    }

    func collection(named name: String) -> DatabaseConnectionLibraryCollection? {
        guard let id = Self.collectionID(for: name) else { return nil }
        return collections.first { $0.id == id }
    }

    static func normalizedTags(_ rawTags: [String]) -> [String] {
        var namesByID: [String: Set<String>] = [:]
        for rawTag in rawTags {
            let name = rawTag.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let id = collectionID(for: name) else { continue }
            namesByID[id, default: []].insert(name)
        }
        return namesByID.values
            .compactMap { $0.sorted(by: displayOrder).first }
            .sorted(by: displayOrder)
    }

    static func collectionID(for name: String) -> String? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return trimmed
            .folding(
                options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
                locale: Locale(identifier: "en_US_POSIX")
            )
            .lowercased(with: Locale(identifier: "en_US_POSIX"))
    }

    private func connections(withIDs ids: [UUID]) -> [DatabaseConnectionConfig] {
        let connectionsByID = Dictionary(
            uniqueKeysWithValues: connections.map { ($0.id, $0) }
        )
        return ids.compactMap { connectionsByID[$0] }
    }

    private static func activityOrder(
        _ lhs: DatabaseConnectionConfig,
        _ rhs: DatabaseConnectionConfig
    ) -> Bool {
        let lhsDate = lhs.lastConnected ?? lhs.dateAdded
        let rhsDate = rhs.lastConnected ?? rhs.dateAdded
        if lhsDate != rhsDate { return lhsDate > rhsDate }
        return connectionOrder(lhs, rhs)
    }

    private static func recentOrder(
        _ lhs: DatabaseConnectionConfig,
        _ rhs: DatabaseConnectionConfig
    ) -> Bool {
        if lhs.lastConnected != rhs.lastConnected {
            return (lhs.lastConnected ?? .distantPast)
                > (rhs.lastConnected ?? .distantPast)
        }
        return connectionOrder(lhs, rhs)
    }

    private static func connectionOrder(
        _ lhs: DatabaseConnectionConfig,
        _ rhs: DatabaseConnectionConfig
    ) -> Bool {
        if displayOrder(lhs.name, rhs.name) { return true }
        if displayOrder(rhs.name, lhs.name) { return false }
        if lhs.host != rhs.host { return lhs.host < rhs.host }
        if lhs.username != rhs.username { return lhs.username < rhs.username }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    private static func displayOrder(_ lhs: String, _ rhs: String) -> Bool {
        let comparison = lhs.localizedCaseInsensitiveCompare(rhs)
        if comparison != .orderedSame {
            return comparison == .orderedAscending
        }
        return lhs < rhs
    }
}

@MainActor
@Observable
class ConnectionManager {
    var connections: [DatabaseConnectionConfig] = []
    var credentialError: String?

    private var hasLoaded = false
    private let persistenceStore: ConnectionPersistenceStore

    init(
        loadImmediately: Bool = true,
        persistenceStore: ConnectionPersistenceStore = .live
    ) {
        self.persistenceStore = persistenceStore
        if loadImmediately {
            loadIfNeeded()
        }
    }

    func loadIfNeeded() {
        guard !hasLoaded else { return }
        hasLoaded = true
        load()
        do {
            _ = try KeychainManager.runMigrationsIfNeeded(connections: connections)
        } catch {
            credentialError = error.localizedDescription
            Logger.keychain.error("Credential migration failed without exposing credential material: \(error.localizedDescription)")
        }
    }

    func load() {
        guard let data = persistenceStore.load() else {
            connections = []
            return
        }

        do {
            connections = try JSONDecoder().decode([DatabaseConnectionConfig].self, from: data)
        } catch {
            Logger.connections.error("Failed to load connections: \(error)")
            connections = []
        }
    }

    func save() throws {
        try persist(connections)
    }

    func add(_ connection: DatabaseConnectionConfig) throws {
        var candidate = connections
        candidate.append(connection)
        try persist(candidate)
        connections = candidate
    }

    func update(_ connection: DatabaseConnectionConfig) throws {
        if let index = connections.firstIndex(where: { $0.id == connection.id }) {
            let previous = connections[index]
            var candidate = connections
            candidate[index] = connection
            try persist(candidate)
            connections = candidate
            removeUnreferencedSQLiteFile(from: previous, replacingWith: connection)
        }
    }

    func connection(for id: UUID) -> DatabaseConnectionConfig? {
        connections.first { $0.id == id }
    }

    func delete(_ connection: DatabaseConnectionConfig) throws {
        let credentialReceipt = try KeychainManager.deleteCredentials(for: connection)
        let candidate = connections.filter { $0.id != connection.id }
        do {
            try persist(candidate)
        } catch {
            do {
                try KeychainManager.restoreCredentials(credentialReceipt)
            } catch {
                throw ConnectionPersistenceError.credentialRollbackFailed
            }
            throw error
        }
        connections = candidate
        removeUnreferencedSQLiteFile(from: connection, replacingWith: nil)
    }

    private func removeUnreferencedSQLiteFile(
        from previous: DatabaseConnectionConfig,
        replacingWith replacement: DatabaseConnectionConfig?
    ) {
        guard previous.engine == .sqlite,
              replacement?.engine != .sqlite || replacement?.host != previous.host,
              !connections.contains(where: { $0.engine == .sqlite && $0.host == previous.host }) else {
            return
        }
        do {
            let managedURL = try SQLiteFileImporter.validatedURL(forPath: previous.host)
            try FileManager.default.removeItem(at: managedURL)
        } catch SQLiteFileImporter.ImportError.managedCopyMissing {
            return
        } catch {
            Logger.connections.error(
                "Failed to remove unreferenced SQLite database: \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    func updateLastConnected(_ connectionID: UUID) {
        if let index = connections.firstIndex(where: { $0.id == connectionID }) {
            var candidate = connections
            candidate[index].lastConnected = Date()
            do {
                try persist(candidate)
                connections = candidate
            } catch {
                credentialError = "The connection succeeded, but its recent-connection timestamp could not be saved. \(error.localizedDescription)"
            }
        }
    }

    func toggleFavorite(_ connection: DatabaseConnectionConfig) {
        if let index = connections.firstIndex(where: { $0.id == connection.id }) {
            var candidate = connections
            candidate[index].isFavorite.toggle()
            do {
                try persist(candidate)
                connections = candidate
            } catch {
                credentialError = "The favorite change could not be saved, so it was not applied. \(error.localizedDescription)"
            }
        }
    }

    private func persist(_ candidate: [DatabaseConnectionConfig]) throws {
        let data = try JSONEncoder().encode(candidate)
        let previousData = persistenceStore.load()
        do {
            try persistenceStore.save(data)
        } catch {
            do {
                try persistenceStore.restore(previousData)
                guard persistenceStore.load() == previousData else {
                    throw ConnectionPersistenceError.rollbackFailed
                }
            } catch {
                throw ConnectionPersistenceError.rollbackFailed
            }
            throw error
        }
    }

    var favoriteConnections: [DatabaseConnectionConfig] {
        connections.filter { $0.isFavorite }
            .sorted { ($0.lastConnected ?? $0.dateAdded) > ($1.lastConnected ?? $1.dateAdded) }
    }

    var recentConnections: [DatabaseConnectionConfig] {
        connections
            .filter { $0.lastConnected != nil }
            .sorted { $0.lastConnected! > $1.lastConnected! }
            .prefix(10)
            .map { $0 }
    }

    var allTags: [String] {
        Array(Set(connections.flatMap { $0.tags })).sorted()
    }
}
