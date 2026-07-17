//
//  ConnectionFormView.swift
//  glassdb
//
//  Add/Edit database connection form — sheet presentation
//  Pattern adapted from glas.sh ServerFormViews.swift (EditServerView)
//

import SwiftUI
import UniformTypeIdentifiers
import os
import GlasSecretStore

enum SQLiteFileImporter {
    enum ImportError: LocalizedError {
        case sourceIsNotAFile
        case managedCopyMissing
        case outsideManagedDirectory

        var errorDescription: String? {
            switch self {
            case .sourceIsNotAFile:
                return "The selected SQLite item is not a readable file."
            case .managedCopyMissing:
                return "The imported SQLite database is missing. Import it again."
            case .outsideManagedDirectory:
                return "The SQLite database is outside glassdb’s managed storage. Import it again."
            }
        }
    }

    static func managedDirectory(
        fileManager: FileManager = .default,
        create: Bool
    ) throws -> URL {
        let applicationSupport = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: create
        )
        let directory = applicationSupport
            .appendingPathComponent("glassdb", isDirectory: true)
            .appendingPathComponent("SQLite Databases", isDirectory: true)
        if create {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return directory
    }

    static func importFile(
        at sourceURL: URL,
        fileManager: FileManager = .default
    ) throws -> URL {
        let values = try sourceURL.resourceValues(forKeys: [.isRegularFileKey])
        guard values.isRegularFile == true else { throw ImportError.sourceIsNotAFile }

        let directory = try managedDirectory(fileManager: fileManager, create: true)
        let fileExtension = sourceURL.pathExtension.isEmpty ? "sqlite" : sourceURL.pathExtension
        let importedURL = directory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(fileExtension)
        try fileManager.copyItem(at: sourceURL, to: importedURL)
        return try validatedURL(forPath: importedURL.path, fileManager: fileManager)
    }

    static func validatedURL(
        forPath path: String,
        fileManager: FileManager = .default
    ) throws -> URL {
        let candidate = URL(fileURLWithPath: path)
            .standardizedFileURL
            .resolvingSymlinksInPath()
        guard fileManager.fileExists(atPath: candidate.path) else {
            throw ImportError.managedCopyMissing
        }
        let root = try managedDirectory(fileManager: fileManager, create: false)
            .standardizedFileURL
            .resolvingSymlinksInPath()
        let rootComponents = root.pathComponents
        let candidateComponents = candidate.pathComponents
        guard candidateComponents.count > rootComponents.count,
              candidateComponents.prefix(rootComponents.count).elementsEqual(rootComponents) else {
            throw ImportError.outsideManagedDirectory
        }
        let values = try candidate.resourceValues(forKeys: [.isRegularFileKey])
        guard values.isRegularFile == true else { throw ImportError.sourceIsNotAFile }
        return candidate
    }
}

struct ConnectionFormView: View {
    enum Mode {
        case add
        case edit(DatabaseConnectionConfig)
    }

    let mode: Mode
    let onSave: (DatabaseConnectionConfig, String, String?) throws -> Void

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
    @State private var databaseCredentialPolicy: CredentialStoragePolicy = .glassdbOnly
    @State private var defaultDatabase: String = ""
    @State private var useTLS: Bool = false
    @State private var useSSHTunnel: Bool = false
    @State private var sshHost: String = ""
    @State private var sshPort: String = "22"
    @State private var sshUsername: String = ""
    @State private var sshPassword: String = ""
    @State private var sshCredentialPolicy: CredentialStoragePolicy = .glassdbOnly
    @State private var sshAuthMethod: AuthenticationMethod = .password
    @State private var sshKeyID: UUID?
    @State private var colorTag: ConnectionColorTag = .none
    @State private var showPassword = false
    @State private var showSSHPassword = false
    @State private var showingAddSSHKey = false
    @State private var showingSQLiteImporter = false

    // MARK: - Test State

    enum TestResult: Equatable {
        case testing
        case success
        case failure(String)

        var statusTitle: String {
            switch self {
            case .testing:
                return "Testing…"
            case .success:
                return "Passed"
            case .failure:
                return "Failed"
            }
        }

        var errorMessage: String? {
            guard case .failure(let message) = self else { return nil }
            return message
        }
    }

