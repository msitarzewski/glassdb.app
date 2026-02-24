//
//  SettingsView.swift
//  glassdb
//
//  App settings window
//

import SwiftUI
import GlasSecretStore

struct SettingsView: View {
    @Environment(SettingsManager.self) private var settingsManager

    @State private var showingAddSSHKey = false
    @State private var renamingKey: StoredSSHKey?
    @State private var renameText = ""
    @State private var deletingKey: StoredSSHKey?

    var body: some View {
        @Bindable var settings = settingsManager

        NavigationStack {
            Form {
                Section("Connection") {
                    Toggle("Auto-reconnect on disconnect", isOn: $settings.autoReconnect)
                    Toggle("Confirm before closing", isOn: $settings.confirmBeforeClosing)
                }

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
                }

                Section("Editor") {
                    HStack {
                        Text("Font size")
                        Spacer()
                        TextField("Size", value: $settings.editorFontSize, format: .number)
                            .frame(width: 60)
                            .multilineTextAlignment(.trailing)
                    }
                    Toggle("Show line numbers", isOn: $settings.showLineNumbers)
                }

                sshKeysSection

                Section("Appearance") {
                    HStack {
                        Text("Window opacity")
                        Spacer()
                        Slider(value: $settings.windowOpacity, in: 0.5...1.0, step: 0.05)
                            .frame(width: 200)
                        Text(String(format: "%.0f%%", settings.windowOpacity * 100))
                            .font(.caption)
                            .frame(width: 40)
                    }
                    Toggle("Blur background", isOn: $settings.blurBackground)
                    Toggle("Interactive glass effects", isOn: $settings.interactiveGlassEffects)
                    Toggle("Show sidebar by default", isOn: $settings.showSidebarByDefault)
                }

                Section("About") {
                    LabeledContent("Version", value: "0.1.0")
                    LabeledContent("Engine", value: "MySQL (via mysql-nio)")
                }
            }
            .navigationTitle("Settings")
        }
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 24))
        .onChange(of: settings.autoReconnect) { settingsManager.saveSettings() }
        .onChange(of: settings.confirmBeforeClosing) { settingsManager.saveSettings() }
        .onChange(of: settings.resultRowLimit) { settingsManager.saveSettings() }
        .onChange(of: settings.maxQueryHistoryItems) { settingsManager.saveSettings() }
        .onChange(of: settings.editorFontSize) { settingsManager.saveSettings() }
        .onChange(of: settings.showLineNumbers) { settingsManager.saveSettings() }
        .onChange(of: settings.windowOpacity) { settingsManager.saveSettings() }
        .onChange(of: settings.blurBackground) { settingsManager.saveSettings() }
        .onChange(of: settings.interactiveGlassEffects) { settingsManager.saveSettings() }
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
                    settingsManager.deleteSSHKey(key)
                }
                deletingKey = nil
            }
            Button("Cancel", role: .cancel) { deletingKey = nil }
        } message: {
            Text("This will permanently remove the SSH key from Keychain.")
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
                            Text(key.keyTypeBadge)
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
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 24))
    }

    private func saveKey() {
        let trimmedKey = privateKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let algorithmKind = detectAlgorithm(from: trimmedKey)
        do {
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

    private func detectAlgorithm(from key: String) -> SSHKeyAlgorithmKind {
        if key.contains("BEGIN RSA PRIVATE KEY") || key.contains("BEGIN RSA PRIVATE") {
            return .rsa
        } else if key.contains("BEGIN OPENSSH PRIVATE KEY") {
            // OpenSSH format can be ed25519, ecdsa, or rsa — check the key body
            if key.contains("ssh-ed25519") {
                return .ed25519
            } else if key.contains("ecdsa-sha2") {
                return .ecdsaP256
            }
            // Default for OpenSSH format — could be ed25519 or rsa, try ed25519 as most common modern key
            return .ed25519
        } else if key.contains("BEGIN EC PRIVATE KEY") {
            return .ecdsaP256
        }
        return .unknown
    }
}
