# Decisions

## 2026-02-23: Separate app from glas.sh, shared architectural DNA
- Status: Approved
- Context: Database management is a different workflow and user intent than terminal access. Bundling would dilute both.
- Decision: Separate repo, separate App Store listing ($10), shared patterns (glass materials, ornaments, multi-window, Citadel SSH, @Observable managers).
- Consequences: Two focused apps with recognizable "glas" family brand. Code reuse at pattern level, not dependency level.

## 2026-02-23: MySQL first, PostgreSQL fast-follow
- Status: Approved
- Context: Developer (msitarzewski) has 30 years MySQL/LAMP experience, zero PostgreSQL. mysql-nio and postgres-nio share the NIO foundation.
- Decision: Ship v0.1 with MySQL only. Add PostgreSQL in v0.2 behind a DatabaseProtocol abstraction in GlassDBKit.
- Consequences: Faster time to market. Protocol abstraction in GlassDBKit ensures Postgres isn't a rewrite.

## 2026-02-23: mysql-nio from Vapor ecosystem
- Status: Approved
- Context: Need async MySQL client compatible with NIO stack already used by Citadel.
- Decision: Use vapor/mysql-nio. Same NIO event loop foundation as Citadel SSH tunnel.
- Consequences: Clean async/await integration. Vapor ecosystem is well-maintained. Future postgres-nio addition follows same pattern.

## 2026-02-23: @unchecked Sendable for NIO/Citadel wrapper types
- Status: Approved
- Context: Swift 6.2 strict concurrency requires `Sendable` conformance. NIO `Channel` and Citadel `SSHClient` are thread-safe but lack formal `Sendable` conformance.
- Decision: Use `@unchecked Sendable` on wrapper classes (`SSHTunnel`, `MySQLEngine`, `MySQLDatabaseConnection`, `SSHTunnelManager`) that hold NIO/Citadel types as stored properties.
- Consequences: Clean build under strict concurrency. Matches established community pattern for NIO-based code. If upstream adds conformance later, can drop `@unchecked`.

## 2026-02-23: $10 one-time App Store + open source GitHub
- Status: Approved
- Context: Same model as glas.sh. Vision Pro users expect quality and are willing to pay. Open source builds trust and allows contributions.
- Decision: $10 one-time on App Store, free to compile from GitHub.
- Consequences: Sustainable indie pricing. No subscription fatigue. Community contributions possible.

## 2026-02-23: GlasSecretStore shared package for Keychain/SSH key management
- Status: Approved
- Context: Both glas.sh and glassdb need SSH key import, Secure Enclave support, and Keychain CRUD. glas.sh has the full implementation in its app target. glassdb has the model fields and tunnel plumbing but no middle layer. Duplicating would cause drift.
- Decision: Extract a shared `GlasSecretStore` Swift package at `/Users/michael/Developer/GlasSecretStore/`. Zero external dependencies (Foundation + Security only). Both apps depend on it as a local package.
- Key choices:
  - Service names unify on `sh.glas.*` (glas.sh production). glassdb uses `legacyServiceNamePrefixes: ["app.glassdb"]` for migration fallback.
  - Shared Keychain access group: `$(AppIdentifierPrefix)sh.glas.shared` — both apps add this entitlement.
  - Shared App Group: `group.sh.glas.shared` — for UserDefaults sharing of `[StoredSSHKey]` metadata.
  - Configuration is a value type (no singletons). Each app creates its own `SecretStoreConfiguration`.
  - SSH key detection stays in Citadel (not in the shared package). Apps call `SSHKeyDetection.detectPrivateKeyType()` at the call site.
  - `StoredSSHKey` Codable is backward-compatible with glas.sh v1 format.
- Consequences: SSH keys imported in glas.sh are immediately available in glassdb. Single source of truth for Keychain operations. Both apps stay in lockstep. iCloud Keychain sync is not possible (`ThisDeviceOnly` accessibility) — this is intentional for security.
- Full plan: `/Users/michael/.claude/plans/buzzing-brewing-haven.md`
