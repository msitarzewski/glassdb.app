//
//  Constants.swift
//  glassdb
//
//  Typed constants for UserDefaults keys.
//  Keychain service names are now derived from the shared GlasSecretStore configuration.
//

import Foundation

enum UserDefaultsKeys {
    static let connections = "glassdb.connections"
    static let savedQueries = "glassdb.savedQueries"
    static let queryHistory = "glassdb.queryHistory"
    static let sshKeys = "glassdb.sshKeys"

    // Settings
    static let maxQueryHistoryItems = "glassdb.maxQueryHistoryItems"
    static let resultRowLimit = "glassdb.resultRowLimit"
    static let windowOpacity = "glassdb.windowOpacity"
    static let blurBackground = "glassdb.blurBackground"
    static let showSidebarByDefault = "glassdb.showSidebarByDefault"
    static let editorFontSize = "glassdb.editorFontSize"
    static let dataGridFontSize = "glassdb.dataGridFontSize"
    static let showLineNumbers = "glassdb.showLineNumbers"
    static let redactQueryHistoryLiterals = "glassdb.redactQueryHistoryLiterals"
}

enum KeychainServiceNames {
    private static let config = KeychainManager.config
    static var passwords: String { config.passwordsService }
    static var sshPasswords: String { config.sshPasswordsService }
    static var sshKeysPrivate: String { config.sshKeysPrivateService }
    static var sshKeysPassphrase: String { config.sshKeysPassphraseService }
    static var sealedP256: String { config.sealedP256Service }
    static var sealedP256Tag: String { config.sealedP256TagService }
}
