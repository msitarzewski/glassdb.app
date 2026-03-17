# Progress

## Status: Late Alpha (Pre-Beta)

### Completed — Infrastructure
- [x] Market research — confirmed zero native visionOS DB clients exist
- [x] Architecture planning — PROJECT_SCAFFOLD.md
- [x] glas.sh pattern analysis — reuse mapping documented
- [x] AGENTS.md adapted for glassdb.app
- [x] Memory bank initialized
- [x] Domain identified: glassdb.app (available)
- [x] Xcode project initialized targeting visionOS 26.0+
- [x] Vendored Citadel + swift-nio-ssh packages from glas.sh
- [x] GlassDBKit package created with mysql-nio dependency
- [x] GitHub repo created, initial commit pushed

### Completed — Core Engine
- [x] DatabaseProtocol abstraction (`DatabaseEngine`, `DatabaseConnection` protocols)
- [x] MySQLAdapter — full mysql-nio wrapper (connect, execute, schema introspection)
- [x] QueryResult + ColumnInfo + DatabaseValue models in GlassDBKit
- [x] SSHTunnelManager — full SSH tunnel via Citadel with DirectTCPIP forwarding
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
- [x] SSH key auth — Ed25519 + RSA + Secure Enclave P256 import/manage/connect
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
- [x] TableDetailView — 5-tab TabView (Data, Structure, DDL, Indexes, Foreign Keys)
- [x] Data tab — auto-loads rows, frozen row numbers, content-width columns, filler cells
- [x] Structure tab — column definitions from INFORMATION_SCHEMA
- [x] DDL tab — SHOW CREATE TABLE with syntax highlighting + copy button
- [x] Indexes tab — SHOW INDEX results
- [x] Foreign Keys tab — KEY_COLUMN_USAGE query
- [x] DatabaseDetailView — properties, table count/rows/size stats, Set Active action
- [x] Context menus on databases and tables (Browse, Copy, Truncate, Drop)
- [x] Row count badges in sidebar (lazy-loaded)
- [x] Filter/search field in sidebar
- [x] CSV export document (DataExporter)

### Completed — Record Editor
- [x] RecordEditorView — sheet modal with staging model
- [x] Type-specific editors: text, JSON (format/validate), booleans, dates, numbers
- [x] NULL as placeholder text — type to replace
- [x] Modified field indicators
- [x] Batch UPDATE with PK-based WHERE clause
- [x] Column metadata loaded for PK detection
- [x] Add Row mode with INSERT SQL generation

### Completed — SQL Tooling
- [x] SQLHighlighter — full tokenizer (keywords, functions, strings, numbers, comments, identifiers)
- [x] HighlightedTextEditor — UIViewRepresentable with UITextView, cursor preservation
- [x] Basic linter (unterminated strings/identifiers)
- [x] Cmd+Return keyboard shortcut for execute
- [x] Multi-query support — split on semicolons, execute sequentially
- [x] Brighter syntax highlighting colors for dark editor background

### Completed — visionOS 26 Migration (PR #1)
- [x] Deployment target raised to visionOS 26.0
- [x] Liquid Glass ornaments via .toolbar(.bottomOrnament)
- [x] Window lifecycle: defaultLaunchBehavior, restorationBehavior
- [x] Settings converted to singleton Window
- [x] WindowRecoveryManager deleted
- [x] Stale session guards (ContentUnavailableView)
- [x] Accessibility: grid headers, data cells, status indicators, form labels
- [x] Look to Scroll on all scrollable views
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
- [x] Auto-repeat: context menu on Execute with interval picker (5s/10s/30s/60s)
- [x] Execute button in header (play icon)

### Completed — Toolbar & Navigation
- [x] Toolbar moved to bottom ornament (TabView swallows child toolbars on visionOS)
- [x] NotificationCenter for toolbar-to-tab communication
- [x] Settings gear in workspace ornament
- [x] AI sparkle button entry point in workspace ornament

### Completed — AI Assistant
- [x] AIAssistant.swift — Foundation Models integration (`#if canImport(FoundationModels)`)
- [x] Schema-aware SQL generation (same pattern as glas.sh)
- [x] Error explanation and query summary features

### In Progress
- [ ] Polish pass — loading states, error recovery, empty states

### Blocked
- Nothing currently blocked

### Not Yet Started (v1.0 remaining)
- [ ] SQL autocomplete (table names, column names, keywords)
- [ ] Query history persistence (survives app restart)
- [ ] TestFlight submission

### Not Yet Started (v1.1)
- [ ] iPad + Mac targets (View modifier extensions, no #if os in views)
- [ ] iCloud Keychain integration (Face ID connection auth)
- [ ] Inline data editing in grid (TablePlus-style staging)
- [ ] Multiple query tabs
- [ ] JSON/SQL export formats
- [ ] View support in sidebar
- [ ] Table creation GUI
- [ ] Stored procedure/function viewer

### Not Yet Started (v2.0)
- [ ] PostgreSQL engine
- [ ] Data import (CSV, JSON, SQL)
- [ ] ER diagram visualization
- [ ] Explain plan visualization
- [ ] Schema comparison
- [ ] Spatial multi-window pinning
