//
//  SettingsManager.swift
//  glassdb
//
//  Application settings persistence + SSH key management
//  Pattern adapted from glas.sh SettingsManager
//

import SwiftUI
import Foundation
import Observation
import GlasSecretStore
import os
import UserNotifications

enum QueryFailureNotificationPreference: String, Sendable {
    case undecided
    case enabled
    case disabled
}

struct SSHKeyLifecycleStore: @unchecked Sendable {
    let retrieve: (UUID) throws -> SSHKeyMaterial?
    let save: (UUID, SSHKeyMaterial) throws -> Void
    let delete: (UUID) throws -> Void

    static let live = SSHKeyLifecycleStore(
        retrieve: { keyID in
            do {
                return try KeychainManager.retrieveSSHKey(for: keyID)
            } catch SecretStoreError.notFound {
                return nil
            }
        },
        save: { keyID, material in
            guard let privateKey = material.privateKey.toUTF8String() else {
                throw SecretStoreError.encodingFailed
            }
            try KeychainManager.saveSSHKey(
                privateKey,
                passphrase: material.passphrase?.toUTF8String(),
                for: keyID
            )
        },
        delete: { keyID in
            try KeychainManager.deleteSSHKey(for: keyID)
        }
    )
}

enum SSHMetadataPersistenceError: LocalizedError, Equatable {
    case appGroupUnavailable
    case invalidCatalog
    case catalogTooLarge
    case readbackMismatch
    case keychainReadbackMismatch
    case rollbackFailed

    var errorDescription: String? {
        switch self {
        case .appGroupUnavailable:
            return "Shared SSH key metadata is unavailable because the Glass app group could not be opened. No SSH key changes were made."
        case .invalidCatalog:
            return "The shared SSH key catalog is malformed or unreadable. No SSH key changes were made."
        case .catalogTooLarge:
            return "The shared SSH key catalog exceeds its safe storage limit. No SSH key changes were made."
        case .readbackMismatch:
            return "The shared SSH key catalog could not be verified after saving. The previous catalog was restored."
        case .keychainReadbackMismatch:
            return "The SSH key could not be verified in Keychain after the operation."
        case .rollbackFailed:
            return "The SSH key operation failed and its metadata or Keychain rollback could not be verified."
        }
    }
}

enum SSHKeyInputError: LocalizedError, Equatable {
    case emptyName
    case nameTooLong
    case emptyPrivateKey
    case privateKeyTooLarge
    case passphraseTooLong

    var errorDescription: String? {
        switch self {
        case .emptyName:
            return "Enter a name for the SSH key."
        case .nameTooLong:
            return "The SSH key name must be 256 bytes or less."
        case .emptyPrivateKey:
            return "Paste an OpenSSH private key."
        case .privateKeyTooLarge:
            return "The SSH private key must be 1 MB or less."
        case .passphraseTooLong:
            return "The SSH key passphrase must be 4,096 bytes or less."
        }
    }
}

@MainActor
@Observable
class SettingsManager {
    static let defaultSharedDefaults = UserDefaults(suiteName: "group.sh.glas.shared")
    private static let sharedSSHKeysKey = "sshKeys"
    static let maximumSSHKeyCatalogBytes = 1024 * 1024
    static let maximumSSHKeyCatalogEntries = 4_096
    static let maximumSSHKeyNameBytes = 256
    static let maximumSSHPrivateKeyBytes = 1024 * 1024
    static let maximumSSHPassphraseBytes = 4_096
    var maxQueryHistoryItems: Int = 500
    var resultRowLimit: Int = 1000
    var windowOpacity: Double = 0.95
    var blurBackground: Double = 1.0
    var showSidebarByDefault: Bool = true
    var editorFontSize: Double = 14.0
    var dataGridFontSize: Double = 13.0
    var showLineNumbers: Bool = true
    var autoFormatJSONInRecordEditor: Bool = true
    var redactQueryHistoryLiterals: Bool = false
    private(set) var queryFailureNotificationPreference: QueryFailureNotificationPreference = .undecided
    var savedQueries: [SavedQuery] = []
    var sshKeys: [StoredSSHKey] = []
    private(set) var sshKeyCatalogError: SSHMetadataPersistenceError?

