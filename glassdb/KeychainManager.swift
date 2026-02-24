//
//  KeychainManager.swift
//  glassdb
//
//  Thin wrapper delegating to GlasSecretStore's KeychainOperations and SSHKeyKeychainStore.
//  Provides app-specific convenience methods while sharing Keychain with glas.sh.
//

import Foundation
import GlasSecretStore
import os

enum KeychainManager {

    // Access group is nil until glas.sh also ships with GlasSecretStore.
    // The entitlement is declared in glassdb.entitlements for when cross-app
    // sharing is enabled — at that point, set accessGroup to
    // "7JQGQ7CRH8.sh.glas.shared" here.
    static let config = SecretStoreConfiguration(
        serviceNamePrefix: "sh.glas",
        accessGroup: nil,
        legacyServiceNamePrefixes: ["app.glassdb"]
    )

    // MARK: - Database Password

    static func savePassword(_ password: String, for connection: DatabaseConnectionConfig) throws {
        let account = "\(connection.username)@\(connection.host):\(connection.port)"
        try KeychainOperations.savePassword(password, account: account, service: config.passwordsService, config: config)
    }

    static func retrievePassword(for connection: DatabaseConnectionConfig) throws -> String {
        let account = "\(connection.username)@\(connection.host):\(connection.port)"
        return try KeychainOperations.retrievePasswordWithFallback(
            account: account,
            primaryService: config.passwordsService,
            legacySuffix: "passwords",
            config: config
        )
    }

    static func deletePassword(for connection: DatabaseConnectionConfig) throws {
        let account = "\(connection.username)@\(connection.host):\(connection.port)"
        try KeychainOperations.deletePassword(account: account, service: config.passwordsService, config: config)
    }

    // MARK: - SSH Password (separate from DB password)

    static func saveSSHPassword(_ password: String, for connection: DatabaseConnectionConfig) throws {
        let account = "ssh:\(connection.sshUsername ?? "")@\(connection.sshHost ?? ""):\(connection.sshPort ?? 22)"
        try KeychainOperations.savePassword(password, account: account, service: config.sshPasswordsService, config: config)
    }

    static func retrieveSSHPassword(for connection: DatabaseConnectionConfig) throws -> String {
        let account = "ssh:\(connection.sshUsername ?? "")@\(connection.sshHost ?? ""):\(connection.sshPort ?? 22)"
        return try KeychainOperations.retrievePasswordWithFallback(
            account: account,
            primaryService: config.sshPasswordsService,
            legacySuffix: "sshpasswords",
            config: config
        )
    }

    static func deleteSSHPassword(for connection: DatabaseConnectionConfig) throws {
        let account = "ssh:\(connection.sshUsername ?? "")@\(connection.sshHost ?? ""):\(connection.sshPort ?? 22)"
        try KeychainOperations.deletePassword(account: account, service: config.sshPasswordsService, config: config)
    }

    // MARK: - SSH Keys

    static func saveSSHKey(_ privateKey: String, passphrase: String?, for keyID: UUID) throws {
        try SSHKeyKeychainStore.save(privateKey: privateKey, passphrase: passphrase, for: keyID, config: config)
    }

    static func retrieveSSHKey(for keyID: UUID) throws -> SSHKeyMaterial {
        try SSHKeyKeychainStore.retrieve(for: keyID, config: config)
    }

    static func deleteSSHKey(for keyID: UUID) throws {
        try SSHKeyKeychainStore.delete(for: keyID, config: config)
    }

    // MARK: - Migration

    static func runMigrationsIfNeeded() {
        let migrationManager = SecretStoreMigrationManager(config: config)
        migrationManager.runScaffoldIfNeeded()
    }
}
