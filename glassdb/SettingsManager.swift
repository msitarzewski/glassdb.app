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

@MainActor
@Observable
class SettingsManager {
    static let defaultSharedDefaults = UserDefaults(suiteName: "group.sh.glas.shared") ?? .standard
    private static let sharedSSHKeysKey = "sshKeys"
    var maxQueryHistoryItems: Int = 500
    var resultRowLimit: Int = 1000
    var windowOpacity: Double = 0.95
    var blurBackground: Double = 1.0
    var showSidebarByDefault: Bool = true
    var editorFontSize: Double = 14.0
    var dataGridFontSize: Double = 13.0
    var showLineNumbers: Bool = true
    var redactQueryHistoryLiterals: Bool = false
    var savedQueries: [SavedQuery] = []
    var sshKeys: [StoredSSHKey] = []

    private var hasLoaded = false
    private let defaults: UserDefaults
    private let sharedDefaults: UserDefaults

    init(
        loadImmediately: Bool = true,
        defaults: UserDefaults = .standard,
        sharedDefaults: UserDefaults = SettingsManager.defaultSharedDefaults
    ) {
        self.defaults = defaults
        self.sharedDefaults = sharedDefaults
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
            windowOpacity = defaults.double(forKey: UserDefaultsKeys.windowOpacity)
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
        if defaults.object(forKey: UserDefaultsKeys.redactQueryHistoryLiterals) != nil {
            redactQueryHistoryLiterals = defaults.bool(forKey: UserDefaultsKeys.redactQueryHistoryLiterals)
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
        defaults.set(redactQueryHistoryLiterals, forKey: UserDefaultsKeys.redactQueryHistoryLiterals)
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
        migrateSSHKeyMetadataToAppGroupIfNeeded()
        guard let data = sharedDefaults.data(forKey: Self.sharedSSHKeysKey) else {
            sshKeys = []
            return
        }
        do {
            sshKeys = try JSONDecoder().decode([StoredSSHKey].self, from: data)
        } catch {
            Logger.settings.error("Failed to load SSH keys: \(error)")
            sshKeys = []
        }
    }

    private func saveSSHKeys() {
        do {
            let data = try JSONEncoder().encode(sshKeys)
            sharedDefaults.set(data, forKey: Self.sharedSSHKeysKey)
            // Keep the previous glassdb build's metadata index synchronized for
            // the rollback-support window. Key material remains in Keychain.
            defaults.set(data, forKey: UserDefaultsKeys.sshKeys)
        } catch {
            Logger.settings.error("Failed to save SSH keys: \(error)")
        }
    }

    func addSSHKey(name: String, privateKey: String, passphrase: String?, algorithmKind: SSHKeyAlgorithmKind) throws {
        let keyID = UUID()
        try KeychainManager.saveSSHKey(privateKey, passphrase: passphrase, for: keyID)
        let storedKey = StoredSSHKey(
            id: keyID,
            name: name,
            algorithm: algorithmKind.badgeName,
            storageKind: .imported,
            algorithmKind: algorithmKind,
            migrationState: .notNeeded
        )
        sshKeys.append(storedKey)
        saveSSHKeys()
    }

    func deleteSSHKey(_ key: StoredSSHKey) throws {
        try KeychainManager.deleteSSHKey(for: key.id)
        sshKeys.removeAll { $0.id == key.id }
        saveSSHKeys()
    }

    func renameSSHKey(_ key: StoredSSHKey, name: String) {
        if let index = sshKeys.firstIndex(where: { $0.id == key.id }) {
            sshKeys[index].name = name
            saveSSHKeys()
        }
    }

    private func migrateSSHKeyMetadataToAppGroupIfNeeded() {
        var merged: [StoredSSHKey] = []
        let candidateData = [
            sharedDefaults.data(forKey: Self.sharedSSHKeysKey),
            sharedDefaults.data(forKey: UserDefaultsKeys.sshKeys),
            defaults.data(forKey: UserDefaultsKeys.sshKeys)
        ]

        for data in candidateData.compactMap({ $0 }) {
            guard let decoded = try? JSONDecoder().decode([StoredSSHKey].self, from: data) else { continue }
            for key in decoded where !merged.contains(where: { $0.id == key.id }) {
                merged.append(key)
            }
        }
        guard !merged.isEmpty, let encoded = try? JSONEncoder().encode(merged) else { return }
        sharedDefaults.set(encoded, forKey: Self.sharedSSHKeysKey)
        // Copy rather than move. The former release reads only this legacy
        // index, so retaining it makes an immediate downgrade recoverable.
        defaults.set(encoded, forKey: UserDefaultsKeys.sshKeys)
    }
}