    private var hasLoaded = false
    private let defaults: UserDefaults
    private let sharedDefaults: UserDefaults?
    private let sshKeyLifecycleStore: SSHKeyLifecycleStore
    private let sharedCatalogWriter: (Data?) throws -> Void
    private let legacyCatalogWriter: (Data?) throws -> Void

    var queryFailureNotificationsEnabled: Bool {
        queryFailureNotificationPreference == .enabled
    }

    var shouldOfferQueryFailureNotifications: Bool {
        queryFailureNotificationPreference == .undecided
    }

    init(
        loadImmediately: Bool = true,
        defaults: UserDefaults = .standard,
        sharedDefaults: UserDefaults? = SettingsManager.defaultSharedDefaults,
        sshKeyLifecycleStore: SSHKeyLifecycleStore = .live,
        sharedCatalogWriter: ((Data?) throws -> Void)? = nil,
        legacyCatalogWriter: ((Data?) throws -> Void)? = nil
    ) {
        self.defaults = defaults
        self.sharedDefaults = sharedDefaults
        self.sshKeyLifecycleStore = sshKeyLifecycleStore
        self.sharedCatalogWriter = sharedCatalogWriter ?? { data in
            guard let sharedDefaults else { return }
            if let data {
                sharedDefaults.set(data, forKey: Self.sharedSSHKeysKey)
            } else {
                sharedDefaults.removeObject(forKey: Self.sharedSSHKeysKey)
            }
        }
        self.legacyCatalogWriter = legacyCatalogWriter ?? { data in
            if let data {
                defaults.set(data, forKey: UserDefaultsKeys.sshKeys)
            } else {
                defaults.removeObject(forKey: UserDefaultsKeys.sshKeys)
            }
        }
        if loadImmediately {
            loadIfNeeded()
        }
    }

    func loadIfNeeded() {
        guard !hasLoaded else { return }
        hasLoaded = true

        let savedMaxHistory = defaults.integer(forKey: UserDefaultsKeys.maxQueryHistoryItems)
        if savedMaxHistory > 0 {
            maxQueryHistoryItems = savedMaxHistory
        }
        let savedRowLimit = defaults.integer(forKey: UserDefaultsKeys.resultRowLimit)
        if savedRowLimit > 0 {
            resultRowLimit = savedRowLimit
        }
        if defaults.object(forKey: UserDefaultsKeys.windowOpacity) != nil {
            windowOpacity = min(
                max(defaults.double(forKey: UserDefaultsKeys.windowOpacity), 0.0),
                1.0
            )
        }
        if let savedBlur = defaults.object(forKey: UserDefaultsKeys.blurBackground) {
            // Migrate the original Boolean toggle without collapsing later slider values.
            if let number = savedBlur as? NSNumber,
               CFGetTypeID(number) == CFBooleanGetTypeID() {
                blurBackground = number.boolValue ? 1.0 : 0.0
            } else if let number = savedBlur as? NSNumber {
                blurBackground = min(max(number.doubleValue, 0.0), 1.0)
            }
        }
        if defaults.object(forKey: UserDefaultsKeys.showSidebarByDefault) != nil {
            showSidebarByDefault = defaults.bool(forKey: UserDefaultsKeys.showSidebarByDefault)
        }
        if defaults.object(forKey: UserDefaultsKeys.editorFontSize) != nil {
            editorFontSize = defaults.double(forKey: UserDefaultsKeys.editorFontSize)
        }
        if defaults.object(forKey: UserDefaultsKeys.dataGridFontSize) != nil {
            dataGridFontSize = defaults.double(forKey: UserDefaultsKeys.dataGridFontSize)
        }
        if defaults.object(forKey: UserDefaultsKeys.showLineNumbers) != nil {
            showLineNumbers = defaults.bool(forKey: UserDefaultsKeys.showLineNumbers)
        }
        if defaults.object(forKey: UserDefaultsKeys.autoFormatJSONInRecordEditor) != nil {
            autoFormatJSONInRecordEditor = defaults.bool(
                forKey: UserDefaultsKeys.autoFormatJSONInRecordEditor
            )
        }
        if defaults.object(forKey: UserDefaultsKeys.redactQueryHistoryLiterals) != nil {
            redactQueryHistoryLiterals = defaults.bool(forKey: UserDefaultsKeys.redactQueryHistoryLiterals)
        }
        if let rawPreference = defaults.string(
            forKey: UserDefaultsKeys.queryFailureNotificationPreference
        ), let preference = QueryFailureNotificationPreference(rawValue: rawPreference) {
            queryFailureNotificationPreference = preference
        }

        loadSavedQueries()
        loadSSHKeys()
    }

