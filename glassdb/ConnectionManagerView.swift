//
//  ConnectionManagerView.swift
//  glassdb
//
//  Main hub — saved database connections
//  Pattern adapted from glas.sh ConnectionManagerView
//

import SwiftUI
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
    @State private var connectionPendingDeletion: DatabaseConnectionConfig?
    @State private var pendingHostTrustAttempt: PendingHostTrustAttempt?
    @FocusState private var searchFieldFocused: Bool

    var body: some View {
        NavigationSplitView {
            sidebar
                .databaseSidebarColumnWidth()
        } detail: {
            detailView
        }
        .sheet(isPresented: $showingAddConnection) {
            ConnectionFormView(mode: .add) { connection, password, sshPassword in
                let credentialReceipt = try saveCredentials(
                    password: password,
                    sshPassword: sshPassword,
                    for: connection,
                    replacing: nil
                )
                do {
                    try connectionManager.add(connection)
                    searchText = ""
                    selectedConnectionID = connection.id
                } catch {
                    try restoreCredentials(credentialReceipt, after: error)
                }
            }
            .environment(sessionManager)
            .environment(settingsManager)
        }
        .sheet(item: $editingConnection) { connection in
            ConnectionFormView(mode: .edit(connection)) { updated, password, sshPassword in
                let credentialReceipt = try saveCredentials(
                    password: password,
                    sshPassword: sshPassword,
                    for: updated,
                    replacing: connection
                )
                do {
                    try connectionManager.update(updated)
                } catch {
                    try restoreCredentials(credentialReceipt, after: error)
                }
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
        .alert(
            "Delete Connection?",
            isPresented: .init(
                get: { connectionPendingDeletion != nil },
                set: { if !$0 { connectionPendingDeletion = nil } }
            ),
            presenting: connectionPendingDeletion
        ) { connection in
            Button("Delete \(connection.name)", role: .destructive) {
                deleteConnection(connection)
            }
            Button("Cancel", role: .cancel) {
                connectionPendingDeletion = nil
            }
        } message: { connection in
            Text(deletionConfirmationMessage(for: connection))
        }
        .onAppear {
            if selectedConnectionID == nil {
                selectedConnectionID = connectionManager.connections.first?.id
            }
        }
        .onChange(of: connectionManager.connections.map(\.id)) { _, ids in
            if let selectedConnectionID, !ids.contains(selectedConnectionID) {
                self.selectedConnectionID = ids.first
            } else if selectedConnectionID == nil {
                selectedConnectionID = ids.first
            }
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List(selection: $selectedConnectionID) {
            if connectionManager.connections.isEmpty {
                ContentUnavailableView {
                    Label("No Connections", systemImage: "cylinder.split.1x2")
                } description: {
                    Text("Add a database connection to begin.")
                } actions: {
                    Button("Add Connection", systemImage: "plus") {
                        showingAddConnection = true
                    }
                }
                .listRowBackground(Color.clear)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 12)
            } else if filteredConnections(connectionManager.connections).isEmpty {
                ContentUnavailableView.search(text: searchText)
                    .listRowBackground(Color.clear)
            } else if !filteredConnections(connectionManager.favoriteConnections).isEmpty {
                Section("Favorites") {
                    ForEach(filteredConnections(connectionManager.favoriteConnections)) { conn in
                        connectionRow(conn)
                    }
                }
            }

            if !connectionManager.connections.isEmpty,
               !filteredConnections(connectionManager.connections).isEmpty,
               !filteredConnections(connectionManager.recentConnections).isEmpty {
                Section("Recent") {
                    ForEach(filteredConnections(connectionManager.recentConnections)) { conn in
                        connectionRow(conn)
                    }
                }
            }

            if !connectionManager.connections.isEmpty,
               !filteredConnections(connectionManager.connections).isEmpty {
                Section("All Connections") {
                    ForEach(filteredConnections(connectionManager.connections)) { conn in
                        connectionRow(conn)
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search connections...")
        .searchFocused($searchFieldFocused)
        .databaseLookScrollEnabled()
        .navigationTitle("glassdb")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddConnection = true
                } label: {
                    Label("Add Connection", systemImage: "plus")
                }
                .managerNewConnectionShortcut()
                .help("Add a database connection (Command-N)")
            }
            #if !os(macOS)
            ToolbarItem(placement: .primaryAction) {
                Button {
                    openWindow(id: "settings")
                } label: {
                    Label("Settings", systemImage: "gear")
                }
                .help("Open glassdb settings")
            }
            #endif
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
                    .lineLimit(1)
                Text(connection.displaySubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
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

            #if os(macOS)
            Menu {
                connectionActions(for: connection)
            } label: {
                Image(systemName: "ellipsis.circle")
                    .accessibilityLabel("Actions for \(connection.name)")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("Connection actions")
            #endif
        }
        .contentShape(Rectangle())
        .tag(connection.id)
        .connectionRowDoubleClick {
            if let sessionID = activeSessionID(for: connection) {
                openWindow(id: "query-editor", value: sessionID)
            } else {
                initiateConnection(connection)
            }
        }
        .contextMenu {
            connectionActions(for: connection)
        }
        .help("Select \(connection.name); double-click to connect or open its workspace")
    }

    @ViewBuilder
    private func connectionActions(for connection: DatabaseConnectionConfig) -> some View {
        if let sessionID = activeSessionID(for: connection) {
            Button("Open Workspace", systemImage: "rectangle.split.2x1") {
                openWindow(id: "query-editor", value: sessionID)
            }
            Button("Disconnect", systemImage: "xmark.circle") {
                Task { await sessionManager.disconnect(sessionID: sessionID) }
            }
        } else {
            Button("Connect", systemImage: "bolt") {
                initiateConnection(connection)
            }
            .disabled(connectingConnectionID != nil)
        }
        Divider()
        Button(connection.isFavorite ? "Remove from Favorites" : "Add to Favorites",
               systemImage: connection.isFavorite ? "star.slash" : "star") {
            connectionManager.toggleFavorite(connection)
        }
        Button("Edit Connection…", systemImage: "pencil") {
            editingConnection = connection
        }
        Divider()
        Button("Delete Connection…", systemImage: "trash", role: .destructive) {
            connectionPendingDeletion = connection
        }
        .disabled(activeSessionID(for: connection) != nil)
        .help(activeSessionID(for: connection) == nil
              ? "Delete this saved connection"
              : "Disconnect this connection before deleting it")
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
        } else if connectionManager.connections.isEmpty {
            ContentUnavailableView {
                Label("No Connections", systemImage: "cylinder.split.1x2")
            } description: {
                Text("Add a MySQL, PostgreSQL, or SQLite connection to begin.")
            } actions: {
                Button("Add Connection", systemImage: "plus") {
                    showingAddConnection = true
                }
                .buttonStyle(.borderedProminent)
            }
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
                .lineLimit(2)
                .multilineTextAlignment(.center)

            Text(connection.displaySubtitle)
                .font(.body)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .truncationMode(.middle)
                .multilineTextAlignment(.center)

            if activeSessionID(for: connection) != nil {
                Label("Connected", systemImage: "bolt.fill")
                    .foregroundStyle(.green)
                    .font(.callout)
            }
        }
    }

    private func connectionDetailActions(_ connection: DatabaseConnectionConfig) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 16) {
                connectionDetailActionButtons(connection)
            }
            VStack(spacing: 12) {
                connectionDetailActionButtons(connection)
            }
        }
    }

    @ViewBuilder
    private func connectionDetailActionButtons(_ connection: DatabaseConnectionConfig) -> some View {
        if let sessionID = activeSessionID(for: connection) {
            Button {
                openWindow(id: "query-editor", value: sessionID)
            } label: {
                Label("Open Workspace", systemImage: "rectangle.split.2x1")
            }
            .buttonStyle(.borderedProminent)
            .help("Open the SQL editor for this active connection")

            Button(role: .destructive) {
                Task { await sessionManager.disconnect(sessionID: sessionID) }
            } label: {
                Label("Disconnect", systemImage: "xmark.circle")
            }
            .help("Close this database session")
        } else {
            Button {
                initiateConnection(connection)
            } label: {
                if connectingConnectionID == connection.id {
                    Label("Connecting…", systemImage: "bolt.horizontal.circle")
                } else {
                    Label("Connect", systemImage: "bolt")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(connectingConnectionID != nil)
            .help("Connect and open the SQL workspace")
        }

        Button {
            editingConnection = connection
        } label: {
            Label("Edit", systemImage: "pencil")
        }
        .disabled(connectingConnectionID == connection.id)
        .help("Edit connection, authentication, TLS, and SSH settings")
    }

    private func deletionConfirmationMessage(for connection: DatabaseConnectionConfig) -> String {
        if connection.engine == .sqlite {
            return "This removes the saved connection, its credentials, and its managed SQLite working copy. The original imported file is not changed. This action cannot be undone."
        }
        return "This removes the saved connection and its database and SSH credentials. The database server is not changed. This action cannot be undone."
    }

    private func deleteConnection(_ connection: DatabaseConnectionConfig) {
        connectionPendingDeletion = nil
        do {
            try connectionManager.delete(connection)
            if selectedConnectionID == connection.id {
                selectedConnectionID = connectionManager.connections.first?.id
            }
        } catch {
            connectionError = "The connection was not deleted safely. \(error.localizedDescription)"
        }
    }

    // MARK: - Connection Logic

    private func initiateConnection(_ connection: DatabaseConnectionConfig) {
        guard connectingConnectionID == nil else { return }
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
    ) throws -> KeychainManager.CredentialDeletionReceipt {
        let report = try KeychainManager.saveCredentials(
            databasePassword: password,
            sshPassword: sshPassword,
            for: connection,
            replacing: previousConnection
        )
        if !password.isEmpty {
            Logger.connections.info("Saved database password for connection \(connection.id, privacy: .public)")
        }
        if let sshPassword, !sshPassword.isEmpty {
            Logger.connections.info("Saved SSH password for connection \(connection.id, privacy: .public)")
        }
        if !report.cleanupWarnings.isEmpty {
            connectionManager.credentialError = report.cleanupWarnings.joined(separator: " ")
        }
        return report.rollbackReceipt
    }

    private func restoreCredentials(
        _ receipt: KeychainManager.CredentialDeletionReceipt,
        after persistenceError: Error
    ) throws -> Never {
        do {
            try KeychainManager.restoreCredentials(receipt)
        } catch {
            throw KeychainManager.CredentialPolicyError.mutationRollbackFailed
        }
        throw persistenceError
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

private extension View {
    @ViewBuilder
    func managerNewConnectionShortcut() -> some View {
        #if os(macOS)
        self.keyboardShortcut("n", modifiers: [.command])
        #else
        self
        #endif
    }

    @ViewBuilder
    func connectionRowDoubleClick(perform action: @escaping () -> Void) -> some View {
        #if os(macOS)
        self.onTapGesture(count: 2, perform: action)
        #else
        self
        #endif
    }
}
