# Progress

## Status: Native visionOS/macOS Implementation Complete; External Release Gates Open

### Completed — Infrastructure
- [x] Initial market scan completed; revalidate competitor claims before public use
- [x] Architecture planning — PROJECT_SCAFFOLD.md
- [x] glas.sh pattern analysis — reuse mapping documented
- [x] AGENTS.md adapted for glassdb.app
- [x] Memory bank initialized
- [x] Domain identified: glassdb.app (available)
- [x] Xcode project targets native visionOS 26.0+ and native macOS 27.0+ application/test paths
- [x] Vendored Citadel + swift-nio-ssh packages from glas.sh
- [x] GlassDBKit package created with mysql-nio dependency
- [x] GitHub repo created, initial commit pushed

### Completed — Core Engine
- [x] DatabaseProtocol abstraction (`DatabaseEngine`, `DatabaseConnection` protocols)
- [x] MySQLAdapter — mysql-nio connect, execute, and schema-introspection paths used by the app
- [x] Passwordless `caching_sha2_password` compatibility — immutable mysql-nio fork pin at `3ad138f`, focused upstream regression coverage, passing gated GlassDBKit/MySQL 9.7.1 test, user-confirmed fresh Mac-app connection, and upstream draft PR #126
- [x] Typed QueryResult, ColumnInfo, and DatabaseValue models in GlassDBKit
- [x] SSHTunnelManager — verified-host Citadel DirectTCPIP forwarding
- [x] Utility command routing — USE/SET/SHOW through simpleQuery (COM_QUERY)
- [x] Protocol extensions: showCreateTable, indexes, foreignKeys, tableStatus, rowCount
- [x] New models: IndexInfo, ForeignKeyInfo, TableStatus, DatabaseError

### Completed — Connection Management
- [x] DatabaseConnectionConfig model with all fields (SSH, TLS, color tags, favorites)
- [x] ConnectionManager — CRUD for saved connections
- [x] ConnectionManagerView — NavigationSplitView sidebar+detail
- [x] ConnectionFormView — add/edit connection forms with test buttons
- [x] DatabaseSessionManager — session lifecycle (connect, disconnect, execute)
- [x] KeychainManager — secure password storage via GlasSecretStore
- [x] GlasSecretStore shared package — 11 source files, Foundation+Security only
- [x] SSH key auth — Ed25519, RSA, and Secure Enclave-wrapped P256 import/manage/connect
- [x] SSH key management UI — Settings section + Add SSH Key sheet
- [x] ConnectionFormView auth picker — segmented Password/SSH Key + key selector
- [x] Credential prompt sheet (replaced alert to fix AutoFill collision)
- [x] Password visibility toggle on all password fields

### Completed — Workspace Architecture
- [x] Unified DatabaseWorkspaceView — NavigationSplitView with sidebar + context-sensitive detail
- [x] WorkspaceSelection enum (.database, .table, .query) drives detail surface
- [x] Schema browser integrated as sidebar (was separate window)
- [x] Sidebar toggle button (topBarLeading)
- [x] Connection name in navigation title

### Completed — Database Manager Features
- [x] TableDetailView — capability-gated Data, Structure, DDL, Indexes, and Foreign Keys tabs
- [x] Data tab — auto-loads rows, frozen row numbers, content-width columns, filler cells
- [x] Structure tab — column definitions from INFORMATION_SCHEMA
- [x] DDL tab — SHOW CREATE TABLE with syntax highlighting + copy button
- [x] Indexes tab — SHOW INDEX results
- [x] Foreign Keys tab — KEY_COLUMN_USAGE query
- [x] DatabaseDetailView — properties, table count/rows/size stats, Set Active action
- [x] Context menus on databases and tables (Browse, Copy, Truncate, Drop)
- [x] Row count badges in sidebar (lazy-loaded)
- [x] Filter/search field in sidebar
- [x] CSV, TSV, JSON, and SQL INSERT export workflows (DataExporter)

