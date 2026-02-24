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
    var autoReconnect: Bool = true
    var confirmBeforeClosing: Bool = true
    var maxQueryHistoryItems: Int = 500
    var resultRowLimit: Int = 1000
    var windowOpacity: Double = 0.95
    var blurBackground: Bool = true
    var interactiveGlassEffects: Bool = true
    var glassTint: String = "None"
    var showSidebarByDefault: Bool = true
    var editorFontSize: Double = 14.0
    var showLineNumbers: Bool = true
    var savedQueries: [SavedQuery] = []
    var sshKeys: [StoredSSHKey] = []

    private var hasLoaded = false

    init(loadImmediately: Bool = true) {
        if loadImmediately {
            loadIfNeeded()
        }
    }

    func loadIfNeeded() {
        guard !hasLoaded else { return }
        hasLoaded = true

        if UserDefaults.standard.object(forKey: UserDefaultsKeys.autoReconnect) != nil {
            autoReconnect = UserDefaults.standard.bool(forKey: UserDefaultsKeys.autoReconnect)
        }
        if UserDefaults.standard.object(forKey: UserDefaultsKeys.confirmBeforeClosing) != nil {
            confirmBeforeClosing = UserDefaults.standard.bool(forKey: UserDefaultsKeys.confirmBeforeClosing)
        }
        let savedMaxHistory = UserDefaults.standard.integer(forKey: UserDefaultsKeys.maxQueryHistoryItems)
        if savedMaxHistory > 0 {
            maxQueryHistoryItems = savedMaxHistory
        }
        let savedRowLimit = UserDefaults.standard.integer(forKey: UserDefaultsKeys.resultRowLimit)
        if savedRowLimit > 0 {
            resultRowLimit = savedRowLimit
        }
        if UserDefaults.standard.object(forKey: UserDefaultsKeys.windowOpacity) != nil {
            windowOpacity = UserDefaults.standard.double(forKey: UserDefaultsKeys.windowOpacity)
        }
        if UserDefaults.standard.object(forKey: UserDefaultsKeys.blurBackground) != nil {
            blurBackground = UserDefaults.standard.bool(forKey: UserDefaultsKeys.blurBackground)
        }
        if UserDefaults.standard.object(forKey: UserDefaultsKeys.interactiveGlassEffects) != nil {
            interactiveGlassEffects = UserDefaults.standard.bool(forKey: UserDefaultsKeys.interactiveGlassEffects)
        }
        if let savedGlassTint = UserDefaults.standard.string(forKey: UserDefaultsKeys.glassTint) {
            glassTint = savedGlassTint
        }
        if UserDefaults.standard.object(forKey: UserDefaultsKeys.showSidebarByDefault) != nil {
            showSidebarByDefault = UserDefaults.standard.bool(forKey: UserDefaultsKeys.showSidebarByDefault)
        }
        if UserDefaults.standard.object(forKey: UserDefaultsKeys.editorFontSize) != nil {
            editorFontSize = UserDefaults.standard.double(forKey: UserDefaultsKeys.editorFontSize)
        }
        if UserDefaults.standard.object(forKey: UserDefaultsKeys.showLineNumbers) != nil {
            showLineNumbers = UserDefaults.standard.bool(forKey: UserDefaultsKeys.showLineNumbers)
        }

        loadSavedQueries()
        loadSSHKeys()
    }

    func saveSettings() {
        UserDefaults.standard.set(autoReconnect, forKey: UserDefaultsKeys.autoReconnect)
        UserDefaults.standard.set(confirmBeforeClosing, forKey: UserDefaultsKeys.confirmBeforeClosing)
        UserDefaults.standard.set(maxQueryHistoryItems, forKey: UserDefaultsKeys.maxQueryHistoryItems)
        UserDefaults.standard.set(resultRowLimit, forKey: UserDefaultsKeys.resultRowLimit)
        UserDefaults.standard.set(windowOpacity, forKey: UserDefaultsKeys.windowOpacity)
        UserDefaults.standard.set(blurBackground, forKey: UserDefaultsKeys.blurBackground)
        UserDefaults.standard.set(interactiveGlassEffects, forKey: UserDefaultsKeys.interactiveGlassEffects)
        UserDefaults.standard.set(glassTint, forKey: UserDefaultsKeys.glassTint)
        UserDefaults.standard.set(showSidebarByDefault, forKey: UserDefaultsKeys.showSidebarByDefault)
        UserDefaults.standard.set(editorFontSize, forKey: UserDefaultsKeys.editorFontSize)
        UserDefaults.standard.set(showLineNumbers, forKey: UserDefaultsKeys.showLineNumbers)
    }

    // MARK: - Saved Queries

    func loadSavedQueries() {
        guard let data = UserDefaults.standard.data(forKey: UserDefaultsKeys.savedQueries) else {
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
            UserDefaults.standard.set(data, forKey: UserDefaultsKeys.savedQueries)
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
        guard let data = UserDefaults.standard.data(forKey: UserDefaultsKeys.sshKeys) else {
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
            UserDefaults.standard.set(data, forKey: UserDefaultsKeys.sshKeys)
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

    func deleteSSHKey(_ key: StoredSSHKey) {
        try? KeychainManager.deleteSSHKey(for: key.id)
        sshKeys.removeAll { $0.id == key.id }
        saveSSHKeys()
    }

    func renameSSHKey(_ key: StoredSSHKey, name: String) {
        if let index = sshKeys.firstIndex(where: { $0.id == key.id }) {
            sshKeys[index].name = name
            saveSSHKeys()
        }
    }
}