    func saveSettings() {
        maxQueryHistoryItems = min(max(maxQueryHistoryItems, 1), 10_000)
        resultRowLimit = min(max(resultRowLimit, 1), 100_000)
        editorFontSize = min(max(editorFontSize, 10), 32)
        dataGridFontSize = min(max(dataGridFontSize, 10), 32)
        windowOpacity = min(max(windowOpacity, 0.0), 1.0)
        blurBackground = min(max(blurBackground, 0.0), 1.0)
        defaults.set(maxQueryHistoryItems, forKey: UserDefaultsKeys.maxQueryHistoryItems)
        defaults.set(resultRowLimit, forKey: UserDefaultsKeys.resultRowLimit)
        defaults.set(windowOpacity, forKey: UserDefaultsKeys.windowOpacity)
        defaults.set(blurBackground, forKey: UserDefaultsKeys.blurBackground)
        defaults.set(showSidebarByDefault, forKey: UserDefaultsKeys.showSidebarByDefault)
        defaults.set(editorFontSize, forKey: UserDefaultsKeys.editorFontSize)
        defaults.set(dataGridFontSize, forKey: UserDefaultsKeys.dataGridFontSize)
        defaults.set(showLineNumbers, forKey: UserDefaultsKeys.showLineNumbers)
        defaults.set(
            autoFormatJSONInRecordEditor,
            forKey: UserDefaultsKeys.autoFormatJSONInRecordEditor
        )
        defaults.set(redactQueryHistoryLiterals, forKey: UserDefaultsKeys.redactQueryHistoryLiterals)
        defaults.set(
            queryFailureNotificationPreference.rawValue,
            forKey: UserDefaultsKeys.queryFailureNotificationPreference
        )
    }

    func declineQueryFailureNotifications() {
        queryFailureNotificationPreference = .disabled
        saveSettings()
    }

    func disableQueryFailureNotifications() {
        queryFailureNotificationPreference = .disabled
        saveSettings()
    }

