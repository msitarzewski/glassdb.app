# Active Context

## Current Phase
Pre-beta. 24 Swift source files in main target, 4 in GlassDBKit package, 11 in GlasSecretStore shared package. Targeting visionOS 26.0+ with Swift 6.2 strict concurrency. M0-M3 complete, M4 (ship-ready) in final stretch.

## Current Focus
M4 final items: glass settings, query history, then TestFlight. SQL autocomplete builds in parallel with TestFlight feedback.

## Recent Changes

### Round 5 (2026-03-15) — visionOS 26 SDK Migration (PR #1, merged)
- **Liquid Glass**: replaced manual `.ornament()` + `.glassBackgroundEffect()` with `.toolbar { ToolbarItemGroup(placement: .bottomOrnament) }` for system Liquid Glass treatment
- **Window lifecycle**: added `.defaultLaunchBehavior`/`.restorationBehavior` to all scenes, converted Settings to singleton `Window`, deleted `WindowRecoveryManager.swift`
- **Stale session guards**: added `ContentUnavailableView` fallback in QueryEditorView and SchemaBrowserView
- **Accessibility**: grid header traits, data cell labels with column names, connection status indicator labels, form enhancement labels, Look to Scroll on all scrollables
- **Removed double-corner artifact**: removed `.background(.ultraThinMaterial, cornerRadius: 24)` from all content windows — `.windowStyle(.plain)` handles window chrome
- **Removed deprecated settings**: `interactiveGlassEffects` removed from SettingsManager, Constants, SettingsView
- **Alternating row colors**: fixed to use `Color.primary.opacity` for adaptive theming
- **Deployment target**: raised to visionOS 26.0

### Round 6-8 (2026-03-15/16) — v1.0 Database Manager (commit f408fd9)

**Architecture overhaul:**
- Replaced separate query editor + schema browser + results windows with unified `DatabaseWorkspaceView`
- `WorkspaceSelection` enum (`.database`, `.table`, `.query`) drives context-sensitive detail surface
- Schema browser integrated as NavigationSplitView sidebar with filter field and context menus
- DBeaver-style interaction model: click database → properties view, click table → data/structure/DDL tabs

**New views (7 files created):**
- `DatabaseWorkspaceView.swift` — NavigationSplitView wrapper, selection routing, sidebar toggle
- `TableDetailView.swift` — 5-tab TabView (Data, Structure, DDL, Indexes, Foreign Keys) with sub-views
- `DatabaseDetailView.swift` — database properties, table stats, active database selector
- `RecordEditorView.swift` — sheet modal for row editing with staging model
- `SQLHighlighter.swift` — full SQL tokenizer + NSAttributedString syntax highlighting
- `HighlightedTextEditor.swift` — UIViewRepresentable wrapping UITextView for highlighted editing
- `DataExporter.swift` — CSV export document

**Query engine fixes:**
- Utility commands (USE, SET, SHOW, DDL) routed through `simpleQuery` (COM_QUERY) instead of prepared statements (COM_STMT_PREPARE) — fixes MySQL protocol error
- Session tracks `currentDatabase` after USE statements
- Column metadata loaded separately for PK detection in record editor

**Protocol extensions (GlassDBKit):**
- 5 new `DatabaseConnection` methods: `showCreateTable`, `indexes`, `foreignKeys`, `tableStatus`, `rowCount`
- 3 new models: `IndexInfo`, `ForeignKeyInfo`, `TableStatus`
- `DatabaseError` enum for protocol-level errors

**Data grid improvements:**
- `LazyVStack(pinnedViews: .sectionHeaders)` for sticky column headers
- `GeometryReader`-based column width calculation sized to content
- Empty filler columns/rows extending to container edges (DBeaver/spreadsheet style)
- Frozen row numbers pinned during horizontal scroll
- Row selection highlighting with tap-to-edit

**Sidebar enhancements:**
- Context menus on databases (Set Active, SQL Editor, Refresh) and tables (Browse Data, Copy Name, Copy SELECT, Truncate, Drop)
- Row count badges (lazy-loaded)
- Filter/search field
- Title changed from "Schema" to "Databases"

**Record editor (staging model):**
- Sheet modal with NavigationStack + Form
- Type-specific editors: text, JSON (format/validate), booleans, dates, numbers
- NULL shown as placeholder — type to replace, "Set to NULL" button to revert
- Modified fields flagged with orange indicator
- Batch apply generates UPDATE ... WHERE pk = ... LIMIT 1
- `.keyboardType(.asciiCapable)` to prevent smart quotes in data fields

**Platform findings:**
- `.inspector()` explicitly `@available(visionOS, unavailable)` — used `.sheet()` instead
- `.navigationSubtitle()` unavailable on visionOS — combined into title string
- `.smartQuotesDisabled()` unavailable on visionOS — used `.keyboardType(.asciiCapable)`

### Round 9 (2026-03-16) — M4 Polish Round 1 (commit 9e9b66b)

**Split editor+results layout:**
- SQL editor (top) + results grid (bottom) in Data tab — DBeaver/SQL Pro Studio pattern
- Dark background on editor area for visual separation
- Draggable resize handle between editor and results panes

**Query execution improvements:**
- Inline Execute button with Cmd+Return keyboard shortcut
- Auto-repeat: context menu on Execute with interval picker (5s/10s/30s/60s)

**Pagination:**
- Page navigation bar with previous/next controls
- Rows-per-page input field
- Total row count display
- LIMIT/OFFSET injection into queries
- Row numbers continue across pages (not reset per page)

**Record editor — Add Row mode:**
- Add Row mode with INSERT SQL generation (alongside existing UPDATE mode)

**Settings:**
- `dataGridFontSize` setting (default 13.0) for data grid font customization

**Toolbar architecture:**
- Moved toolbar to bottom ornament — TabView was swallowing child toolbar items on visionOS
- NotificationCenter-based communication from parent toolbar to child tab views

**AI Assistant:**
- Foundation Models integration (`#if canImport(FoundationModels)`)
- Schema-aware SQL generation (same pattern as glas.sh AIAssistant)
- Error explanation and query summary features
- AI sparkle button entry point in workspace ornament

### Round 10 (2026-03-16) — M4 Polish Round 3 (commit 8f56c06)

- Removed duplicate row stats display
- Execute button moved to header (play icon only, compact)
- Multi-query support: split SQL on semicolons, execute sequentially
- Pager syncs with query LIMIT clause (`isAutoQuery` flag prevents double-limiting)
- Brighter syntax highlighting colors optimized for dark editor background
- Settings gear icon added to workspace ornament
- AI sparkle button entry point refined

## Next Steps (M4 Ship-Ready)
1. Glass/transparency/color settings (port from glas.sh — resolvedMaterial, tint color, opacity controls)
2. Query history persistence (SavedQuery model exists in SettingsManager, needs disk storage + UI)
3. Submit TestFlight build — what we have is already more functional than anything on visionOS
4. SQL autocomplete (tables, columns, keywords) — build while TestFlight feedback comes in, ship in App Store v1.0
