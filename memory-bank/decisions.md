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
- Consequences: Eligible SSH keys imported in glas.sh are immediately available in glassdb on the same device. Single source of truth for Keychain operations. Both apps stay in lockstep. The original `ThisDeviceOnly` cross-device disposition is superseded by the 2026-07-17 decision below.
- Full plan: `/Users/michael/.claude/plans/buzzing-brewing-haven.md`

## 2026-07-17: Glass-family credential availability and device boundaries
- Status: Approved
- Context: GlasSecretStore exists so glassdb and glas.sh can share credentials across their supported Apple devices, while Secure Enclave keys are cryptographically bound to the device that created them. The existing shared access group and App Group provide same-device sharing only, and the current `ThisDeviceOnly` accessibility prevents eligible Keychain items from synchronizing.
- Decision:
  - GlasSecretStore owns stable credential identities and the synchronized credential/SSH metadata catalog; app-specific connection UUIDs may reference those identities but must not define the family-wide account identity.
  - Passwords, passphrases, and exportable imported RSA/Ed25519 keys may opt into iCloud Keychain synchronization and remain available to authorized Glass-family apps through the shared access group.
  - Secure Enclave keys and user-presence-protected material remain device-bound and require explicit per-device provisioning. UX must distinguish “shared with Glass apps,” “syncs across devices,” and “requires authentication.”
  - Deleting a synchronized credential must warn about and test cross-device propagation. App-only credentials remain outside the shared/synchronized catalog.
- Consequences: Same-device sharing already works; cross-device catalog and eligible-secret synchronization are an open C3 release requirement. Secure Enclave non-sync is a stated platform property, not a failure of the Glass-family sharing model. The future native macOS shell must consume the same GlasSecretStore identities and policies.

## 2026-08-05: My Connections is the shared Glass-family user model

- Status: Approved product and architecture direction; implementation not started
- Context:
  - The 2026-07-17 decision defines credential mobility correctly, but glassdb
    still embeds SSH tunnel fields in each database connection and publishes an
    endpoint-derived compatibility alias for glas.sh.
  - Users moving between glas.sh and glassdb should not have to understand or
    rebuild repository, endpoint-schema, Keychain, CloudKit, or migration state.
- Decision:
  - Present one **My Connections** model across glas.sh and glassdb: define an SSH
    connection once, find it on supported Apple devices, and use it as a terminal
    destination or glassdb database tunnel.
  - Separate neutral `EndpointProfile` metadata, the glassdb database overlay,
    and GlasSecretStore credential identity/material through stable references.
  - Require no proprietary Glass account. Use Apple iCloud/Keychain services and
    explicit consent for eligible cross-device credential mobility.
  - Treat app sharing, device mobility, and authentication kind as independent
    policies. Metadata visibility never implies that a credential is ready.
  - Keep Secure Enclave identities device-bound and require local enrollment on a
    new device; never silently substitute weaker authentication.
  - Keep host trust, user presence, local-network access, and account recovery
    explicit while hiding implementation vocabulary from normal onboarding.
- Consequences:
  - Canonical acceptance path: define an eligible SSH connection in glas.sh on
    iPhone, select it in glassdb on Vision Pro as a database tunnel, complete any
    required local trust action, and connect without re-entering endpoint or
    credential data.
  - Reverse direction, fresh install, upgrade, delayed-secret arrival, offline
    use, account change, deletion/rotation, and Secure Enclave enrollment require
    cross-app/device evidence before public claims.
  - C3 owns glassdb integration; the glas.sh Phase 08 plan owns cross-repository
    coordination; GlasSecretStore owns credential identity and availability.
  - Existing same-device UUID/compatibility behavior remains the migration
    baseline and must not be described as cross-device completion.
- References: `memory-bank/releases/codex-completions/C3-credentials-secrets.md`, `memory-bank/releases/platforms-plus-plus/P6-network-credentials-lifecycle.md`, `../glas.sh/memory-bank/releases/codex-completions/08-glassdb-metadata-sync.md`

## 2026-03-15: DBeaver-style unified workspace over separate windows
- Status: Approved
- Context: Original architecture had separate windows for query editor, schema browser, and results grid. User wanted a traditional IDE layout with sidebar + context-sensitive detail surface, inspired by DBeaver's interaction model.
- Decision: Replace separate query-editor and schema WindowGroups with a single DatabaseWorkspaceView using NavigationSplitView. WorkspaceSelection enum drives detail switching. Schema browser becomes sidebar. Results grid remains detachable for spatial pinning.
- Consequences: More cohesive UX. Sidebar selection drives the entire detail view. Fewer windows to manage. Window ID "query-editor" kept for backward compatibility with openWindow calls.

