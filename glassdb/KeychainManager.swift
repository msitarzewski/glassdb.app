//
//  KeychainManager.swift
//  glassdb
//
//  Thin wrapper delegating to GlasSecretStore's KeychainOperations and SSHKeyKeychainStore.
//  Provides app-specific convenience methods while sharing Keychain with glas.sh.
//

import Foundation
import GlasSecretStore
import GlassDBKit
import LocalAuthentication
import os

enum KeychainManager {

    static let credentialMigrationVersionKey = "app.glassdb.connectionCredentialMigrationVersion"
    static let currentCredentialMigrationVersion = 2

    struct CredentialMigrationReport: Sendable {
        let migratedDatabasePasswords: Int
        let migratedSSHPasswords: Int
        let failures: [String]

        var isSuccessful: Bool { failures.isEmpty }
    }

    struct CredentialMigrationStore: @unchecked Sendable {
        let retrieveData: (
            _ account: String,
            _ service: String,
            _ config: SecretStoreConfiguration
        ) throws -> Data
        let retrievePassword: (
            _ account: String,
            _ service: String,
            _ config: SecretStoreConfiguration
        ) throws -> String
        let savePassword: (
            _ value: String,
            _ account: String,
            _ service: String,
            _ config: SecretStoreConfiguration
        ) throws -> Void

        static let live = CredentialMigrationStore(
            retrieveData: { account, service, config in
                try KeychainOperations.retrieveData(
                    account: account,
                    service: service,
                    config: config
                )
            },
            retrievePassword: { account, service, config in
                try KeychainOperations.retrievePassword(
                    account: account,
                    service: service,
                    config: config
                )
            },
            savePassword: { value, account, service, config in
                try KeychainOperations.savePassword(
                    value,
                    account: account,
                    service: service,
                    config: config
                )
            }
        )
    }

    struct CredentialMigrationError: LocalizedError {
        let failures: [String]

        var errorDescription: String? {
            "Some saved credentials could not be upgraded. Your connections were kept, but affected credentials must be saved again. \(failures.joined(separator: " "))"
        }
    }

    enum CredentialKind: Sendable {
        case databasePassword
        case sshPassword
    }

    struct CredentialStorageDescriptor: Sendable {
        let service: String
        let config: SecretStoreConfiguration
        let accessPolicy: SecretAccessPolicy
        let authenticationPrompt: String?
        let isSharedWithGlas: Bool
    }

    struct CredentialPersistenceReport: Sendable {
        let cleanupWarnings: [String]
    }

    enum CredentialPolicyError: LocalizedError {
        case authenticationUnavailable(String)
        case authenticationCancelledOrCredentialUnavailable
        case verificationFailed

        var errorDescription: String? {
            switch self {
            case .authenticationUnavailable(let reason):
                return "Device-owner authentication is unavailable. \(reason)"
            case .authenticationCancelledOrCredentialUnavailable:
                return "Authentication was canceled, failed, or the protected credential is unavailable."
            case .verificationFailed:
                return "The credential could not be verified in its new secure storage location. The previous copy was retained."
            }
        }
    }

    static let sharedConfig = SecretStoreConfiguration(
        serviceNamePrefix: "sh.glas",
        accessGroup: "7JQGQ7CRH8.sh.glas.shared",
        legacyServiceNamePrefixes: ["app.glassdb"]
    )

    static let appOnlyConfig = SecretStoreConfiguration(
        serviceNamePrefix: "app.glassdb.private",
        accessGroup: nil
    )

    static let authenticatedConfig = SecretStoreConfiguration(
        serviceNamePrefix: "app.glassdb.protected",
        accessGroup: nil
    )

    /// SSH keys and host pins remain intentionally shared with glas.sh.
    static let config = sharedConfig

    // MARK: - Database Password

    static func savePassword(_ password: String, for connection: DatabaseConnectionConfig) throws {
        try save(password, account: databaseAccount(for: connection.id), descriptor: descriptor(
            for: connection.databaseCredentialPolicy,
            kind: .databasePassword
        ))
    }

    static func retrievePassword(for connection: DatabaseConnectionConfig) throws -> String {
        let storage = descriptor(for: connection.databaseCredentialPolicy, kind: .databasePassword)
        do {
            return try retrieveStablePassword(
                account: databaseAccount(for: connection.id),
                descriptor: storage
            )
        } catch GlasSecretStore.SecretStoreError.notFound {
            guard connection.databaseCredentialPolicy == .sharedWithGlas else {
                throw GlasSecretStore.SecretStoreError.notFound
            }
            let password = try retrieveLegacyPassword(
                account: legacyDatabaseAccount(for: connection),
                primaryService: sharedConfig.passwordsService,
                legacySuffix: "passwords"
            )
            try savePassword(password, for: connection)
            return password
        }
    }