    @State private var sshTestResult: TestResult?
    @State private var dbTestResult: TestResult?

    private var isTestingConnection: Bool {
        sshTestResult == .testing || dbTestResult == .testing
    }

    // MARK: - Connection Error

    @State private var connectionError: String?
    @State private var databaseCredentialLoadFailed = false
    @State private var sshCredentialLoadFailed = false

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
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        if engine == .sqlite {
            let path = host.trimmingCharacters(in: .whitespacesAndNewlines)
            return !path.isEmpty && FileManager.default.fileExists(atPath: path)
        }
        guard !host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let databasePort = Int(port), (1...65_535).contains(databasePort)
        else { return false }
        guard useSSHTunnel else { return true }
        guard !sshHost.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !sshUsername.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let tunnelPort = Int(sshPort), (1...65_535).contains(tunnelPort)
        else { return false }
        if sshAuthMethod == .sshKey {
            guard let keyID = sshKeyID,
                  let key = settingsManager.sshKeys.first(where: { $0.id == keyID })
            else { return false }
            return key.storageKind != .secureEnclave || key.keyTag != nil
        }
        return true
    }

    init(mode: Mode, onSave: @escaping (DatabaseConnectionConfig, String, String?) throws -> Void) {
        self.mode = mode
        self.onSave = onSave

        // Pre-populate @State from connection in edit mode (glas.sh EditServerView:277-289 pattern)
        if case .edit(let connection) = mode {
            _name = State(initialValue: connection.name)
            _engine = State(initialValue: connection.engine)
            _host = State(initialValue: connection.host)
            _port = State(initialValue: String(connection.port))
            _username = State(initialValue: connection.username)
            _databaseCredentialPolicy = State(initialValue: connection.databaseCredentialPolicy)
            _defaultDatabase = State(initialValue: connection.defaultDatabase ?? "")
            _useTLS = State(initialValue: connection.useTLS)
            _useSSHTunnel = State(initialValue: connection.useSSHTunnel)
            _sshHost = State(initialValue: connection.sshHost ?? "")
            _sshPort = State(initialValue: String(connection.sshPort ?? 22))
            _sshUsername = State(initialValue: connection.sshUsername ?? "")
            _sshAuthMethod = State(initialValue: connection.sshAuthMethod ?? .password)
            _sshCredentialPolicy = State(initialValue: connection.sshCredentialPolicy)
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
        .onChange(of: engine) { _, newEngine in
            host = newEngine.defaultHost
            port = String(newEngine.defaultPort)
            username = newEngine.defaultUsername
            defaultDatabase = ""
            useTLS = false
            useSSHTunnel = false
            dbTestResult = nil
        }
        .fileImporter(
            isPresented: $showingSQLiteImporter,
            allowedContentTypes: Self.sqliteContentTypes,
            allowsMultipleSelection: false
        ) { result in
            importSQLiteFile(result)
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
            Button("OK", role: .cancel) { connectionError = nil }
        } message: {
            Text(connectionError ?? "")
        }
    }

    // MARK: - Connection Section

    @ViewBuilder
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
            if engine == .sqlite {
                LabeledContent("Database File") {
                    Text(host.isEmpty ? "No file selected" : URL(fileURLWithPath: host).lastPathComponent)
                        .foregroundStyle(host.isEmpty ? .secondary : .primary)
                        .lineLimit(1)
                }
                Button {
                    showingSQLiteImporter = true
                } label: {
                    Label(host.isEmpty ? "Choose SQLite File" : "Choose Different File", systemImage: "folder")
                }
            } else {
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
                }
            }
        }
    }

    private static var sqliteContentTypes: [UTType] {
        var types: [UTType] = [.data]
        for filenameExtension in ["sqlite", "sqlite3", "db"] {
            if let type = UTType(filenameExtension: filenameExtension) {
                types.insert(type, at: 0)
            }
        }
        return types
    }

    private func importSQLiteFile(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            let importedURL = try SQLiteFileImporter.importFile(at: url)
            host = importedURL.path
            if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                name = url.deletingPathExtension().lastPathComponent
            }
            dbTestResult = nil
        } catch {
            connectionError = "The SQLite file could not be imported. \(error.localizedDescription)"
        }
    }

    // MARK: - Database Auth Section

    @ViewBuilder
    private var databaseAuthSection: some View {
        if engine != .sqlite {
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
            credentialPolicyPicker(
                label: "Password Storage",
                selection: $databaseCredentialPolicy
            )
            LabeledContent("Default Database") {
                TextField("Optional", text: $defaultDatabase)
                    .multilineTextAlignment(.trailing)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }
            Toggle("Use TLS", isOn: $useTLS)
            }
        } else {
            Section("Local Database") {
                Text("glassdb imports a private working copy of the selected SQLite file. The original file is left unchanged.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - SSH Tunnel Section

    @ViewBuilder
    private var sshTunnelSection: some View {
        if engine.supportsSSHTunnel {
            Section("SSH Tunnel") {
                Toggle("Use SSH Tunnel", isOn: $useSSHTunnel)
            }
        }

        if engine.supportsSSHTunnel && useSSHTunnel {
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
                    credentialPolicyPicker(
                        label: "Password Storage",
                        selection: $sshCredentialPolicy
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

    private func credentialPolicyPicker(
        label: String,
        selection: Binding<CredentialStoragePolicy>
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Picker(label, selection: selection) {
                ForEach(CredentialStoragePolicy.allCases) { policy in
                    Text(policy.displayName).tag(policy)
                }
            }
            Text(selection.wrappedValue.policyDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
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
                    Text("\(key.name) (\(sshKeyBadge(key)))")
                        .tag(key.id as UUID?)
                        .disabled(key.storageKind == .secureEnclave && key.keyTag == nil)
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
            .disabled(sshHost.isEmpty || sshUsername.isEmpty || isTestingConnection)

            Spacer()

            testResultIndicator(sshTestResult, accessibilityName: "SSH connection")
        }
    }

    private var testDBButton: some View {
        HStack {
            Button {
                testDB()
            } label: {
                Label("Test Connection", systemImage: "bolt")
            }
            .disabled(!isFormValid || isTestingConnection)

            Spacer()

            testResultIndicator(dbTestResult, accessibilityName: "Database connection")
        }
    }

    @ViewBuilder
    private func testResultIndicator(
        _ result: TestResult?,
        accessibilityName: String
    ) -> some View {
        switch result {
        case .none:
            EmptyView()
        case .testing:
            ProgressView(result?.statusTitle ?? "Testing…")
                .controlSize(.small)
                .accessibilityLabel("\(accessibilityName) test in progress")
        case .success:
            Label(result?.statusTitle ?? "Passed", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.callout)
                .accessibilityLabel("\(accessibilityName) test succeeded")
        case .failure:
            Button {
                connectionError = result?.errorMessage
            } label: {
                Label(result?.statusTitle ?? "Failed", systemImage: "exclamationmark.circle.fill")
                    .foregroundStyle(.red)
                    .font(.callout)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(accessibilityName) test failed")
            .accessibilityHint("Shows error details")
        }
    }

    // MARK: - Keychain Load (glas.sh EditServerView:428-434 pattern)

    private func loadKeychainCredentials() {
        guard let connection = editingConnection else { return }
        if connection.engine.supportsCredentials {
            do {
                let saved = try KeychainManager.retrievePassword(for: connection)
                password = saved
                databaseCredentialLoadFailed = false
            } catch SecretStoreError.notFound {
                password = ""
            } catch {
                databaseCredentialLoadFailed = true
                connectionError = "The saved database password could not be loaded. You can enter and save a replacement. \(error.localizedDescription)"
            }
        }
        if connection.useSSHTunnel, connection.sshAuthMethod != .sshKey {
            do {
                let saved = try KeychainManager.retrieveSSHPassword(for: connection)
                sshPassword = saved
                sshCredentialLoadFailed = false
            } catch SecretStoreError.notFound {
                sshPassword = ""
            } catch {
                sshCredentialLoadFailed = true
                connectionError = "The saved SSH password could not be loaded. You can enter and save a replacement. \(error.localizedDescription)"
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
            useSSHTunnel: engine.supportsSSHTunnel && useSSHTunnel,
            sshHost: useSSHTunnel ? sshHost.trimmingCharacters(in: .whitespacesAndNewlines) : nil,
            sshPort: useSSHTunnel ? Int(sshPort) ?? 22 : nil,
            sshUsername: useSSHTunnel ? sshUsername.trimmingCharacters(in: .whitespacesAndNewlines) : nil,
            sshAuthMethod: useSSHTunnel ? sshAuthMethod : nil,
            sshKeyID: useSSHTunnel && sshAuthMethod == .sshKey ? sshKeyID : nil,
            databaseCredentialPolicy: databaseCredentialPolicy,
            sshCredentialPolicy: sshCredentialPolicy,
            useTLS: engine.supportsTLS && useTLS,
            isFavorite: editingConnection?.isFavorite ?? false,
            colorTag: colorTag,
            dateAdded: editingConnection?.dateAdded ?? Date(),
            lastConnected: editingConnection?.lastConnected,
            tags: editingConnection?.tags ?? []
        )
    }

    // MARK: - Save

    private func save() {
        guard credentialMaterialIsReadyForSave else { return }
        let config = buildConnection()
        let sshPw: String? = useSSHTunnel && sshAuthMethod == .password ? sshPassword : nil
        do {
            try onSave(config, engine.supportsCredentials ? password : "", sshPw)
            dismiss()
        } catch {
            connectionError = "The connection was not saved because its credentials could not be stored securely. \(error.localizedDescription)"
        }
    }

    private func saveAndConnect() {
        guard credentialMaterialIsReadyForSave else { return }
        let config = buildConnection()
        let sshPw: String? = useSSHTunnel && sshAuthMethod == .password ? sshPassword : nil
        do {
            try onSave(config, engine.supportsCredentials ? password : "", sshPw)
            dismiss()
        } catch {
            connectionError = "The connection was not saved because its credentials could not be stored securely. \(error.localizedDescription)"
            return
        }

        Task {
            do {
                let sessionID = try await sessionManager.connect(
                    config: config,
                    password: engine.supportsCredentials ? password : "",
                    sshPassword: sshPw
                )
                // updateLastConnected handled by ConnectionManagerView's onSave
                openWindow(id: "query-editor", value: sessionID)
            } catch {
                connectionError = error.localizedDescription
            }
        }
    }

    private var credentialMaterialIsReadyForSave: Bool {
        if engine.supportsCredentials && databaseCredentialLoadFailed && password.isEmpty {
            connectionError = "Authenticate again or enter a replacement database password before changing this connection."
            return false
        }
        if useSSHTunnel, sshAuthMethod == .password,
           sshCredentialLoadFailed, sshPassword.isEmpty {
            connectionError = "Authenticate again or enter a replacement SSH password before changing this connection."
            return false
        }
        return true
    }

    // MARK: - Test Actions

    private func testSSH() {
        connectionError = nil
        sshTestResult = .testing
        let config = buildConnection()
        let sshPw: String? = useSSHTunnel && sshAuthMethod == .password ? sshPassword : nil
        Task {
            do {
                try await sessionManager.testSSHConnection(config: config, sshPassword: sshPw)
                sshTestResult = .success
            } catch {
                let message = "SSH connection test failed.\n\n\(error.localizedDescription)"
                sshTestResult = .failure(message)
                connectionError = message
            }
        }
    }

    private func testDB() {
        connectionError = nil
        dbTestResult = .testing
        let config = buildConnection()
        let sshPw: String? = useSSHTunnel && sshAuthMethod == .password ? sshPassword : nil
        Task {
            do {
                try await sessionManager.testConnection(
                    config: config,
                    password: engine.supportsCredentials ? password : "",
                    sshPassword: sshPw
                )
                dbTestResult = .success
            } catch {
                let message = "Database connection test failed.\n\n\(error.localizedDescription)"
                dbTestResult = .failure(message)
                connectionError = message
            }
        }
    }

    private func sshKeyBadge(_ key: StoredSSHKey) -> String {
        if key.storageKind == .secureEnclave {
            if key.keyTag == nil {
                return "Hardware Secure Enclave \(key.algorithmKind.badgeName) — use in glas.sh"
            }
            return "Secure Enclave–wrapped \(key.algorithmKind.badgeName)"
        }
        return key.keyTypeBadge
    }
}