## 2026-03-15: visionOS 26 SDK migration
- Status: Approved
- Context: Apple's visionOS 26 SDK deadline is April 28, 2026. Liquid Glass introduced at WWDC 2025 replaces manual glass patterns for navigation layer elements.
- Decision: Raise deployment target to visionOS 26.0. Adopt Liquid Glass for ornaments (.toolbar(.bottomOrnament)), keep .ultraThinMaterial only for content-layer elements. Remove manual .ultraThinMaterial backgrounds from content windows (causes double-corner artifact with .windowStyle(.plain)). Add window lifecycle modifiers, accessibility labels, Look to Scroll.
- Consequences: Clean visionOS 26 compliance. App Store ready by deadline. WindowRecoveryManager deleted (replaced by .defaultLaunchBehavior).

## 2026-03-15: simpleQuery for MySQL utility commands
- Status: Approved
- Context: MySQL rejects USE, SET, SHOW, and DDL commands in the prepared statement protocol (COM_STMT_PREPARE). mysql-nio's `connection.query()` always uses prepared statements. Executing `USE database` threw "not supported in prepared statement protocol."
- Decision: Added `isUtilityCommand()` check in MySQLAdapter.execute() that routes utility commands through `connection.simpleQuery()` (COM_QUERY text protocol) while keeping data queries on prepared statements.
- Consequences: USE, SET, SHOW, CREATE, DROP, ALTER, and transaction commands all work. DatabaseSessionManager tracks currentDatabase after USE statements.

## 2026-03-15: .inspector() unavailable on visionOS — use .sheet()
- Status: Approved
- Context: SwiftUI's `.inspector(isPresented:content:)` is explicitly `@available(visionOS, unavailable)` in the SDK headers despite the symbol existing. Apple considers visionOS's spatial paradigm incompatible with 2D inspector drawers. Also tried `.ornament(attachmentAnchor: .scene(.trailing))` but it rendered as a tiny detached floating panel.
- Decision: Use `.sheet()` for the record editor. Full-size modal with NavigationStack + Form. When multiplatform support is added (v1.1), `.inspector()` can be used on iPad/Mac.
- Consequences: Record editor is a proper full-screen modal on visionOS. Platform-specific editor presentation can be added later.

## 2026-03-17: NotificationCenter for toolbar-to-tab communication
- Status: Approved
- Context: visionOS TabView swallows child view `.toolbar` items — toolbar buttons defined inside tab content views never appear in the bottom ornament. This is a known visionOS limitation where TabView manages its own toolbar space.
- Decision: Parent `DatabaseWorkspaceView` owns the bottom ornament toolbar and posts `NotificationCenter` notifications for actions like execute, add row, settings, and AI. Child tab views subscribe via `.onReceive(NotificationCenter.default.publisher(for:))`.
- Consequences: All toolbar actions work reliably. Slight indirection but clean separation. When Apple fixes TabView toolbar forwarding, can migrate back to child-owned toolbars.

## 2026-03-17: Split editor+results layout over separate modes
- Status: Approved
- Context: Original QueryEditorView was a full-screen editor that switched to a results view after execution. Professional database tools (DBeaver, SQL Pro Studio, DataGrip) show the editor and results simultaneously in a vertical split.
- Decision: Data tab shows SQL editor (top) + results grid (bottom) with a draggable resize handle. Editor is always visible — no mode switching. Dark background on editor for visual separation.
- Consequences: Matches user expectations from desktop database tools. Query iteration is faster (edit and see results without switching). Draggable handle lets users allocate space based on their workflow.

## 2026-03-17: Foundation Models for on-device AI
- Status: Approved
- Context: visionOS 26 ships Foundation Models framework for on-device inference. glas.sh already has an AIAssistant with the same pattern. SQL generation from natural language is a high-value feature for database clients.
- Decision: `AIAssistant.swift` wraps Foundation Models behind `#if canImport(FoundationModels)`. Schema-aware: passes table/column metadata as context for grounded SQL generation. Features: SQL generation, error explanation, query summary. Entry point is an AI sparkle button in the workspace ornament.
- Consequences: On-device inference means no API keys or cloud dependency. Schema context prevents hallucinated table/column names. Graceful degradation on devices/simulators without Foundation Models support.

## 2026-03-16: Multiplatform expansion planned for v1.1
- Status: Planned
- Context: iPad has no good native database client — massive market opportunity. Mac is crowded but iPad is wide open. The codebase is 90% standard SwiftUI. Only ~20 platform-specific modifiers need abstraction.
- Decision: Target iPad as primary v1.1 platform, Mac secondary. Use View modifier extensions (one #if per extension, zero in views) instead of scattering #if os() throughout code. On-device authentication and cross-device credential synchronization are separate policies; their current disposition is governed by the 2026-07-17 Glass-family credential decision.
- Consequences: Ship visionOS v1.0 first. Multiplatform work is a focused follow-up, not a rewrite. .inspector() available on iPad/Mac for record editor.