    static func deletePassword(for connection: DatabaseConnectionConfig) throws {
        try delete(account: databaseAccount(for: connection.id), descriptor: descriptor(
            for: connection.databaseCredentialPolicy,
            kind: .databasePassword
        ))
    }

    // MARK: - SSH Password (separate from DB password)

    static func saveSSHPassword(_ password: String, for connection: DatabaseConnectionConfig) throws {
        try save(password, account: sshAccount(for: connection.id), descriptor: descriptor(
            for: connection.sshCredentialPolicy,
            kind: .sshPassword
        ))
    }

    static func retrieveSSHPassword(for connection: DatabaseConnectionConfig) throws -> String {
        let storage = descriptor(for: connection.sshCredentialPolicy, kind: .sshPassword)
        do {
            return try retrieveStablePassword(
                account: sshAccount(for: connection.id),
                descriptor: storage
            )
        } catch GlasSecretStore.SecretStoreError.notFound {
            guard connection.sshCredentialPolicy == .sharedWithGlas else {
                throw GlasSecretStore.SecretStoreError.notFound
            }
            let password = try retrieveLegacyPassword(
                account: legacySSHAccount(for: connection),
                primaryService: sharedConfig.sshPasswordsService,
                legacySuffix: "sshpasswords"
            )
            try saveSSHPassword(password, for: connection)
            return password
        }
    }

    static func deleteSSHPassword(for connection: DatabaseConnectionConfig) throws {
        try delete(account: sshAccount(for: connection.id), descriptor: descriptor(
            for: connection.sshCredentialPolicy,
            kind: .sshPassword
        ))
    }

    /// Saves and verifies every destination before removing any prior-policy
    /// record. Cleanup failures are warnings because the verified destination is
    /// already authoritative and blocking the metadata update would make it
    /// unreachable despite retaining the source or destination bytes.
    static func saveCredentials(
        databasePassword: String,
        sshPassword: String?,
        for connection: DatabaseConnectionConfig,
        replacing previousConnection: DatabaseConnectionConfig?
    ) throws -> CredentialPersistenceReport {
        var writes: [CredentialWrite] = []
        if !databasePassword.isEmpty {
            writes.append(CredentialWrite(
                value: databasePassword,
                account: databaseAccount(for: connection.id),
                destination: descriptor(for: connection.databaseCredentialPolicy, kind: .databasePassword),
                source: previousConnection.map {
                    descriptor(for: $0.databaseCredentialPolicy, kind: .databasePassword)
                }
            ))
        }
        if let sshPassword, !sshPassword.isEmpty,
           connection.useSSHTunnel, connection.sshAuthMethod != .sshKey {
            writes.append(CredentialWrite(
                value: sshPassword,
                account: sshAccount(for: connection.id),
                destination: descriptor(for: connection.sshCredentialPolicy, kind: .sshPassword),
                source: previousConnection.map {
                    descriptor(for: $0.sshCredentialPolicy, kind: .sshPassword)
                }
            ))
        }

        var completedWrites: [CredentialWrite] = []
        do {
            for write in writes {
                try save(write.value, account: write.account, descriptor: write.destination)
                completedWrites.append(write)
                let verified = try retrieveStablePassword(
                    account: write.account,
                    descriptor: write.destination
                )
                guard verified == write.value else { throw CredentialPolicyError.verificationFailed }
            }
        } catch {
            // Only remove newly selected locations. A same-policy write is the
            // source record and must never be deleted during recovery.
            for write in completedWrites.reversed() where !write.destination.matches(write.source) {
                try? delete(account: write.account, descriptor: write.destination)
            }
            throw error
        }

        var cleanupWarnings: [String] = []
        for write in writes {
            guard let source = write.source, !write.destination.matches(source) else { continue }
            do {
                try delete(account: write.account, descriptor: source)
            } catch {
                cleanupWarnings.append(
                    "The credential was moved successfully, but its previous Keychain copy could not be removed."
                )
            }
        }

        if let previousConnection,
           previousConnection.useSSHTunnel,
           previousConnection.sshAuthMethod != .sshKey,
           (!connection.useSSHTunnel || connection.sshAuthMethod == .sshKey) {
            do {
                try deleteSSHPassword(for: previousConnection)
            } catch {
                cleanupWarnings.append(
                    "The unused SSH password could not be removed from its previous Keychain location."
                )
            }
        }
        return CredentialPersistenceReport(cleanupWarnings: cleanupWarnings)
    }

