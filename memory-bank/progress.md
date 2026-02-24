# Progress

## Status: Early Development (Alpha)

### Completed
- [x] Market research — confirmed zero native visionOS DB clients exist
- [x] Architecture planning — PROJECT_SCAFFOLD.md
- [x] glas.sh pattern analysis — reuse mapping documented
- [x] AGENTS.md adapted for glassdb.app
- [x] Memory bank initialized
- [x] Domain identified: glassdb.app (available)
- [x] Xcode project initialized targeting visionOS 2.0+
- [x] Vendored Citadel + swift-nio-ssh packages from glas.sh
- [x] GlassDBKit package created with mysql-nio dependency
- [x] DatabaseProtocol abstraction (`DatabaseEngine`, `DatabaseConnection` protocols)
- [x] MySQLAdapter — full mysql-nio wrapper (connect, execute, schema introspection)
- [x] QueryResult + ColumnInfo + DatabaseValue models in GlassDBKit
- [x] SSHTunnelManager — full SSH tunnel via Citadel with DirectTCPIP forwarding
- [x] Multi-window scene architecture (5 windows: main, query-editor, results, schema, settings)
- [x] Window presence tracking (adapted from glas.sh)
- [x] DatabaseConnectionConfig model with all fields (SSH, TLS, color tags, favorites)
- [x] ConnectionManager — CRUD for saved connections
- [x] ConnectionManagerView — NavigationSplitView sidebar+detail
- [x] ConnectionFormView — add/edit connection forms
- [x] DatabaseSessionManager — session lifecycle (connect, disconnect, execute)
- [x] KeychainManager — secure password storage
- [x] SettingsManager + SettingsView
- [x] QueryEditorView scaffold
- [x] ResultsGridView scaffold
- [x] SchemaBrowserView scaffold
- [x] Logger, Constants, WindowRecoveryManager infrastructure
- [x] Fixed SSHTunnel Sendable conformance (`@unchecked Sendable` for NIO/Citadel types)
- [x] **Clean build** — zero errors on visionOS Simulator (2026-02-23)
- [x] **Disconnect flow hardened** — ELG leaks, zombie sessions, channel close crash all fixed
- [x] **SQL injection fixed** — `escapeIdentifier()` + `escapeLiteral()` in MySQLAdapter
- [x] **Task race condition fixed** — buffered forwarding in LocalToSSHForwarder
- [x] **Schema errors surfaced** — SchemaBrowserView shows errors instead of infinite spinner
- [x] **queryHistory capped** — enforced `maxQueryHistoryItems` setting
- [x] **Force unwrap removed** — KeychainManager `data(using:)` safely guarded
- [x] **GlasSecretStore shared package** — 11 source files, Foundation+Security only
- [x] **SSH key auth integration** — full flow: import → Keychain → UI → connect
- [x] **KeychainManager rewritten** — thin wrapper over shared package
- [x] **Service names unified** — `sh.glas.*` primary, `app.glassdb.*` fallback
- [x] **SSHTunnelManager expanded** — RSA + Secure Enclave P256 + Ed25519
- [x] **SSH key management UI** — Settings section + Add SSH Key sheet
- [x] **ConnectionFormView auth picker** — segmented Password/SSH Key + key selector
- [x] **Entitlements** — keychain-access-groups + application-groups for cross-app sharing
- [x] **Keychain save errors surfaced** — `try?` → `do/catch` + `Logger.keychain` on save and retrieve
- [x] **Credential prompt → sheet** — replaced `.alert()` with `.sheet()` to fix AutoFill presentation collision
- [x] **Password visibility toggle** — eye/eye.slash on all 4 password fields (ConnectionFormView + credential prompt)
- [x] **Connection host:port logging** — `DatabaseSessionManager` logs exact values before `engine.connect()`

### In Progress
- [ ] Wire up end-to-end: connection form → connect → query → results

### Blocked
- Nothing currently blocked

### MVP Checklist
- [x] Connection manager (add/edit/delete MySQL connections)
- [x] SSH tunnel support (Citadel) — password auth working
- [x] Keychain password storage
- [x] MySQL connection via mysql-nio
- [x] SSH key auth (Ed25519 + RSA + Secure Enclave P256) via GlasSecretStore
- [ ] Query editor with syntax highlighting *(editor scaffold exists, no syntax highlighting yet)*
- [ ] Execute query + display results grid *(views exist, need end-to-end wiring)*
- [ ] Schema browser (databases → tables → columns) *(view exists, need live data wiring)*
- [x] Multi-window spatial layout
- [ ] Glass material UI *(`.windowStyle(.plain)` set, glass materials not yet applied to views)*
- [ ] visionOS ornament chrome

### Not Yet Started
- [ ] SQL syntax highlighting engine (SQLLexer, SQLHighlighter, SchemaCompleter)
- [ ] Query history persistence
- [ ] Export results (CSV, JSON)
- [ ] Table data browsing with pagination
- [ ] Autocomplete (keyword + schema-aware)
- [ ] Unit/integration tests
- [ ] GlasSecretStore integration into glas.sh (Phase 3 — separate PR)
