//
//  ConnectionManagerView.swift
//  glassdb
//
//  Main hub — saved database connections
//  Pattern adapted from glas.sh ConnectionManagerView
//

import SwiftUI
import UIKit
import os
import GlasSecretStore
import GlassDBKit

private struct PendingHostTrustAttempt {
    let connection: DatabaseConnectionConfig
    let password: String
    let sshPassword: String?
    let challenge: SSHHostKeyChallenge
}

struct ConnectionManagerView: View {
    @Environment(ConnectionManager.self) private var connectionManager
    @Environment(DatabaseSessionManager.self) private var sessionManager
    @Environment(SettingsManager.self) private var settingsManager
    @Environment(\.openWindow) private var openWindow

    @State private var selectedConnectionID: UUID?
    @State private var searchText = ""
    @State private var connectingConnectionID: UUID?
    @State private var connectionError: String?
    @State private var showingAddConnection = false
    @State private var editingConnection: DatabaseConnectionConfig?
    @State private var pendingHostTrustAttempt: PendingHostTrustAttempt?

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detailView
        }
        .sheet(isPresented: $showingAddConnection) {
            ConnectionFormView(mode: .add) { connection, password, sshPassword in
                try saveCredentials(
                    password: password,
                    sshPassword: sshPassword,
                    for: connection,
                    replacing: nil
                )
                connectionManager.add(connection)
            }
            .environment(sessionManager)
            .environment(settingsManager)
        }
        .sheet(item: $editingConnection) { connection in
            ConnectionFormView(mode: .edit(connection)) { updated, password, sshPassword in
                try saveCredentials(
                    password: password,
                    sshPassword: sshPassword,
                    for: updated,
                    replacing: connection
                )
                connectionManager.update(updated)
            }
            .environment(sessionManager)
            .environment(settingsManager)
        }
        .alert("Connection Error", isPresented: .init(
            get: { connectionError != nil || connectionManager.credentialError != nil },
            set: {
                if !$0 {
                    connectionError = nil
                    connectionManager.credentialError = nil
                }
            }
        )) {
            Button("OK") { connectionError = nil }
        } message: {
            Text(connectionError ?? connectionManager.credentialError ?? "")
        }
        .alert(
            pendingHostTrustAttempt?.challenge.reason == .changed ? "SSH Host Key Changed" : "Verify SSH Host",
            isPresented: .init(
                get: { pendingHostTrustAttempt != nil },
                set: { if !$0 { pendingHostTrustAttempt = nil } }
            )
        ) {
            Button("Trust & Retry", role: pendingHostTrustAttempt?.challenge.reason == .changed ? .destructive : nil) {
                trustPendingHostAndRetry()
            }
            Button("Cancel", role: .cancel) { pendingHostTrustAttempt = nil }
        } message: {
            if let challenge = pendingHostTrustAttempt?.challenge {
                Text("Host: \(challenge.host):\(challenge.port)\nAlgorithm: \(challenge.algorithm)\nFingerprint: \(challenge.fingerprintSHA256)\n\n\(challenge.reason == .changed ? "The saved host identity no longer matches. Confirm the server’s new fingerprint through a trusted channel before continuing." : "Confirm this fingerprint through a trusted channel before saving it.")")
            }
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List(selection: $selectedConnectionID) {
            if !connectionManager.favoriteConnections.isEmpty {
                Section("Favorites") {
                    ForEach(filteredConnections(connectionManager.favoriteConnections)) { conn in
                        connectionRow(conn)
                    }
                }
            }

            if !connectionManager.recentConnections.isEmpty {
                Section("Recent") {
                    ForEach(filteredConnections(connectionManager.recentConnections)) { conn in
                        connectionRow(conn)
                    }
                }
            }

            Section("All Connections") {
                ForEach(filteredConnections(connectionManager.connections)) { conn in
                    connectionRow(conn)
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search connections...")
        .scrollInputBehavior(.enabled, for: .look)
        .navigationTitle("glassdb")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddConnection = true
                } label: {
                    Label("Add Connection", systemImage: "plus")
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    openWindow(id: "settings")
                } label: {
                    Label("Settings", systemImage: "gear")
                }
            }
        }
    }

    // MARK: - Connection Row

    private func connectionRow(_ connection: DatabaseConnectionConfig) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(connection.colorTag.color)
                .frame(width: 8, height: 8)
                .accessibilityLabel(connection.colorTag == .none ? "" : "\(connection.colorTag.displayName) tag")
                .accessibilityHidden(connection.colorTag == .none)

            VStack(alignment: .leading, spacing: 2) {
                Text(connection.name)
                    .font(.headline)
                Text(connection.displaySubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if activeSessionID(for: connection) != nil {
                Image(systemName: "bolt.fill")
                    .foregroundStyle(.green)
                    .font(.caption)
                    .accessibilityLabel("Active connection")
            }

            if connection.isFavorite {
                Image(systemName: "star.fill")
                    .foregroundStyle(.yellow)
                    .font(.caption)
                    .accessibilityLabel("Favorite")
            }
        }
        .tag(connection.id)
        .contextMenu {
            Button("Connect") { initiateConnection(connection) }
            Button(connection.isFavorite ? "Unfavorite" : "Favorite") {
                connectionManager.toggleFavorite(connection)
            }
            Divider()
            Button("Edit...") { editingConnection = connection }
            Button("Delete", role: .destructive) {
                do {
                    try connectionManager.delete(connection)
                } catch {
                    connectionError = "The connection was not deleted because its saved credentials could not be removed. \(error.localizedDescription)"
                }
            }
        }
    }

    // MARK: - Detail View

    @ViewBuilder
    private var detailView: some View {
        if let id = selectedConnectionID,
           let connection = connectionManager.connection(for: id) {
            VStack(spacing: 24) {
                connectionDetailHeader(connection)
                connectionDetailActions(connection)
            }
            .padding(32)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ContentUnavailableView(
                "Select a Connection",
                systemImage: "cylinder",
                description: Text("Choose a database connection from the sidebar or add a new one.")
            )
        }
    }

    private func connectionDetailHeader(_ connection: DatabaseConnectionConfig) -> some View {
        VStack(spacing: 12) {
            Image(systemName: connection.engine.iconName)
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text(connection.name)
                .font(.title)

            Text(connection.displaySubtitle)
                .font(.body)
                .foregroundStyle(.secondary)

            if activeSessionID(for: connection) != nil {
                Label("Connected", systemImage: "bolt.fill")
                    .foregroundStyle(.green)
                    .font(.callout)
            }
        }
    }

    private func connectionDetailActions(_ connection: DatabaseConnectionConfig) -> some View {
        HStack(spacing: 16) {
            if let sessionID = activeSessionID(for: connection) {
                Button {
                    openWindow(id: "query-editor", value: sessionID)
                } label: {
                    Label("Workspace", systemImage: "rectangle.split.2x1")
                }
                .buttonStyle(.borderedProminent)

                Button(role: .destructive) {
                    Task { await sessionManager.disconnect(sessionID: sessionID) }
                } label: {
                    Label("Disconnect", systemImage: "xmark.circle")
                }
            } else {
                Button {
                    initiateConnection(connection)
                } label: {
                    Label("Connect", systemImage: "bolt")
                }
                .buttonStyle(.borderedProminent)
            }

            Button {
                editingConnection = connection
            } label: {
                Label("Edit", systemImage: "pencil")
            }
        }
    }

    // MARK: - Connection Logic

    private func initiateConnection(_ connection: DatabaseConnectionConfig) {
        do {
            let dbPassword: String
            if connection.engine.supportsCredentials {
                do {
                    dbPassword = try KeychainManager.retrievePassword(for: connection)
                } catch SecretStoreError.notFound {
                    dbPassword = ""
                }
            } else {
                dbPassword = ""
            }
            let usesSSHKey = connection.sshAuthMethod == .sshKey
            var sshPassword: String?
            if connection.useSSHTunnel && !usesSSHKey {
                do {
                    sshPassword = try KeychainManager.retrieveSSHPassword(for: connection)
                } catch SecretStoreError.notFound {
                    sshPassword = ""
                }
            }
            Task { await connectWith(connection, password: dbPassword, sshPassword: sshPassword) }
        } catch {
            connectionError = "Saved credentials are unavailable. Edit this connection and save its credentials again. \(error.localizedDescription)"
        }
    }

    private func connectWith(_ connection: DatabaseConnectionConfig, password: String, sshPassword: String? = nil) async {
        connectingConnectionID = connection.id
        do {
            let sessionID = try await sessionManager.connect(
                config: connection,
                password: password,
                sshPassword: sshPassword
            )
            connectionManager.updateLastConnected(connection.id)
            openWindow(id: "query-editor", value: sessionID)
        } catch let trustError as SSHHostKeyTrustRequiredError {
            pendingHostTrustAttempt = PendingHostTrustAttempt(
                connection: connection,
                password: password,
                sshPassword: sshPassword,
                challenge: trustError.challenge
            )
        } catch {
            connectionError = error.localizedDescription
        }
        connectingConnectionID = nil
    }

    private func trustPendingHostAndRetry() {
        guard let attempt = pendingHostTrustAttempt else { return }
        do {
            try KeychainManager.saveHostKey(attempt.challenge)
            pendingHostTrustAttempt = nil
            Task {
                await connectWith(
                    attempt.connection,
                    password: attempt.password,
                    sshPassword: attempt.sshPassword
                )
            }
        } catch {
            pendingHostTrustAttempt = nil
            connectionError = "The SSH host key was not trusted because it could not be saved securely. \(error.localizedDescription)"
        }
    }

    private func activeSessionID(for connection: DatabaseConnectionConfig) -> UUID? {
        sessionManager.sessions.first { _, session in
            session.connectionConfig.id == connection.id && session.state.isConnected
        }?.key
    }

    // MARK: - Credential Persistence

    private func saveCredentials(
        password: String,
        sshPassword: String?,
        for connection: DatabaseConnectionConfig,
        replacing previousConnection: DatabaseConnectionConfig?
    ) throws {
        let report = try KeychainManager.saveCredentials(
            databasePassword: password,
            sshPassword: sshPassword,
            for: connection,
            replacing: previousConnection
        )
        if connection.engine == .sqlite,
           let previousConnection,
           previousConnection.engine.supportsCredentials {
            try KeychainManager.deletePassword(for: previousConnection)
        }
        if !password.isEmpty {
            Logger.connections.info("Saved database password for connection \(connection.id, privacy: .public)")
        }
        if let sshPassword, !sshPassword.isEmpty {
            Logger.connections.info("Saved SSH password for connection \(connection.id, privacy: .public)")
        }
        if !report.cleanupWarnings.isEmpty {
            connectionManager.credentialError = report.cleanupWarnings.joined(separator: " ")
        }
    }

    // MARK: - Filtering

    private func filteredConnections(_ connections: [DatabaseConnectionConfig]) -> [DatabaseConnectionConfig] {
        guard !searchText.isEmpty else { return connections }
        return connections.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.host.localizedCaseInsensitiveContains(searchText) ||
            $0.username.localizedCaseInsensitiveContains(searchText) ||
            ($0.defaultDatabase ?? "").localizedCaseInsensitiveContains(searchText)
        }
    }
}