    // MARK: - SSH Keys

    static func saveSSHKey(_ privateKey: String, passphrase: String?, for keyID: UUID) throws {
        let secureKey = SecureBytes(Data(privateKey.utf8))
        let securePassphrase = passphrase.map { SecureBytes(Data($0.utf8)) }
        try SSHKeyKeychainStore.save(privateKey: secureKey, passphrase: securePassphrase, for: keyID, config: config)
    }

    static func retrieveSSHKey(for keyID: UUID) throws -> SSHKeyMaterial {
        try SSHKeyKeychainStore.retrieve(for: keyID, config: config)
    }

    static func deleteSSHKey(for keyID: UUID) throws {
        try SSHKeyKeychainStore.delete(for: keyID, config: config)
    }

    // MARK: - SSH Host Trust

    static func saveHostKey(_ challenge: SSHHostKeyChallenge) throws {
        let hostKey = PinnedSSHHostKey(
            host: challenge.host,
            port: challenge.port,
            algorithm: challenge.algorithm,
            publicKeyData: challenge.publicKeyData,
            sha256Fingerprint: challenge.fingerprintSHA256
        )
        if challenge.reason == .changed {
            // Preserve revoked history for audit while advancing the only generation
            // permitted to authorize this endpoint.
            try SSHHostTrustKeychainStore.replace(with: hostKey, config: config)
        } else {
            try SSHHostTrustKeychainStore.save(hostKey, config: config)
        }
    }

    // MARK: - Migration

    @discardableResult
    static func runMigrationsIfNeeded(
        connections: [DatabaseConnectionConfig],
        defaults: UserDefaults = .standard
    ) throws -> CredentialMigrationReport {
        let migrationManager = SecretStoreMigrationManager(config: config)
        migrationManager.runScaffoldIfNeeded()

        guard defaults.integer(forKey: credentialMigrationVersionKey) < currentCredentialMigrationVersion else {
            return CredentialMigrationReport(
                migratedDatabasePasswords: 0,
                migratedSSHPasswords: 0,
                failures: []
            )
        }

        var databaseCount = 0
        var sshCount = 0
        var failures: [String] = []

        for connection in connections {
            do {
                if try migrateLegacyCredentialIfPresent(
                    destinationAccount: databaseAccount(for: connection.id),
                    legacyAccount: legacyDatabaseAccount(for: connection),
                    primaryService: config.passwordsService,
                    legacySuffix: "passwords"
                ) {
                    databaseCount += 1
                }
            } catch {
                failures.append("Database password for ‘\(connection.name)’ was not migrated.")
            }

            guard connection.useSSHTunnel, connection.sshAuthMethod != .sshKey else { continue }
            do {
                if try migrateLegacyCredentialIfPresent(
                    destinationAccount: sshAccount(for: connection.id),
                    legacyAccount: legacySSHAccount(for: connection),
                    primaryService: config.sshPasswordsService,
                    legacySuffix: "sshpasswords"
                ) {
                    sshCount += 1
                }
            } catch {
                failures.append("SSH password for ‘\(connection.name)’ was not migrated.")
            }
        }

        let report = CredentialMigrationReport(
            migratedDatabasePasswords: databaseCount,
            migratedSSHPasswords: sshCount,
            failures: failures
        )
        if report.isSuccessful {
            defaults.set(currentCredentialMigrationVersion, forKey: credentialMigrationVersionKey)
        } else {
            throw CredentialMigrationError(failures: failures)
        }
        return report
    }

    static func databaseAccount(for connectionID: UUID) -> String {
        "database:\(connectionID.uuidString.lowercased())"
    }

    static func sshAccount(for connectionID: UUID) -> String {
        "ssh:\(connectionID.uuidString.lowercased())"
    }

    static func legacyDatabaseAccount(for connection: DatabaseConnectionConfig) -> String {
        "\(connection.username)@\(connection.host):\(connection.port)"
    }

    static func legacySSHAccount(for connection: DatabaseConnectionConfig) -> String {
        "ssh:\(connection.sshUsername ?? "")@\(connection.sshHost ?? ""):\(connection.sshPort ?? 22)"
    }

