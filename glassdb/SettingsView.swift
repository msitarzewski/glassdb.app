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
    @State private var sshKeyError: String?

    var body: some View {
        @Bindable var settings = settingsManager

        Group {
            #if os(macOS)
            macSettings
            #else
            spatialSettings
            #endif
        }
        .onChange(of: settings.resultRowLimit) { _, _ in settingsManager.saveSettings() }
        .onChange(of: settings.maxQueryHistoryItems) { _, _ in settingsManager.saveSettings() }
        .onChange(of: settings.redactQueryHistoryLiterals) { _, _ in settingsManager.saveSettings() }
        .onChange(of: settings.editorFontSize) { _, _ in settingsManager.saveSettings() }
        .onChange(of: settings.dataGridFontSize) { _, _ in settingsManager.saveSettings() }
        .onChange(of: settings.showLineNumbers) { _, _ in settingsManager.saveSettings() }
        .onChange(of: settings.windowOpacity) { _, _ in settingsManager.saveSettings() }
        .onChange(of: settings.blurBackground) { _, _ in settingsManager.saveSettings() }
        .onChange(of: settings.showSidebarByDefault) { _, _ in settingsManager.saveSettings() }
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
                .databaseNoAutocapitalization()
            Button("Rename") {
                if let key = renamingKey {
                    do {
                        try settingsManager.renameSSHKey(key, name: renameText)
                    } catch {
                        sshKeyError = error.localizedDescription
                    }
                }
                renamingKey = nil
            }
            .disabled(renameText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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
                        sshKeyError = error.localizedDescription
                    }
                }
                deletingKey = nil
            }
            Button("Cancel", role: .cancel) { deletingKey = nil }
        } message: {
            Text("This will permanently remove the SSH key from Keychain.")
        }
        .alert("SSH Key Error", isPresented: .init(
            get: { sshKeyError != nil },
            set: { if !$0 { sshKeyError = nil } }
        )) {
            Button("OK", role: .cancel) { sshKeyError = nil }
        } message: {
            Text(sshKeyError ?? "")
        }
    }

    #if os(macOS)
    private var macSettings: some View {
        TabView {
            Tab("General", systemImage: "gearshape") {
                generalSettingsForm
            }

            Tab("Editor", systemImage: "text.cursor") {
                editorSettingsForm
            }

            Tab("Appearance", systemImage: "circle.lefthalf.filled") {
                appearanceSettingsForm
            }

            Tab("SSH Keys", systemImage: "key") {
                sshKeySettingsForm
            }

            Tab("About", systemImage: "info.circle") {
                aboutSettingsForm
            }
        }
        .accessibilityIdentifier("settings.tab-view")
    }
    #endif

    private var spatialSettings: some View {
        NavigationStack {
            Form {
                querySection
                editorSection
                sshKeysSection
                appearanceSection
                aboutSection
            }
            .navigationTitle("Settings")
        }
    }

    private var generalSettingsForm: some View {
        Form {
            querySection

            Section("Windows") {
                @Bindable var settings = settingsManager
                Toggle("Show sidebar when opening a workspace", isOn: $settings.showSidebarByDefault)
            }
        }
        .formStyle(.grouped)
    }

    private var editorSettingsForm: some View {
        Form {
            editorSection
        }
        .formStyle(.grouped)
    }

    private var appearanceSettingsForm: some View {
        Form {
            appearanceSection
        }
        .formStyle(.grouped)
    }

    private var sshKeySettingsForm: some View {
        Form {
            sshKeysSection
        }
        .formStyle(.grouped)
    }

    private var aboutSettingsForm: some View {
        Form {
            aboutSection
        }
        .formStyle(.grouped)
    }

    @ViewBuilder
    private var querySection: some View {
        @Bindable var settings = settingsManager

        Section {
            BoundedStepperRow(
                title: "Result row limit",
                value: $settings.resultRowLimit,
                range: 1...100_000,
                step: 100,
                accessibilityHint: "Limits rows returned to the results grid"
            )
            BoundedStepperRow(
                title: "Query history limit",
                value: $settings.maxQueryHistoryItems,
                range: 1...10_000,
                step: 100,
                accessibilityHint: "Limits locally retained query history"
            )
            Toggle("Redact literals in query history", isOn: $settings.redactQueryHistoryLiterals)
                .help("Replaces quoted strings and numeric values before queries are stored in history.")
        } header: {
            Text("Query")
        } footer: {
            Text("Limits protect memory use. Literal redaction applies only to history; it never changes SQL sent to a database.")
        }
    }

    @ViewBuilder
    private var editorSection: some View {
        @Bindable var settings = settingsManager

        Section {
            BoundedDoubleStepperRow(
                title: "SQL editor text",
                value: $settings.editorFontSize,
                range: 10...32,
                suffix: "pt"
            )
            BoundedDoubleStepperRow(
                title: "Results grid text",
                value: $settings.dataGridFontSize,
                range: 10...32,
                suffix: "pt"
            )
            Toggle("Show line numbers", isOn: $settings.showLineNumbers)
        } header: {
            Text("Editor")
        } footer: {
            Text("Text sizes apply to newly rendered editors and results grids.")
        }
    }

    @ViewBuilder
    private var appearanceSection: some View {
        @Bindable var settings = settingsManager

        Section {
            ContinuousSettingSlider(
                title: "Workspace opacity",
                value: $settings.windowOpacity,
                leadingAccessibilityLabel: "Transparent",
                trailingAccessibilityLabel: "Opaque"
            )
            ContinuousSettingSlider(
                title: "Background blur",
                value: $settings.blurBackground,
                leadingAccessibilityLabel: "No blur",
                trailingAccessibilityLabel: "Maximum blur"
            )
        } header: {
            Text("Database Workspace")
        } footer: {
            Text("These controls affect only the live SQL and row-management canvas. Set both to 0% for a completely transparent canvas. The titlebar, sidebar, workspace tabs, Connections, Settings, and detached results retain Apple system materials.")
        }

        #if !os(macOS)
        Section("Windows") {
            Toggle("Show sidebar when opening a workspace", isOn: $settings.showSidebarByDefault)
        }
        #endif
    }

    @ViewBuilder
    private var aboutSection: some View {
        Section("glassdb") {
            LabeledContent("Version", value: "0.1.0")
            LabeledContent("Database engines", value: "MySQL, PostgreSQL, SQLite")
            LabeledContent("Platforms", value: "Apple silicon")
        }
    }

    // MARK: - SSH Keys Section

    @ViewBuilder
    private var sshKeysSection: some View {
        Section {
            if let catalogError = settingsManager.sshKeyCatalogError {
                Label(catalogError.localizedDescription, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
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
                        #if os(macOS)
                        Menu {
                            Button("Rename…") {
                                renameText = key.name
                                renamingKey = key
                            }
                            Divider()
                            Button("Delete", role: .destructive) {
                                deletingKey = key
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .accessibilityLabel("Actions for \(key.name)")
                        }
                        .menuStyle(.borderlessButton)
                        .fixedSize()
                        #endif
                    }
                    .contextMenu {
                        Button("Rename…") {
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
                Label("Import SSH Key…", systemImage: "plus")
            }
        } header: {
            Text("SSH Keys")
        } footer: {
            Text("Private key material and passphrases are stored through GlassSecretStore in Keychain. Secure Enclave keys remain bound to the device that created them.")
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

private struct BoundedStepperRow: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let step: Int
    let accessibilityHint: String

    var body: some View {
        LabeledContent(title) {
            HStack(spacing: 8) {
                Text(value, format: .number.grouping(.automatic))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 64, alignment: .trailing)
                    .accessibilityHidden(true)
                Stepper("", value: $value, in: range, step: step)
                    .labelsHidden()
                    .fixedSize()
                    .accessibilityLabel(title)
                    .accessibilityValue(Text(value, format: .number))
                    .accessibilityHint(accessibilityHint)
            }
        }
    }
}

private struct BoundedDoubleStepperRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let suffix: String

    var body: some View {
        LabeledContent(title) {
            HStack(spacing: 8) {
                Text("\(Int(value.rounded())) \(suffix)")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 52, alignment: .trailing)
                    .accessibilityHidden(true)
                Stepper("", value: $value, in: range, step: 1)
                    .labelsHidden()
                    .fixedSize()
                    .accessibilityLabel(title)
                    .accessibilityValue("\(Int(value.rounded())) \(suffix)")
            }
        }
    }
}

private struct ContinuousSettingSlider: View {
    let title: String
    @Binding var value: Double
    let leadingAccessibilityLabel: String
    let trailingAccessibilityLabel: String

    var body: some View {
        LabeledContent(title) {
            HStack(spacing: 12) {
                Slider(value: $value, in: 0...1, step: 0.01)
                    .frame(minWidth: 190)
                    .accessibilityLabel(title)
                    .accessibilityValue(Text(value, format: .percent.precision(.fractionLength(0))))
                    .accessibilityHint("\(leadingAccessibilityLabel) to \(trailingAccessibilityLabel)")
                Text(value, format: .percent.precision(.fractionLength(0)))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(width: 44, alignment: .trailing)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: 280)
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
    @State private var revealsPassphrase = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Key Details") {
                    TextField("Name", text: $name)
                        .autocorrectionDisabled()
                        .databaseNoAutocapitalization()
                        .accessibilityIdentifier("ssh-key.name")
                }

                Section {
                    TextEditor(text: $privateKey)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 160)
                        .padding(4)
                        .overlay {
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(.quaternary, lineWidth: 1)
                        }
                        .autocorrectionDisabled()
                        .databaseNoAutocapitalization()
                        .accessibilityLabel("OpenSSH private key")
                        .accessibilityIdentifier("ssh-key.private-key")
                } header: {
                    Text("OpenSSH Private Key")
                } footer: {
                    Text("Paste an RSA or Ed25519 private key. The key is validated before it is stored in Keychain.")
                }

                Section("Passphrase") {
                    HStack(spacing: 8) {
                        Group {
                            if revealsPassphrase {
                                TextField("Passphrase (optional)", text: $passphrase)
                            } else {
                                SecureField("Passphrase (optional)", text: $passphrase)
                            }
                        }
                        .autocorrectionDisabled()
                        .databaseNoAutocapitalization()
                        .accessibilityIdentifier("ssh-key.passphrase")

                        Button {
                            revealsPassphrase.toggle()
                        } label: {
                            Image(systemName: revealsPassphrase ? "eye.slash" : "eye")
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel(revealsPassphrase ? "Hide passphrase" : "Show passphrase")
                        .help(revealsPassphrase ? "Hide passphrase" : "Show passphrase")
                    }
                }
                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Import SSH Key")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .keyboardShortcut(.cancelAction)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Import") { saveKey() }
                        .keyboardShortcut(.defaultAction)
                        .disabled(
                            name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                || privateKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        )
                }
            }
        }
        #if os(macOS)
        .frame(width: 560, height: 500)
        #endif
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
