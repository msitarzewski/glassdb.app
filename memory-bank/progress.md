# Progress

## Status: Native iPhone/iPad/macOS/visionOS Automated Release Candidate Complete; External Release Gates Open

### Completed — Platforms Plus Plus
- [x] One shared native SwiftUI application target builds arm64 iPhone, iPad, Mac, and Vision Pro products; iOS/iPadOS and visionOS require 26.0+, macOS requires 27.0+, and Catalyst/Intel remain excluded
- [x] iPhone uses compact `NavigationStack`/native lists and record summaries; iPad retains adaptive `NavigationSplitView`, multiple workspace windows, native forms/toolbars, and the documented regular-width professional-grid exception
- [x] Connection forms use explicit Test and Save & Connect actions; field submission only advances or dismisses focus and cannot initiate a connection
- [x] GlasSecretStore owns canonical UUID credential accounts; explicitly shared SSH passwords atomically publish both glassdb and glas.sh-compatible records with rollback on partial failure
- [x] Lifecycle recovery validates foreground transports, intercepts known-disconnected requests, preserves workspace/session history on explicit reconnect, and avoids premature shared-session closure across windows
- [x] Full application suite passed 101/101 on macOS 27, iPhone 17 Pro iOS 27, iPad Pro 13-inch iOS 27, Vision Pro visionOS 26.5, and Vision Pro visionOS 27
- [x] Generic unsigned iOS and visionOS device builds passed; produced Mac/iOS/visionOS executables are arm64-only and generated iOS metadata declares minimum 26.0, families 1/2, all orientations, icon, and local-network purpose
- [x] GlasSecretStore passed 69 tests/13 suites, GlassDBKit passed 25 tests/3 suites, and Citadel passed 31 tests with only explicitly environment-gated live SSH/server cases skipped
- [x] OSV-discovered swift-nio 2.96.0 advisories repaired by locking 2.100.0; post-fix OSV scan reports no issues, Xcode Analyze succeeds, and post-fix Mac/iPhone/Vision application regressions pass
- [x] Final authored-code scan found no in-scope TODO/FIXME/stub/fatalError/preconditionFailure/empty-catch implementation; vendored upstream markers are classified in the release tracker

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
- [x] Searchable staged Columns manager with visible/frozen switches, bulk show/hide/unfreeze, reset, and persisted per-table layout
- [x] Native Mac row-number selection: plain, Shift range, Command toggle, Command-Shift range union, and double-click edit
- [x] Selected-row Copy, Compare, and CSV/TSV/JSON/SQL export use one shared ordered selection model
- [x] Typed Filter Rows sheet with bound server-query mode by default and an explicit loaded-page-only Display Only mode
- [x] Pinned adaptive column headers and row-number gutter remain legible while scrolling across transparent/blurred database canvases

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
- [x] Native macOS 27 arm64 application suite passed 84/84, including finite/stable native Settings layout, JSON round-trip, workspace, schema tooling, filtering, and Mac row-selection coverage
- [x] visionOS 26.4 arm64 simulator application suite passed 59/59; the prior visionOS 26.5 minimum-runtime checkpoint passed 44/44
- [x] Both final app result bundles report zero errors, build/analyzer/runtime warnings, skips, and expected failures; final diff whitespace validation is clean
- [x] Native macOS Release archive verified as arm64 with macOS 27.0 minimum and `macosx`/`MacOSX` platform metadata
- [x] Native Settings crash regression passed ten fresh Debug launches plus the exact Release archive with Settings auto-opened; no new `.ips` or AppKit constraint-loop signature
- [x] GlassDBKit aggregate coverage is 25/25: the current local run passed all 22 non-live tests, while the three environment-gated MySQL 8, PostgreSQL 17, and passwordless MySQL 9.7.1 tests retain their recorded live passes
- [x] Citadel passed 31 executed tests with 5 environment-gated skips and 0 failures; swift-nio-ssh passed 320/320; GlasSecretStore passed 68/68
- [x] Transport pending buffers are bounded; Citadel payload/SFTP/invalid-state paths use typed failure handling rather than process traps
- [x] Latest development-signed macOS arm64 bundle and generic visionOS simulator arm64 build passed; strict Mac signature verification succeeded

### In Progress
- [ ] C3 cross-device Glass-family credential catalog and eligible-secret synchronization; shared access group/App Group behavior is currently same-device only
- [ ] Magic / First Class **My Connections** contract: neutral endpoint identity,
  glassdb database/tunnel overlay, outcome-oriented onboarding, and canonical
  glas.sh/iPhone -> glassdb/Vision Pro tunnel acceptance; approved direction,
  implementation not started
- [ ] External distribution provisioning/signing and physical-device acceptance for Vision Pro and Mac, including device-only Keychain, user-presence, Secure Enclave, and supported Foundation Models behavior
- [ ] Physical iPhone/iPad acceptance, signed glassdb/glas.sh cross-app Keychain read, live database/TLS/SSH/Tailscale failure matrix, accessibility/input review, Instruments, and iOS 26 runtime fallback validation for `platforms-plus-plus`
- [ ] Final residual-risk review and release documentation reconciliation

### Blocked
- No implementation or automated-test blocker
- Distribution signing/provisioning and device-only acceptance depend on external Apple account/profile and physical-device availability

### Release Approval Required
- [ ] Review the final residual-risk register, known capability limits, and external/device-gate evidence
- [ ] Explicitly approve any TestFlight submission

### Future Platform/Product Releases
- [ ] View support in sidebar
- [ ] Table creation GUI
- [ ] Stored procedure/function viewer

### Longer-Term
- [ ] ER diagram visualization
- [ ] Explain plan visualization
- [ ] Schema comparison
- [ ] Spatial multi-window pinning