    static func descriptor(
        for policy: CredentialStoragePolicy,
        kind: CredentialKind
    ) -> CredentialStorageDescriptor {
        let config: SecretStoreConfiguration
        let accessPolicy: SecretAccessPolicy
        let prompt: String?
        let isShared: Bool
        switch policy {
        case .sharedWithGlas:
            config = sharedConfig
            accessPolicy = .standard
            prompt = nil
            isShared = true
        case .glassdbOnly:
            config = appOnlyConfig
            accessPolicy = .standard
            prompt = nil
            isShared = false
        case .requireAuthentication:
            config = authenticatedConfig
            accessPolicy = .userPresence
            prompt = kind == .databasePassword
                ? "Authenticate to use this database password."
                : "Authenticate to use this SSH password."
            isShared = false
        }
        let service = kind == .databasePassword
            ? config.passwordsService
            : config.sshPasswordsService
        return CredentialStorageDescriptor(
            service: service,
            config: config,
            accessPolicy: accessPolicy,
            authenticationPrompt: prompt,
            isSharedWithGlas: isShared
        )
    }

    private static func retrieveLegacyPassword(
        account: String,
        primaryService: String,
        legacySuffix: String,
        store: CredentialMigrationStore = .live
    ) throws -> String {
        do {
            return try store.retrievePassword(account, primaryService, config)
        } catch GlasSecretStore.SecretStoreError.notFound {
            // Only a verified absence permits lookup in the next legacy service.
        }
        for prefix in config.legacyServiceNamePrefixes {
            do {
                return try store.retrievePassword(
                    account,
                    "\(prefix).\(legacySuffix)",
                    config
                )
            } catch GlasSecretStore.SecretStoreError.notFound {
                continue
            }
        }
        throw GlasSecretStore.SecretStoreError.notFound
    }

    static func migrateLegacyCredentialIfPresent(
        destinationAccount: String,
        legacyAccount: String,
        primaryService: String,
        legacySuffix: String,
        store: CredentialMigrationStore = .live
    ) throws -> Bool {
        do {
            _ = try store.retrieveData(destinationAccount, primaryService, config)
            return false
        } catch GlasSecretStore.SecretStoreError.notFound {
            // Only a verified absence permits consulting legacy credentials.
        }

        let value: String
        do {
            value = try retrieveLegacyPassword(
                account: legacyAccount,
                primaryService: primaryService,
                legacySuffix: legacySuffix,
                store: store
            )
        } catch GlasSecretStore.SecretStoreError.notFound {
            return false
        }
        try store.savePassword(
            value,
            destinationAccount,
            primaryService,
            config
        )
        return true
    }

    private struct CredentialWrite {
        let value: String
        let account: String
        let destination: CredentialStorageDescriptor
        let source: CredentialStorageDescriptor?
    }

    private static func save(
        _ value: String,
        account: String,
        descriptor: CredentialStorageDescriptor
    ) throws {
        try KeychainOperations.savePassword(
            value,
            account: account,
            service: descriptor.service,
            config: descriptor.config,
            policy: descriptor.accessPolicy
        )
    }

    private static func delete(
        account: String,
        descriptor: CredentialStorageDescriptor
    ) throws {
        try KeychainOperations.deletePassword(
            account: account,
            service: descriptor.service,
            config: descriptor.config
        )
    }

    private static func retrieveStablePassword(
        account: String,
        descriptor: CredentialStorageDescriptor
    ) throws -> String {
        if descriptor.accessPolicy == .userPresence {
            let context = LAContext()
            var evaluationError: NSError?
            guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &evaluationError) else {
                throw CredentialPolicyError.authenticationUnavailable(
                    evaluationError?.localizedDescription ?? "Configure a device passcode or biometric authentication and try again."
                )
            }
        }
        let data: Data
        do {
            data = try KeychainOperations.retrieveData(
                account: account,
                service: descriptor.service,
                config: descriptor.config,
                authenticationPrompt: descriptor.authenticationPrompt
            )
        } catch {
            if descriptor.accessPolicy == .userPresence {
                throw CredentialPolicyError.authenticationCancelledOrCredentialUnavailable
            }
            throw error
        }
        guard let value = String(data: data, encoding: .utf8) else {
            throw GlasSecretStore.SecretStoreError.encodingFailed
        }
        return value
    }
}

private extension KeychainManager.CredentialStorageDescriptor {
    func matches(_ other: KeychainManager.CredentialStorageDescriptor?) -> Bool {
        guard let other else { return false }
        return service == other.service && isSharedWithGlas == other.isSharedWithGlas
    }
}