### Completed — Record Editor
- [x] RecordEditorView — sheet modal with staging model
- [x] Type-specific editors: text, JSON (format/validate), booleans, dates, numbers
- [x] NULL as placeholder text — type to replace
- [x] Modified field indicators
- [x] Bound optimistic UPDATE using stable identity plus original-row predicates
- [x] Column metadata loaded for PK detection
- [x] Add Row mode with INSERT SQL generation

### Completed — SQL Tooling
- [x] SQLHighlighter — SQL-aware tokenizer/parser for editor workflows
- [x] HighlightedTextEditor — UIViewRepresentable with UITextView, cursor preservation
- [x] Basic linter (unterminated strings/identifiers)
- [x] Cmd+Return keyboard shortcut for execute
- [x] Parser-backed sequential multi-query execution; stops on failure and displays the latest result
- [x] Brighter syntax highlighting colors for dark editor background

### Completed — visionOS 26 Migration (PR #1)
- [x] Deployment target raised to visionOS 26.0
- [x] Liquid Glass ornaments via .toolbar(.bottomOrnament)
- [x] Window lifecycle: defaultLaunchBehavior, restorationBehavior
- [x] Settings converted to singleton Window
- [x] WindowRecoveryManager deleted
- [x] Stale session guards (ContentUnavailableView)
- [x] Accessibility: grid headers, data cells, status indicators, form labels
- [x] Look to Scroll on major database/editor grid surfaces
- [x] Removed double-corner .ultraThinMaterial backgrounds
- [x] Alternating row colors adaptive (Color.primary.opacity)

### Completed — Data Grid
- [x] LazyVStack with pinnedViews for sticky headers
- [x] GeometryReader-based column width calculation
- [x] Empty filler columns/rows (DBeaver-style spreadsheet)
- [x] Frozen row numbers (scroll sync fixed, continue across pages)
- [x] Row selection highlighting
- [x] Split editor+results layout (SQL editor top, results bottom, draggable resize handle)
- [x] Dark background on editor area
- [x] Pagination: page nav bar, rows-per-page input, total row count, LIMIT/OFFSET
- [x] Pager syncs with query LIMIT (isAutoQuery flag)
- [x] Font size setting (dataGridFontSize, default 13.0)

### Completed — Query Execution
- [x] Auto-repeat: table-data Execute context menu offers a fixed 10-second interval
- [x] Execute button in header (play icon)
- [x] Parser-backed statement selection and deterministic side-effect classification
- [x] Configurable server-side editor result bounds with sentinel-row truncation reporting
- [x] Persistent history with search, connection, and status filters; saved queries persist
- [x] Multiple text/selection/result tabs and bounded SQL document open/save
- [x] Schema-aware completion, formatting, diagnostics, line numbers, and explain entry point

### Completed — Toolbar & Navigation
- [x] Toolbar moved to bottom ornament (TabView swallows child toolbars on visionOS)
- [x] NotificationCenter for toolbar-to-tab communication
- [x] Settings gear in workspace ornament
- [x] AI sparkle button entry point in workspace ornament

### Completed — AI Assistant
- [x] AIAssistant.swift — Foundation Models integration (`#if canImport(FoundationModels)`)
- [x] Current-table context with disclosure, metadata-only default, redaction, and size limits
- [x] Error-explanation and query-summary model methods (not yet surfaced in product UI)
- [x] Editor-first generation with deterministic SQL safety policy
- [x] Foundation Models availability gating (minimum-runtime launch remains a C9 gate)

