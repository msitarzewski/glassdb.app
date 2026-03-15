//
//  ConnectionFormView.swift
//  glassdb
//
//  Add/Edit database connection form — sheet presentation
//  Pattern adapted from glas.sh ServerFormViews.swift (EditServerView)
//

import SwiftUI
import os

struct ConnectionFormView: View {
    enum Mode {
        case add
        case edit(DatabaseConnectionConfig)
    }

    let mode: Mode
    let onSave: (DatabaseConnectionConfig, String, String?) -> Void

    @Environment(SettingsManager.self) private var settingsManager
    @Environment(DatabaseSessionManager.self) private var sessionManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openWindow) private var openWindow

    // MARK: - Form Fields

    @State private var name: String = ""
    @State private var engine: DatabaseEngineType = .mysql
    @State private var host: String = "127.0.0.1"
    @State private var port: String = "3306"
    @State private var username: String = "root"
    @State private var password: String = ""
    @State private var defaultDatabase: String = ""
    @State private var useTLS: Bool = false
    @State private var useSSHTunnel: Bool = false
    @State private var sshHost: String = ""
    @State private var sshPort: String = "22"
    @State private var sshUsername: String = ""
    @State private var sshPassword: String = ""
    @State private var sshAuthMethod: AuthenticationMethod = .password
    @State private var sshKeyID: UUID?
    @State private var colorTag: ConnectionColorTag = .none
    @State private var showPassword = false
    @State private var showSSHPassword = false
    @State private var showingAddSSHKey = false

    // MARK: - Test State

    enum TestResult {
        case testing
        case success
        case failure(String)
    }

    @State private var sshTestResult: TestResult?
    @State private var dbTestResult: TestResult?

    // MARK: - Connection Error

    @State private var connectionError: String?

    // MARK: - Computed

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var editingConnection: DatabaseConnectionConfig? {
        if case .edit(let connection) = mode { return connection }
        return nil
    }

    private var isFormValid: Bool {
        !name.isEmpty && !host.isEmpty && !username.isEmpty
    }

    init(mode: Mode, onSave: @escaping (DatabaseConnectionConfig, String, String?) -> Void) {
        self.mode = mode
        self.onSave = onSave

        // Pre-populate @State from connection in edit mode (glas.sh EditServerView:277-289 pattern)
        if case .edit(let connection) = mode {
            _name = State(initialValue: connection.name)
            _engine = State(initialValue: connection.engine)
            _host = State(initialValue: connection.host)
            _port = State(initialValue: String(connection.port))
            _username = State(initialValue: connection.username)
            _defaultDatabase = State(initialValue: connection.defaultDatabase ?? "")
            _useTLS = State(initialValue: connection.useTLS)
            _useSSHTunnel = State(initialValue: connection.useSSHTunnel)
            _sshHost = State(initialValue: connection.sshHost ?? "")
            _sshPort = State(initialValue: String(connection.sshPort ?? 22))
            _sshUsername = State(initialValue: connection.sshUsername ?? "")
            _sshAuthMethod = State(initialValue: connection.sshAuthMethod ?? .password)
            _sshKeyID = State(initialValue: connection.sshKeyID)
            _colorTag = State(initialValue: connection.colorTag)
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                connectionSection
                databaseAuthSection
                sshTunnelSection
                appearanceSection
                testSection
            }
            .navigationTitle(isEditing ? "Edit Connection" : "Add Connection")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!isFormValid)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save & Connect") { saveAndConnect() }
                        .disabled(!isFormValid)
                }
            }
        }
        .onAppear {
            loadKeychainCredentials()
        }
        .sheet(isPresented: $showingAddSSHKey) {
            AddSSHKeyView { name, privateKey, passphrase, algorithmKind in
                try settingsManager.addSSHKey(
                    name: name,
                    privateKey: privateKey,
                    passphrase: passphrase,
                    algorithmKind: algorithmKind
                )
            }
        }
        .onChange(of: settingsManager.sshKeys.map(\.id)) { _, newIDs in
            // Auto-select newly added key if none selected
            if sshAuthMethod == .sshKey, sshKeyID == nil || !newIDs.contains(sshKeyID!) {
                sshKeyID = newIDs.last
            }
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

    // MARK: - Connection Section

    private var connectionSection: some View {
        Section("Connection") {
            LabeledContent("Name") {
                TextField("Display Name", text: $name)
                    .multilineTextAlignment(.trailing)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }
            Picker("Engine", selection: $engine) {
                ForEach(DatabaseEngineType.allCases) { eng in
                    Text(eng.displayName).tag(eng)
                }
            }
            LabeledContent("Host") {
                TextField("127.0.0.1", text: $host)
                    .multilineTextAlignment(.trailing)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }
            LabeledContent("Port") {
                TextField("\(engine.defaultPort)", text: $port)
                    .multilineTextAlignment(.trailing)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .onChange(of: engine) { _, newEngine in
                        port = String(newEngine.defaultPort)
                    }
            }
        }
    }

    // MARK: - Database Auth Section

    private var databaseAuthSection: some View {
        Section("Database Authentication") {
            LabeledContent("Username") {
                TextField("root", text: $username)
                    .multilineTextAlignment(.trailing)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }
            passwordField(
                label: "Password",
                text: $password,
                showPlaintext: $showPassword
            )
            LabeledContent("Default Database") {
                TextField("Optional", text: $defaultDatabase)
                    .multilineTextAlignment(.trailing)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }
            Toggle("Use TLS", isOn: $useTLS)
        }
    }

    // MARK: - SSH Tunnel Section

    @ViewBuilder
    private var sshTunnelSection: some View {
        Section("SSH Tunnel") {
            Toggle("Use SSH Tunnel", isOn: $useSSHTunnel)
        }

        if useSSHTunnel {
            Section("SSH Server") {
                LabeledContent("Host") {
                    TextField("hostname or IP", text: $sshHost)
                        .multilineTextAlignment(.trailing)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
                LabeledContent("Port") {
                    TextField("22", text: $sshPort)
                        .multilineTextAlignment(.trailing)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
                LabeledContent("Username") {
                    TextField("username", text: $sshUsername)
                        .multilineTextAlignment(.trailing)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
            }

            Section("SSH Authentication") {
                Picker("Method", selection: $sshAuthMethod) {
                    Text("Password").tag(AuthenticationMethod.password)
                    Text("SSH Key").tag(AuthenticationMethod.sshKey)
                }

                if sshAuthMethod == .password {
                    passwordField(
                        label: "Password",
                        text: $sshPassword,
                        showPlaintext: $showSSHPassword
                    )
                } else {
                    sshKeyPicker
                }
            }

            Section {
                testSSHButton
            }
        }
    }

    // MARK: - Appearance Section

    private var appearanceSection: some View {
        Section("Appearance") {
            Picker("Color Tag", selection: $colorTag) {
                ForEach(ConnectionColorTag.allCases, id: \.self) { tag in
                    Label(tag.displayName, systemImage: "circle.fill")
                        .foregroundStyle(tag.color)
                        .tag(tag)
                }
            }
        }
    }

    // MARK: - Test Section

    private var testSection: some View {
        Section {
            testDBButton
        }
    }

    // MARK: - Password Field (reusable, glas.sh SecureField + eye toggle + paste)

    private func passwordField(
        label: String,
        text: Binding<String>,
        showPlaintext: Binding<Bool>
    ) -> some View {
        HStack {
            if showPlaintext.wrappedValue {
                TextField(label, text: text)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            } else {
                SecureField(label, text: text)
            }
            Button {
                showPlaintext.wrappedValue.toggle()
            } label: {
                Image(systemName: showPlaintext.wrappedValue ? "eye.slash" : "eye")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(showPlaintext.wrappedValue ? "Hide password" : "Show password")
            PasteButton(payloadType: String.self) { strings in
                if let value = strings.first {
                    text.wrappedValue = value
                }
            }
            .buttonBorderShape(.circle)
            .labelStyle(.iconOnly)
            .accessibilityLabel("Paste from clipboard")
        }
    }

    // MARK: - SSH Key Picker

    @ViewBuilder
    private var sshKeyPicker: some View {
        if settingsManager.sshKeys.isEmpty {
            Text("No SSH keys available. Add one to continue.")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            Picker("SSH Key", selection: $sshKeyID) {
                Text("Select a key...").tag(nil as UUID?)
                ForEach(settingsManager.sshKeys) { key in
                    Text("\(key.name) (\(key.algorithmKind.badgeName))")
                        .tag(key.id as UUID?)
                }
            }
        }
        Button {
            showingAddSSHKey = true
        } label: {
            Label("Add SSH Key", systemImage: "plus.circle")
        }
        .buttonStyle(.bordered)
    }

    // MARK: - Test Buttons

    private var testSSHButton: some View {
        HStack {
            Button {
                testSSH()
            } label: {
                Label("Test SSH Connection", systemImage: "antenna.radiowaves.left.and.right")
            }
            .disabled(sshHost.isEmpty || sshUsername.isEmpty)

            Spacer()

            testResultIndicator(sshTestResult)
        }
    }

    private var testDBButton: some View {
        HStack {
            Button {
                testDB()
            } label: {
                Label("Test Connection", systemImage: "bolt")
            }
            .disabled(host.isEmpty || username.isEmpty)

            Spacer()

            testResultIndicator(dbTestResult)
        }
    }

    @ViewBuilder
    private func testResultIndicator(_ result: TestResult?) -> some View {
        switch result {
        case .none:
            EmptyView()
        case .testing:
            ProgressView()
                .controlSize(.small)
        case .success:
            Label("Success", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.callout)
        case .failure(let message):
            Label(message, systemImage: "xmark.circle.fill")
                .foregroundStyle(.red)
                .font(.callout)
                .lineLimit(2)
        }
    }

    // MARK: - Keychain Load (glas.sh EditServerView:428-434 pattern)

    private func loadKeychainCredentials() {
        guard let connection = editingConnection else { return }
        if let saved = try? KeychainManager.retrievePassword(for: connection) {
            password = saved
        }
        if connection.useSSHTunnel, connection.sshAuthMethod != .sshKey {
            if let saved = try? KeychainManager.retrieveSSHPassword(for: connection) {
                sshPassword = saved
            }
        }
    }

    // MARK: - Build Connection Config

    private func buildConnection() -> DatabaseConnectionConfig {
        DatabaseConnectionConfig(
            id: editingConnection?.id ?? UUID(),
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            engine: engine,
            host: host.trimmingCharacters(in: .whitespacesAndNewlines),
            port: Int(port) ?? engine.defaultPort,
            username: username.trimmingCharacters(in: .whitespacesAndNewlines),
            defaultDatabase: defaultDatabase.isEmpty ? nil : defaultDatabase.trimmingCharacters(in: .whitespacesAndNewlines),
            useSSHTunnel: useSSHTunnel,
            sshHost: useSSHTunnel ? sshHost.trimmingCharacters(in: .whitespacesAndNewlines) : nil,
            sshPort: useSSHTunnel ? Int(sshPort) ?? 22 : nil,
            sshUsername: useSSHTunnel ? sshUsername.trimmingCharacters(in: .whitespacesAndNewlines) : nil,
            sshAuthMethod: useSSHTunnel ? sshAuthMethod : nil,
            sshKeyID: useSSHTunnel && sshAuthMethod == .sshKey ? sshKeyID : nil,
            useTLS: useTLS,
            isFavorite: editingConnection?.isFavorite ?? false,
            colorTag: colorTag,
            dateAdded: editingConnection?.dateAdded ?? Date(),
            lastConnected: editingConnection?.lastConnected,
            tags: editingConnection?.tags ?? []
        )
    }

    // MARK: - Save

    private func save() {
        let config = buildConnection()
        let sshPw: String? = useSSHTunnel && sshAuthMethod == .password ? sshPassword : nil
        onSave(config, password, sshPw)
        dismiss()
    }

    private func saveAndConnect() {
        let config = buildConnection()
        let sshPw: String? = useSSHTunnel && sshAuthMethod == .password ? sshPassword : nil
        onSave(config, password, sshPw)
        dismiss()

        Task {
            do {
                let sessionID = try await sessionManager.connect(
                    config: config,
                    password: password,
                    sshPassword: sshPw
                )
                // updateLastConnected handled by ConnectionManagerView's onSave
                openWindow(id: "query-editor", value: sessionID)
            } catch {
                connectionError = error.localizedDescription
            }
        }
    }

    // MARK: - Test Actions

    private func testSSH() {
        sshTestResult = .testing
        let config = buildConnection()
        let sshPw: String? = useSSHTunnel && sshAuthMethod == .password ? sshPassword : nil
        Task {
            do {
                try await sessionManager.testSSHConnection(config: config, sshPassword: sshPw)
                sshTestResult = .success
            } catch {
                sshTestResult = .failure(error.localizedDescription)
            }
        }
    }

    private func testDB() {
        dbTestResult = .testing
        let config = buildConnection()
        let sshPw: String? = useSSHTunnel && sshAuthMethod == .password ? sshPassword : nil
        Task {
            do {
                try await sessionManager.testConnection(config: config, password: password, sshPassword: sshPw)
                dbTestResult = .success
            } catch {
                dbTestResult = .failure(error.localizedDescription)
            }
        }
    }
}
