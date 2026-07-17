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

@MainActor
@Observable
class ConnectionManager {
    var connections: [DatabaseConnectionConfig] = []
    var credentialError: String?

    private var hasLoaded = false

    init(loadImmediately: Bool = true) {
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
        guard let data = UserDefaults.standard.data(forKey: UserDefaultsKeys.connections) else {
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

    func save() {
        do {
            let data = try JSONEncoder().encode(connections)
            UserDefaults.standard.set(data, forKey: UserDefaultsKeys.connections)
        } catch {
            Logger.connections.error("Failed to save connections: \(error)")
        }
    }

    func add(_ connection: DatabaseConnectionConfig) {
        connections.append(connection)
        save()
    }

    func update(_ connection: DatabaseConnectionConfig) {
        if let index = connections.firstIndex(where: { $0.id == connection.id }) {
            connections[index] = connection
            save()
        }
    }

    func connection(for id: UUID) -> DatabaseConnectionConfig? {
        connections.first { $0.id == id }
    }

    func delete(_ connection: DatabaseConnectionConfig) throws {
        if connection.engine.supportsCredentials {
            try KeychainManager.deletePassword(for: connection)
        }
        if connection.useSSHTunnel, connection.sshAuthMethod != .sshKey {
            try KeychainManager.deleteSSHPassword(for: connection)
        }
        connections.removeAll { $0.id == connection.id }
        save()
    }

    func updateLastConnected(_ connectionID: UUID) {
        if let index = connections.firstIndex(where: { $0.id == connectionID }) {
            connections[index].lastConnected = Date()
            save()
        }
    }

    func toggleFavorite(_ connection: DatabaseConnectionConfig) {
        if let index = connections.firstIndex(where: { $0.id == connection.id }) {
            connections[index].isFavorite.toggle()
            save()
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