    @discardableResult
    func enableQueryFailureNotifications() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .sound]
            )
            queryFailureNotificationPreference = granted ? .enabled : .disabled
            saveSettings()
            return granted
        } catch {
            Logger.settings.error("Notification authorization failed: \(error.localizedDescription)")
            queryFailureNotificationPreference = .disabled
            saveSettings()
            return false
        }
    }

    func postQueryFailureNotification() async {
        guard queryFailureNotificationsEnabled else { return }

        let center = UNUserNotificationCenter.current()
        let authorization = await center.notificationSettings().authorizationStatus
        guard authorization == .authorized || authorization == .provisional else {
            queryFailureNotificationPreference = .disabled
            saveSettings()
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Query Failed"
        // Do not expose SQL, schema names, literals, or server diagnostics in a
        // notification that may appear on a locked device.
        content.body = "A database query failed. Open glassdb to review the error."
        content.sound = .default
        content.threadIdentifier = "app.glassdb.query-failures"

        do {
            try await center.add(UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: nil
            ))
        } catch {
            Logger.settings.error("Query failure notification could not be delivered: \(error.localizedDescription)")
        }
    }

    // MARK: - Saved Queries

    func loadSavedQueries() {
        guard let data = defaults.data(forKey: UserDefaultsKeys.savedQueries) else {
            savedQueries = []
            return
        }
        do {
            savedQueries = try JSONDecoder().decode([SavedQuery].self, from: data)
        } catch {
            Logger.settings.error("Failed to load saved queries: \(error)")
            savedQueries = []
        }
    }

    private func saveSavedQueries() {
        do {
            let data = try JSONEncoder().encode(savedQueries)
            defaults.set(data, forKey: UserDefaultsKeys.savedQueries)
        } catch {
            Logger.settings.error("Failed to save queries: \(error)")
        }
    }

    func addSavedQuery(_ query: SavedQuery) {
        savedQueries.append(query)
        saveSavedQueries()
    }

    func updateSavedQuery(_ query: SavedQuery) {
        if let index = savedQueries.firstIndex(where: { $0.id == query.id }) {
            savedQueries[index] = query
            saveSavedQueries()
        }
    }

    func deleteSavedQuery(_ query: SavedQuery) {
        savedQueries.removeAll { $0.id == query.id }
        saveSavedQueries()
    }

    func useSavedQuery(_ queryID: UUID) {
        if let index = savedQueries.firstIndex(where: { $0.id == queryID }) {
            savedQueries[index].lastUsed = Date()
            savedQueries[index].useCount += 1
            saveSavedQueries()
        }
    }

    // MARK: - SSH Keys

    func loadSSHKeys() {
        do {
            sshKeys = try loadMergedSSHKeyCatalog(persistMigration: true)
            sshKeyCatalogError = nil
        } catch {
            Logger.settings.error("Failed to load SSH keys: \(error)")
            recordSSHMetadataError(error)
        }
    }

    func addSSHKey(name: String, privateKey: String, passphrase: String?, algorithmKind: SSHKeyAlgorithmKind) throws {
        do {
            let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedPrivateKey = privateKey.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedName.isEmpty else { throw SSHKeyInputError.emptyName }
            guard trimmedName.utf8.count <= Self.maximumSSHKeyNameBytes else {
                throw SSHKeyInputError.nameTooLong
            }
            guard !trimmedPrivateKey.isEmpty else { throw SSHKeyInputError.emptyPrivateKey }
            guard trimmedPrivateKey.utf8.count <= Self.maximumSSHPrivateKeyBytes else {
                throw SSHKeyInputError.privateKeyTooLarge
            }
            if let passphrase, passphrase.utf8.count > Self.maximumSSHPassphraseBytes {
                throw SSHKeyInputError.passphraseTooLong
            }
            let originalKeys = try reloadSSHKeyCatalogForMutation()
            let keyID = UUID()
            let material = SSHKeyMaterial(
                privateKey: SecureBytes(Data(trimmedPrivateKey.utf8)),
                passphrase: passphrase.map { SecureBytes(Data($0.utf8)) }
            )
            let storedKey = StoredSSHKey(
                id: keyID,
                name: trimmedName,
                algorithm: algorithmKind.badgeName,
                storageKind: .imported,
                algorithmKind: algorithmKind,
                migrationState: .notNeeded
            )

            do {
                try sshKeyLifecycleStore.save(keyID, material)
                guard let readback = try sshKeyLifecycleStore.retrieve(keyID),
                      Self.sshKeyMaterialMatches(readback, material) else {
                    throw SSHMetadataPersistenceError.keychainReadbackMismatch
                }
                let candidateKeys = originalKeys + [storedKey]
                try persistSSHKeyCatalogTransaction(candidateKeys)
                sshKeys = candidateKeys
                sshKeyCatalogError = nil
            } catch {
                sshKeys = originalKeys
                do {
                    try sshKeyLifecycleStore.delete(keyID)
                    guard try sshKeyLifecycleStore.retrieve(keyID) == nil else {
                        throw SSHMetadataPersistenceError.keychainReadbackMismatch
                    }
                } catch {
                    recordSSHMetadataError(SSHMetadataPersistenceError.rollbackFailed)
                    throw SSHMetadataPersistenceError.rollbackFailed
                }
                throw error
            }
        } catch {
            recordSSHMetadataError(error)
            throw error
        }
    }

    func deleteSSHKey(_ key: StoredSSHKey) throws {
        do {
            let originalKeys = try reloadSSHKeyCatalogForMutation()
            guard originalKeys.contains(where: { $0.id == key.id }) else {
                throw SecretStoreError.notFound
            }
            let sharedSnapshot = sharedDefaults?.data(forKey: Self.sharedSSHKeysKey)
            let legacySnapshot = defaults.data(forKey: UserDefaultsKeys.sshKeys)
            let originalMaterial = try sshKeyLifecycleStore.retrieve(key.id)
            let candidateKeys = originalKeys.filter { $0.id != key.id }

            try persistSSHKeyCatalogTransaction(candidateKeys)
            do {
                try sshKeyLifecycleStore.delete(key.id)
                guard try sshKeyLifecycleStore.retrieve(key.id) == nil else {
                    throw SSHMetadataPersistenceError.keychainReadbackMismatch
                }
                sshKeys = candidateKeys
                sshKeyCatalogError = nil
            } catch {
                var rollbackSucceeded = true
                if let originalMaterial {
                    do {
                        try restoreSSHKeyMaterialIfNeeded(originalMaterial, for: key.id)
                    } catch {
                        rollbackSucceeded = false
                    }
                }
                do {
                    try restoreSSHKeyCatalogSnapshots(
                        shared: sharedSnapshot,
                        legacy: legacySnapshot
                    )
                } catch {
                    rollbackSucceeded = false
                }
                sshKeys = originalKeys
                guard rollbackSucceeded else {
                    recordSSHMetadataError(SSHMetadataPersistenceError.rollbackFailed)
                    throw SSHMetadataPersistenceError.rollbackFailed
                }
                throw error
            }
        } catch {
            recordSSHMetadataError(error)
            throw error
        }
    }

    func renameSSHKey(_ key: StoredSSHKey, name: String) throws {
        do {
            let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedName.isEmpty else { throw SSHKeyInputError.emptyName }
            guard trimmedName.utf8.count <= Self.maximumSSHKeyNameBytes else {
                throw SSHKeyInputError.nameTooLong
            }
            let originalKeys = try reloadSSHKeyCatalogForMutation()
            guard let index = originalKeys.firstIndex(where: { $0.id == key.id }) else {
                throw SecretStoreError.notFound
            }
            var candidateKeys = originalKeys
            candidateKeys[index].name = trimmedName
            try persistSSHKeyCatalogTransaction(candidateKeys)
            sshKeys = candidateKeys
            sshKeyCatalogError = nil
        } catch {
            recordSSHMetadataError(error)
            throw error
        }
    }

    private func reloadSSHKeyCatalogForMutation() throws -> [StoredSSHKey] {
        let keys = try loadMergedSSHKeyCatalog(persistMigration: false)
        sshKeys = keys
        sshKeyCatalogError = nil
        return keys
    }

    private func loadMergedSSHKeyCatalog(persistMigration: Bool) throws -> [StoredSSHKey] {
        guard let sharedDefaults else {
            throw SSHMetadataPersistenceError.appGroupUnavailable
        }
        let sharedKeys = try loadSSHKeyCatalog(
            from: sharedDefaults,
            key: Self.sharedSSHKeysKey
        )
        // An earlier glassdb build briefly wrote the app-local key name into
        // the shared suite. Read it for migration, but all new writes use the
        // stable Glass-family `sshKeys` catalog consumed by glas.sh.
        let sharedLegacyKeys = try loadSSHKeyCatalog(
            from: sharedDefaults,
            key: UserDefaultsKeys.sshKeys
        )
        let legacyKeys = try loadSSHKeyCatalog(
            from: defaults,
            key: UserDefaultsKeys.sshKeys
        )
        var merged = sharedKeys ?? []
        for key in sharedLegacyKeys ?? [] where !merged.contains(where: { $0.id == key.id }) {
            merged.append(key)
        }
        for key in legacyKeys ?? [] where !merged.contains(where: { $0.id == key.id }) {
            merged.append(key)
        }
        try validateSSHKeyCatalog(merged)

        if persistMigration,
           (sharedKeys != nil || sharedLegacyKeys != nil || legacyKeys != nil),
           sharedKeys != merged || legacyKeys != merged {
            try persistSSHKeyCatalogTransaction(merged)
        }
        return merged
    }

    private func loadSSHKeyCatalog(from defaults: UserDefaults, key: String) throws -> [StoredSSHKey]? {
        guard let object = defaults.object(forKey: key) else { return nil }
        guard let data = object as? Data else {
            throw SSHMetadataPersistenceError.invalidCatalog
        }
        guard data.count <= Self.maximumSSHKeyCatalogBytes else {
            throw SSHMetadataPersistenceError.catalogTooLarge
        }
        guard let keys = try? JSONDecoder().decode([StoredSSHKey].self, from: data) else {
            throw SSHMetadataPersistenceError.invalidCatalog
        }
        try validateSSHKeyCatalog(keys)
        return keys
    }

    private func validateSSHKeyCatalog(_ keys: [StoredSSHKey]) throws {
        guard keys.count <= Self.maximumSSHKeyCatalogEntries else {
            throw SSHMetadataPersistenceError.catalogTooLarge
        }
        guard Set(keys.map(\.id)).count == keys.count else {
            throw SSHMetadataPersistenceError.invalidCatalog
        }
    }

    private func persistSSHKeyCatalogTransaction(_ candidateKeys: [StoredSSHKey]) throws {
        guard let sharedDefaults else {
            throw SSHMetadataPersistenceError.appGroupUnavailable
        }
        try validateSSHKeyCatalog(candidateKeys)
        let data = try JSONEncoder().encode(candidateKeys)
        guard data.count <= Self.maximumSSHKeyCatalogBytes else {
            throw SSHMetadataPersistenceError.catalogTooLarge
        }

        let sharedSnapshot = sharedDefaults.data(forKey: Self.sharedSSHKeysKey)
        let legacySnapshot = defaults.data(forKey: UserDefaultsKeys.sshKeys)
        do {
            try sharedCatalogWriter(data)
            try verifySSHKeyCatalog(candidateKeys, in: sharedDefaults, key: Self.sharedSSHKeysKey)
            try legacyCatalogWriter(data)
            try verifySSHKeyCatalog(candidateKeys, in: defaults, key: UserDefaultsKeys.sshKeys)
        } catch {
            do {
                try restoreSSHKeyCatalogSnapshots(
                    shared: sharedSnapshot,
                    legacy: legacySnapshot
                )
            } catch {
                throw SSHMetadataPersistenceError.rollbackFailed
            }
            throw error
        }
    }

    private func restoreSSHKeyCatalogSnapshots(shared: Data?, legacy: Data?) throws {
        guard let sharedDefaults else {
            throw SSHMetadataPersistenceError.appGroupUnavailable
        }
        try sharedCatalogWriter(shared)
        try legacyCatalogWriter(legacy)
        try verifyRawCatalogSnapshot(
            shared,
            in: sharedDefaults,
            key: Self.sharedSSHKeysKey
        )
        try verifyRawCatalogSnapshot(
            legacy,
            in: defaults,
            key: UserDefaultsKeys.sshKeys
        )
    }

    private func verifySSHKeyCatalog(
        _ expected: [StoredSSHKey],
        in defaults: UserDefaults,
        key: String
    ) throws {
        guard let readback = defaults.data(forKey: key),
              readback.count <= Self.maximumSSHKeyCatalogBytes,
              let decoded = try? JSONDecoder().decode([StoredSSHKey].self, from: readback),
              decoded == expected else {
            throw SSHMetadataPersistenceError.readbackMismatch
        }
    }

    private func verifyRawCatalogSnapshot(
        _ expected: Data?,
        in defaults: UserDefaults,
        key: String
    ) throws {
        if let expected {
            guard defaults.data(forKey: key) == expected else {
                throw SSHMetadataPersistenceError.rollbackFailed
            }
        } else {
            guard defaults.object(forKey: key) == nil else {
                throw SSHMetadataPersistenceError.rollbackFailed
            }
        }
    }

    private static func sshKeyMaterialMatches(_ lhs: SSHKeyMaterial, _ rhs: SSHKeyMaterial) -> Bool {
        guard lhs.privateKey.toData() == rhs.privateKey.toData() else { return false }
        switch (lhs.passphrase, rhs.passphrase) {
        case (nil, nil):
            return true
        case let (left?, right?):
            return left.toData() == right.toData()
        default:
            return false
        }
    }

    private func restoreSSHKeyMaterialIfNeeded(_ material: SSHKeyMaterial, for keyID: UUID) throws {
        if let current = try sshKeyLifecycleStore.retrieve(keyID) {
            guard Self.sshKeyMaterialMatches(current, material) else {
                throw SSHMetadataPersistenceError.rollbackFailed
            }
            return
        }
        try sshKeyLifecycleStore.save(keyID, material)
        guard let restored = try sshKeyLifecycleStore.retrieve(keyID),
              Self.sshKeyMaterialMatches(restored, material) else {
            throw SSHMetadataPersistenceError.rollbackFailed
        }
    }

    private func recordSSHMetadataError(_ error: any Error) {
        if let persistenceError = error as? SSHMetadataPersistenceError {
            sshKeyCatalogError = persistenceError
        }
    }
}
