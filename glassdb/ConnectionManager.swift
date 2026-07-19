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