### Completed — Trust, Engines, and Data Safety
- [x] Required/disabled/pinned MySQL TLS adapter policy with fail-closed validation
- [x] SSH TOFU fingerprint confirmation and changed-host-key rejection
- [x] Stable UUID credentials, rollback-preserving legacy migration, and three credential policies with same-device Glass-family sharing
- [x] App Group SSH metadata migration with rollback-window dual writes
- [x] On-device user-presence credential policy and device-bound Secure Enclave-wrapped keys
- [x] Typed value fidelity, parameter binding, transactions, affected rows, and precise timings
- [x] Transactional optimistic INSERT/UPDATE/paste paths with preview, rollback, and audit records
- [x] PostgreSQL and managed-copy SQLite adapters with explicit capability gating
- [x] Server-bound filters, sorts, grouping/aggregates, persisted layouts, range copy/paste, and import/export limits
- [x] Vision Pro database-workspace 0–100% opacity and continuous blur controls; system materials elsewhere
- [x] visionOS 26.0 minimum and arm64-only app/test target settings
- [x] Coordinated GlasSecretStore hardening published and merged as PR #2 (`b21c137`)

### Completed — Native macOS 27+
- [x] Native SwiftUI macOS application shell integrated into the existing target; this is not Catalyst
- [x] Platform-native Mac scenes, commands, Settings scene, window behavior, editor/grid interactions, and Keychain handling
- [x] Dedicated macOS Info.plist, entitlements, and Mac application icon assets
- [x] macOS application and tests require macOS 27.0; the shipping Mac executable is arm64-only and Intel remains excluded
- [x] Vision Pro database workspace retains the 0–100% opacity and continuous blur controls; general application windows continue to use Apple-recommended materials
- [x] Native Mac form/input UX audit completed: tabbed grouped Settings, bounded steppers/sliders, inline validation and input gates, keyboard actions, adaptive editor/grid controls, and a 300-point minimum / 340-point default connection sidebar

### Completed — Final Automated QA
- [x] Native macOS 27 arm64 application suite passed 60/60, including finite/stable native Settings layout coverage
- [x] visionOS 26.4 arm64 simulator application suite passed 59/59; the prior visionOS 26.5 minimum-runtime checkpoint passed 44/44
- [x] Both final app result bundles report zero errors, build/analyzer/runtime warnings, skips, and expected failures; final diff whitespace validation is clean
- [x] Native macOS Release archive verified as arm64 with macOS 27.0 minimum and `macosx`/`MacOSX` platform metadata
- [x] Native Settings crash regression passed ten fresh Debug launches plus the exact Release archive with Settings auto-opened; no new `.ips` or AppKit constraint-loop signature
- [x] GlassDBKit passed 24/24 package tests plus the existing 2/2 live MySQL/PostgreSQL integrations; the added passwordless `caching_sha2_password` GlassDBKit harness also completed against MySQL 9.7.1
- [x] Citadel passed 31 executed tests with 5 environment-gated skips and 0 failures; swift-nio-ssh passed 320/320; GlasSecretStore passed 68/68
- [x] Transport pending buffers are bounded; Citadel payload/SFTP/invalid-state paths use typed failure handling rather than process traps

### In Progress
- [ ] C3 cross-device Glass-family credential catalog and eligible-secret synchronization; shared access group/App Group behavior is currently same-device only
- [ ] External distribution provisioning/signing and physical-device acceptance for Vision Pro and Mac, including device-only Keychain, user-presence, Secure Enclave, and supported Foundation Models behavior
- [ ] Final residual-risk review and release documentation reconciliation

### Blocked
- No implementation or automated-test blocker
- Distribution signing/provisioning and device-only acceptance depend on external Apple account/profile and physical-device availability

### Release Approval Required
- [ ] Review the final residual-risk register, known capability limits, and external/device-gate evidence
- [ ] Explicitly approve any TestFlight submission

### Future Platform/Product Releases
- [ ] Native iPad application target and a focused iOS experience; native macOS is complete in `codex-completions`
- [ ] View support in sidebar
- [ ] Table creation GUI
- [ ] Stored procedure/function viewer

### Longer-Term
- [ ] ER diagram visualization
- [ ] Explain plan visualization
- [ ] Schema comparison
- [ ] Spatial multi-window pinning
