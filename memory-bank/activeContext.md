# Active Context

## Current Phase
Late alpha / pre-beta. 23 Swift source files in main target, 4 in GlassDBKit package, 11 in GlasSecretStore shared package. Targeting visionOS 26.0+ with Swift 6.2 strict concurrency. Two major milestones completed since last update.

## Current Focus
M4 polish — bug fixes, scroll sync, remaining rough edges before TestFlight. The `fixes` branch has the complete v1.0 database manager and needs a PR to main.

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

### Round 6-8 (2026-03-15/16) — v1.0 Database Manager (commit f408fd9 on fixes branch)

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

## Next Steps
1. PR `fixes` branch to main
2. SQL autocomplete (table names, column names, keywords)
3. Query history persistence (survives app restart)
4. Data grid vertical scroll sync between row numbers and data columns
5. Polish pass: loading states, error recovery, empty states
6. TestFlight submission
