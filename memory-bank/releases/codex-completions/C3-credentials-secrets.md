# C3: Credentials & Secret Integration

**Status**: in progress
**Depends on**: C0, C1
**Source IDs**: S04, S08-S09, G01-G07

## Goal

Keep and extend GlasSecretStore while making credential identity, migration,
sharing, authentication, user-visible availability, and the cross-app **My
Connections** tunnel experience correct.

## Implementation Plan

### Stable identity and migration

- [x] Replace endpoint-derived accounts with stable connection UUID accounts for database and SSH credentials.
- [x] Preserve endpoint lookup only as a one-time copy-migration source without overwriting either destination record.
- [x] Invoke migration during bootstrap before credentials are read.
- [x] Make migration idempotent, resumable, versioned, rollback-preserving, and covered by collision/partial-failure fixtures.
- [x] Present Keychain save/delete/migration failures to the user and block misleading success states.

### Policy and sharing

- [x] Add per-credential policies: shared with glas.sh, glassdb-only, and require user authentication before use.
- [x] Select and document the current `WhenUnlockedThisDeviceOnly` accessibility and access-control behavior for each secret class.
- [x] Add LocalAuthentication/Security access-control behavior for user-presence-protected credentials, including cancellation and unavailable-biometry paths.
- [x] Move shared SSH-key metadata from standard defaults into the configured App Group suite with migration and rollback-window dual writes.
- [x] Add iOS/iPadOS 26 to GlasSecretStore's declared platforms; glassdb's native
  iPhone/iPad consumers compile against the package.
- [ ] Run the full GlasSecretStore suite on every declared platform supported by
  CI and retain physical-device gates for Security-framework-only behavior.

### Glass-family sharing and device synchronization

- [x] Share eligible credentials and SSH metadata between glassdb and glas.sh on the same device through the common Keychain access group and App Group.
- [ ] Move family-wide credential identity and metadata ownership into a stable GlasSecretStore catalog independent of app connection UUIDs.
- [ ] Add iCloud Keychain synchronization and migration for eligible passwords, passphrases, and exportable imported RSA/Ed25519 keys.
- [ ] Separate “shared with Glass apps,” “syncs across devices,” and “requires authentication” in storage policy and UX.
- [ ] Keep Secure Enclave and user-presence-protected material device-bound, with explicit per-device provisioning copy.
- [ ] Warn that deletion of synchronized credentials propagates across devices and cover propagation/conflict/recovery behavior with tests.

### Magic / First Class endpoint integration

- [ ] Adopt a neutral, versioned `EndpointProfile`/`EndpointID` for reusable SSH
  facts and reference a stable GlasSecretStore `CredentialID` without embedding
  secret material.
- [ ] Move glassdb-specific database and tunnel-use fields into an app overlay
  keyed by endpoint identity; preserve current embedded SSH fields as a
  collision-safe, rollback-aware migration source.
- [ ] Present shared endpoints as **My Connections** and select one directly as a
  database SSH tunnel.
- [ ] Surface **Ready**, **Still Syncing**, **Sign In to iCloud**, **Set Up This
  Key**, and **Review Fingerprint** without exposing package/storage vocabulary.
- [ ] Keep host trust, local-network access, user presence, and Secure Enclave
  enrollment explicit; never substitute a weaker credential.

### SSH keys and Secure Enclave language

- [x] Integrate the host-trust store from C1 without duplicating secret-storage logic in the app.
- [x] Use the accurate label “Secure Enclave–wrapped P256” for the implemented lifecycle.
- [x] Update model/UI/docs terminology and threat model for raw P256 reconstruction in the tunnel layer.
- [x] Verify touched logs, user-visible errors, and migrations never expose passwords, passphrases, or private key bytes.

## Exit Criteria

- [x] Two connections sharing username/host/port retain distinct credentials.
- [x] Supported legacy records copy-migrate exactly once without data loss and remain available for rollback.
- [x] Users can understand and change same-device sharing/authentication policy per credential.
- [x] Secret persistence failures block misleading success states and provide recovery actions.
- [x] Secure Enclave wording matches the implemented key lifecycle.
- [ ] Eligible credentials and their stable catalog synchronize across supported Glass-family devices.
- [ ] Cross-device UX and tests clearly preserve the Secure Enclave/user-presence device boundary.
- [ ] An eligible connection defined in glas.sh on iPhone is selectable and
  usable as a glassdb SSH tunnel on Vision Pro without re-entering endpoint or
  credential data; reverse direction and Mac/iPad combinations follow the same
  contract.
- [ ] Fresh install, upgrade, delayed-secret arrival, offline use, iCloud account
  change, deletion/rotation, and local-key enrollment converge without stale
  resurrection, data loss, or phantom readiness.

## Evidence Log

| Date | Migration/Policy Scenario | Expected | Actual | Test/Commit |
|---|---|---|---|---|
| 2026-07-17 | UUID identity and three policies | collision-free stable accounts and explicit access policy | named migration/policy/persistence tests passed | `glassdbTests.swift` credential tests; 44/44 on visionOS 27 |
| 2026-07-17 | Shared secret package | retain package, rotation history, and user-presence behavior | 68/68 passed with host Keychain access | GlasSecretStore PR #2, merge `b21c137` |
| 2026-07-17 | SSH metadata rollback | downgrade retains and tracks prior metadata index | final isolated dual-write test passed | `sshMetadataMigrationRetainsAndUpdatesRollbackIndex` |
| 2026-07-17 | Cross-device availability audit | distinguish current behavior from intended family model | same-device sharing present; no synchronizable catalog/items yet; Secure Enclave and user-presence items device-bound | open C3 work; `decisions.md` 2026-07-17 |
| 2026-08-09 | Database connection-library precursor | establish adaptive library UX without creating a competing endpoint or credential authority | All/Favorites/Recent/Collections and search now project existing database records across all targets; neutral endpoints, CredentialID availability, sync, and tunnel selection remain open | `agent/connection-library-parity`; 414 green platform test executions |
