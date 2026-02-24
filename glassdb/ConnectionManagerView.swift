//
//  ConnectionManagerView.swift
//  glassdb
//
//  Main hub — saved database connections
//  Pattern adapted from glas.sh ConnectionManagerView
//

import SwiftUI
import os

struct ConnectionManagerView: View {
    @Environment(ConnectionManager.self) private var connectionManager
    @Environment(DatabaseSessionManager.self) private var sessionManager
    @Environment(SettingsManager.self) private var settingsManager
    @Environment(\.openWindow) private var openWindow

    @State private var selectedConnectionID: UUID?
    @State private var searchText = ""
    @State private var showingAddConnection = false
    @State private var editingConnection: DatabaseConnectionConfig?
    @State private var connectingConnectionID: UUID?
    @State private var passwordPromptConnection: DatabaseConnectionConfig?
    @State private var passwordInput = ""
    @State private var sshPasswordInput = ""
    @State private var needsSSHPassword = false
    @State private var showPromptPassword = false
    @State private var showPromptSSHPassword = false
    @State private var connectionError: String?

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detailView
        }
        .sheet(isPresented: $showingAddConnection) {
            ConnectionFormView(mode: .add) { connection, password, sshPassword in
                connectionManager.add(connection)
                saveCredentials(password: password, sshPassword: sshPassword, for: connection)
            }
        }
        .sheet(item: $editingConnection) { connection in
            ConnectionFormView(mode: .edit(connection)) { updated, password, sshPassword in
                connectionManager.update(updated)
                saveCredentials(password: password, sshPassword: sshPassword, for: updated)
            }
        }
        .sheet(isPresented: .init(
            get: { passwordPromptConnection != nil },
            set: { if !$0 { clearPasswordPrompt() } }
        )) {
            credentialPromptSheet
        }
        .alert("Connection Error", isPresented: .init(
            get: { connectionError != nil },
            set: { if !$0 { connectionError = nil } }
        )) {
            Button("OK") { connectionError = nil }
        } message: {
            Text(connectionError ?? "")
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

            VStack(alignment: .leading, spacing: 2) {
                Text(connection.name)
                    .font(.headline)
                Text(connection.displaySubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let sessionID = activeSessionID(for: connection) {
                Image(systemName: "bolt.fill")
                    .foregroundStyle(.green)
                    .font(.caption)
            }

            if connection.isFavorite {
                Image(systemName: "star.fill")
                    .foregroundStyle(.yellow)
                    .font(.caption)
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
                connectionManager.delete(connection)
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

            if let sessionID = activeSessionID(for: connection),
               let session = sessionManager.session(for: sessionID) {
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
                    Label("Query Editor", systemImage: "text.page")
                }
                .buttonStyle(.borderedProminent)

                Button {
                    openWindow(id: "schema", value: sessionID)
                } label: {
                    Label("Schema", systemImage: "list.bullet.indent")
                }

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

    // MARK: - Credential Prompt Sheet

    private var credentialPromptSheet: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        if showPromptPassword {
                            TextField("Database Password", text: $passwordInput)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                        } else {
                            SecureField("Database Password", text: $passwordInput)
                                .textContentType(.password)
                        }
                        Button {
                            showPromptPassword.toggle()
                        } label: {
                            Image(systemName: showPromptPassword ? "eye.slash" : "eye")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    if needsSSHPassword {
                        HStack {
                            if showPromptSSHPassword {
                                TextField("SSH Password", text: $sshPasswordInput)
                                    .autocorrectionDisabled()
                                    .textInputAutocapitalization(.never)
                            } else {
                                SecureField("SSH Password", text: $sshPasswordInput)
                                    .textContentType(.password)
                            }
                            Button {
                                showPromptSSHPassword.toggle()
                            } label: {
                                Image(systemName: showPromptSSHPassword ? "eye.slash" : "eye")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } footer: {
                    if let conn = passwordPromptConnection {
                        Text("Connecting to \(conn.displaySubtitle)")
                    }
                }
            }
            .navigationTitle("Enter Credentials")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { clearPasswordPrompt() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Connect") {
                        if let conn = passwordPromptConnection {
                            let sshPwd = needsSSHPassword ? sshPasswordInput : (try? KeychainManager.retrieveSSHPassword(for: conn))
                            Task { await connectWith(conn, password: passwordInput, sshPassword: sshPwd) }
                        }
                        clearPasswordPrompt()
                    }
                    .disabled(passwordInput.isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Credential Persistence

    private func saveCredentials(password: String?, sshPassword: String?, for connection: DatabaseConnectionConfig) {
        if let password, !password.isEmpty {
            do {
                try KeychainManager.savePassword(password, for: connection)
                Logger.keychain.info("Saved database password for \(connection.username)@\(connection.host):\(connection.port)")
            } catch {
                Logger.keychain.error("Failed to save database password for \(connection.username)@\(connection.host):\(connection.port): \(error)")
            }
        }
        if let sshPassword, !sshPassword.isEmpty {
            do {
                try KeychainManager.saveSSHPassword(sshPassword, for: connection)
                Logger.keychain.info("Saved SSH password for \(connection.sshUsername ?? "")@\(connection.sshHost ?? "")")
            } catch {
                Logger.keychain.error("Failed to save SSH password for \(connection.sshUsername ?? "")@\(connection.sshHost ?? ""): \(error)")
            }
        }
    }

    // MARK: - Connection Logic

    private func initiateConnection(_ connection: DatabaseConnectionConfig) {
        var dbPassword: String?
        do {
            dbPassword = try KeychainManager.retrievePassword(for: connection)
        } catch {
            Logger.keychain.warning("No saved database password for \(connection.username)@\(connection.host):\(connection.port): \(error)")
        }

        // When using SSH key auth, SSH password is not needed — key material is resolved in connect()
        let usesSSHKey = connection.sshAuthMethod == .sshKey
        var sshPassword: String?
        if connection.useSSHTunnel && !usesSSHKey {
            do {
                sshPassword = try KeychainManager.retrieveSSHPassword(for: connection)
            } catch {
                Logger.keychain.warning("No saved SSH password for \(connection.sshUsername ?? "")@\(connection.sshHost ?? ""): \(error)")
            }
        }

        if let dbPassword {
            if connection.useSSHTunnel && !usesSSHKey && sshPassword == nil {
                // Have DB password but missing SSH password — prompt for SSH only
                passwordInput = dbPassword
                needsSSHPassword = true
                passwordPromptConnection = connection
            } else {
                // Have everything — connect directly
                Task { await connectWith(connection, password: dbPassword, sshPassword: sshPassword) }
            }
        } else {
            // Missing DB password — prompt for it (and SSH if needed)
            needsSSHPassword = connection.useSSHTunnel && !usesSSHKey && sshPassword == nil
            passwordPromptConnection = connection
        }
    }

    private func clearPasswordPrompt() {
        passwordPromptConnection = nil
        passwordInput = ""
        sshPasswordInput = ""
        needsSSHPassword = false
        showPromptPassword = false
        showPromptSSHPassword = false
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
        } catch {
            connectionError = error.localizedDescription
        }
        connectingConnectionID = nil
    }

    private func activeSessionID(for connection: DatabaseConnectionConfig) -> UUID? {
        sessionManager.sessions.first { _, session in
            session.connectionConfig.id == connection.id && session.state.isConnected
        }?.key
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
