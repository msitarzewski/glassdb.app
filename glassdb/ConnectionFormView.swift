//
//  ConnectionFormView.swift
//  glassdb
//
//  Add/Edit database connection forms
//

import SwiftUI
import GlasSecretStore

struct ConnectionFormView: View {
    enum Mode: Identifiable {
        case add
        case edit(DatabaseConnectionConfig)

        var id: String {
            switch self {
            case .add: return "add"
            case .edit(let c): return c.id.uuidString
            }
        }
    }

    let mode: Mode
    let onSave: (DatabaseConnectionConfig, String?, String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(SettingsManager.self) private var settingsManager

    @State private var name: String = ""
    @State private var engine: DatabaseEngineType = .mysql
    @State private var host: String = "127.0.0.1"
    @State private var port: String = "3306"
    @State private var username: String = "root"
    @State private var password: String = ""
    @State private var hasExistingPassword: Bool = false
    @State private var defaultDatabase: String = ""
    @State private var useTLS: Bool = false
    @State private var useSSHTunnel: Bool = false
    @State private var sshHost: String = ""
    @State private var sshPort: String = "22"
    @State private var sshUsername: String = ""
    @State private var sshPassword: String = ""
    @State private var hasExistingSSHPassword: Bool = false
    @State private var sshAuthMethod: AuthenticationMethod = .password
    @State private var sshKeyID: UUID?
    @State private var colorTag: ConnectionColorTag = .none
    @State private var showPassword = false
    @State private var showSSHPassword = false

    init(mode: Mode, onSave: @escaping (DatabaseConnectionConfig, String?, String?) -> Void) {
        self.mode = mode
        self.onSave = onSave

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
            let saved = (try? KeychainManager.retrievePassword(for: connection)) != nil
            _hasExistingPassword = State(initialValue: saved)
            let sshSaved = (try? KeychainManager.retrieveSSHPassword(for: connection)) != nil
            _hasExistingSSHPassword = State(initialValue: sshSaved)
        }
    }

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var existingConnection: DatabaseConnectionConfig? {
        if case .edit(let c) = mode { return c }
        return nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Connection") {
                    TextField("Name", text: $name)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    Picker("Engine", selection: $engine) {
                        ForEach(DatabaseEngineType.allCases) { eng in
                            Text(eng.displayName).tag(eng)
                        }
                    }
                    TextField("Host", text: $host)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    TextField("Port", text: $port)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .onChange(of: engine) { _, newEngine in
                            port = String(newEngine.defaultPort)
                        }
                }

                Section("Database Authentication") {
                    TextField("Database Username", text: $username)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    HStack {
                        let placeholder = hasExistingPassword && password.isEmpty ? "Database Password (saved in Keychain)" : "Database Password"
                        if showPassword {
                            TextField(placeholder, text: $password)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                        } else {
                            SecureField(placeholder, text: $password)
                        }
                        Button {
                            showPassword.toggle()
                        } label: {
                            Image(systemName: showPassword ? "eye.slash" : "eye")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    if hasExistingPassword && password.isEmpty {
                        Text("Leave blank to keep existing database password")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    TextField("Default Database", text: $defaultDatabase)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }

                Section("Security") {
                    Toggle("Use TLS", isOn: $useTLS)
                }

                Section("SSH Tunnel") {
                    Toggle("Use SSH Tunnel", isOn: $useSSHTunnel)
                    if useSSHTunnel {
                        TextField("SSH Host", text: $sshHost)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                        TextField("SSH Port", text: $sshPort)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                        TextField("SSH Username", text: $sshUsername)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)

                        Picker("Auth Method", selection: $sshAuthMethod) {
                            Text("Password").tag(AuthenticationMethod.password)
                            Text("SSH Key").tag(AuthenticationMethod.sshKey)
                        }
                        .pickerStyle(.segmented)

                        if sshAuthMethod == .password {
                            HStack {
                                let placeholder = hasExistingSSHPassword && sshPassword.isEmpty ? "SSH Password (saved in Keychain)" : "SSH Password"
                                if showSSHPassword {
                                    TextField(placeholder, text: $sshPassword)
                                        .autocorrectionDisabled()
                                        .textInputAutocapitalization(.never)
                                } else {
                                    SecureField(placeholder, text: $sshPassword)
                                }
                                Button {
                                    showSSHPassword.toggle()
                                } label: {
                                    Image(systemName: showSSHPassword ? "eye.slash" : "eye")
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                            if hasExistingSSHPassword && sshPassword.isEmpty {
                                Text("Leave blank to keep existing SSH password")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            if settingsManager.sshKeys.isEmpty {
                                Text("No SSH keys imported. Add one in Settings.")
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
                        }
                    }
                }

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
            .navigationTitle(isEditing ? "Edit Connection" : "New Connection")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                        dismiss()
                    }
                    .disabled(name.isEmpty || host.isEmpty || username.isEmpty)
                }
            }
        }
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 24))
    }

    private func save() {
        let connection = DatabaseConnectionConfig(
            id: existingConnection?.id ?? UUID(),
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
            isFavorite: existingConnection?.isFavorite ?? false,
            colorTag: colorTag,
            dateAdded: existingConnection?.dateAdded ?? Date(),
            lastConnected: existingConnection?.lastConnected,
            tags: existingConnection?.tags ?? []
        )
        onSave(connection, password.isEmpty ? nil : password, sshPassword.isEmpty ? nil : sshPassword)
    }
}
