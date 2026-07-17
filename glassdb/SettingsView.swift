//
//  SettingsView.swift
//  glassdb
//
//  App settings window
//

import SwiftUI
import GlasSecretStore
import GlassDBKit

struct SettingsView: View {
    @Environment(SettingsManager.self) private var settingsManager

    @State private var showingAddSSHKey = false
    @State private var renamingKey: StoredSSHKey?
    @State private var renameText = ""
    @State private var deletingKey: StoredSSHKey?
    @State private var keychainError: String?

    var body: some View {
        @Bindable var settings = settingsManager

        NavigationStack {
            Form {
                Section("Query") {
                    HStack {
                        Text("Result row limit")
                        Spacer()
                        TextField("Limit", value: $settings.resultRowLimit, format: .number)
                            .frame(width: 100)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Query history limit")
                        Spacer()
                        TextField("Limit", value: $settings.maxQueryHistoryItems, format: .number)
                            .frame(width: 100)
                            .multilineTextAlignment(.trailing)
                    }
                    Toggle("Redact literals in query history", isOn: $settings.redactQueryHistoryLiterals)
                }

                Section("Editor") {
                    HStack {
                        Text("Editor font size")
                        Spacer()
                        TextField("Size", value: $settings.editorFontSize, format: .number)
                            .frame(width: 60)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Grid font size")
                        Spacer()
                        TextField("Size", value: $settings.dataGridFontSize, format: .number)
                            .frame(width: 60)
                            .multilineTextAlignment(.trailing)
                    }
                    Toggle("Show line numbers", isOn: $settings.showLineNumbers)
                }

                sshKeysSection

                Section("Appearance") {
                    Slider(value: $settings.windowOpacity, in: 0.0...1.0) {
                        Text("Database workspace opacity")
                    } minimumValueLabel: {
                        Text("Transparent")
                    } maximumValueLabel: {
                        Text("Opaque")
                    }

                    Slider(value: $settings.blurBackground, in: 0.0...1.0) {
                        Text("Database workspace blur")
                    } minimumValueLabel: {
                        Text("None")
                    } maximumValueLabel: {
                        Text("Maximum")
                    }

                    Text("Opacity and blur apply only to live database workspaces. Set both to zero for a completely transparent SQL and row-management window. Connections, Settings, and detached results keep their system materials.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Toggle("Show sidebar by default", isOn: $settings.showSidebarByDefault)
                }

                Section("About") {
                    LabeledContent("Version", value: "0.1.0")
                    LabeledContent("Engines", value: "MySQL, PostgreSQL, SQLite")
                }
            }
            .navigationTitle("Settings")
        }
        .onChange(of: settings.resultRowLimit) { settingsManager.saveSettings() }
        .onChange(of: settings.maxQueryHistoryItems) { settingsManager.saveSettings() }
        .onChange(of: settings.redactQueryHistoryLiterals) { settingsManager.saveSettings() }
        .onChange(of: settings.editorFontSize) { settingsManager.saveSettings() }
        .onChange(of: settings.dataGridFontSize) { settingsManager.saveSettings() }
        .onChange(of: settings.showLineNumbers) { settingsManager.saveSettings() }
        .onChange(of: settings.windowOpacity) { settingsManager.saveSettings() }
        .onChange(of: settings.blurBackground) { settingsManager.saveSettings() }
        .onChange(of: settings.showSidebarByDefault) { settingsManager.saveSettings() }
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
        .alert("Rename SSH Key", isPresented: .init(
            get: { renamingKey != nil },
            set: { if !$0 { renamingKey = nil } }
        )) {
            TextField("Name", text: $renameText)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            Button("Rename") {
                if let key = renamingKey {
                    settingsManager.renameSSHKey(key, name: renameText)
                }
                renamingKey = nil
            }
            Button("Cancel", role: .cancel) { renamingKey = nil }
        }
        .alert("Delete SSH Key?", isPresented: .init(
            get: { deletingKey != nil },
            set: { if !$0 { deletingKey = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let key = deletingKey {
                    do {
                        try settingsManager.deleteSSHKey(key)
                    } catch {
                        keychainError = "The SSH key was not removed because Keychain deletion failed. \(error.localizedDescription)"
                    }
                }
                deletingKey = nil
            }
            Button("Cancel", role: .cancel) { deletingKey = nil }
        } message: {
            Text("This will permanently remove the SSH key from Keychain.")
        }
        .alert("Keychain Error", isPresented: .init(
            get: { keychainError != nil },
            set: { if !$0 { keychainError = nil } }
        )) {
            Button("OK", role: .cancel) { keychainError = nil }
        } message: {
            Text(keychainError ?? "")
        }
    }

    // MARK: - SSH Keys Section

    @ViewBuilder
    private var sshKeysSection: some View {
        Section {
            if settingsManager.sshKeys.isEmpty {
                Text("No SSH keys imported")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(settingsManager.sshKeys) { key in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(key.name)
                                .font(.headline)
                            Text(sshKeyBadge(key))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(key.createdAt, style: .date)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .contextMenu {
                        Button("Rename...") {
                            renameText = key.name
                            renamingKey = key
                        }
                        Divider()
                        Button("Delete", role: .destructive) {
                            deletingKey = key
                        }
                    }
                }
            }
            Button {
                showingAddSSHKey = true
            } label: {
                Label("Add SSH Key", systemImage: "plus")
            }
        } header: {
            Text("SSH Keys")
        }
    }

    private func sshKeyBadge(_ key: StoredSSHKey) -> String {
        if key.storageKind == .secureEnclave {
            if key.keyTag == nil {
                return "Hardware Secure Enclave \(key.algorithmKind.badgeName) — glas.sh only"
            }
            return "Secure Enclave–wrapped \(key.algorithmKind.badgeName)"
        }
        return key.keyTypeBadge
    }
}

// MARK: - Add SSH Key Sheet

struct AddSSHKeyView: View {
    let onSave: (String, String, String?, SSHKeyAlgorithmKind) throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var privateKey = ""
    @State private var passphrase = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Key Details") {
                    TextField("Name", text: $name)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    TextEditor(text: $privateKey)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 120)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    SecureField("Passphrase (optional)", text: $passphrase)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Add SSH Key")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { saveKey() }
                        .disabled(name.isEmpty || privateKey.isEmpty)
                }
            }
        }
    }

    private func saveKey() {
        let trimmedKey = privateKey.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            let algorithmKind = try detectAlgorithm(from: trimmedKey)
            try onSave(
                name.trimmingCharacters(in: .whitespacesAndNewlines),
                trimmedKey,
                passphrase.isEmpty ? nil : passphrase,
                algorithmKind
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func detectAlgorithm(from key: String) throws -> SSHKeyAlgorithmKind {
        switch try SSHTunnelManager.detectPrivateKeyAlgorithm(from: key) {
        case .rsa:
            return .rsa
        case .ed25519:
            return .ed25519
        case .secureEnclaveP256:
            return .ecdsaP256
        }
    }
}
