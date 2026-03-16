# System Patterns

## Workspace Architecture (DBeaver-style, as of 2026-03-16)
- Unified `DatabaseWorkspaceView` with NavigationSplitView: sidebar + context-sensitive detail.
- `WorkspaceSelection` enum drives the detail surface:
  - `.query` → `QueryEditorView` (SQL editor + inline results)
  - `.database(name)` → `DatabaseDetailView` (properties, table stats)
  - `.table(db, table)` → `TableDetailView` (5-tab TabView: Data, Structure, DDL, Indexes, FK)
- Schema browser integrated as sidebar (was separate window).
- Sidebar toggle button at `.topBarLeading`.
- Connection manager remains the primary window (`WindowGroup("Connections", id: "main")`).
- Results grid remains detachable to separate spatial window.
- Settings is a singleton `Window` (not WindowGroup).

## Window Scenes (glassdbApp.swift)
- `main` — ConnectionManagerView, `.defaultLaunchBehavior(.presented)`
- `query-editor` — DatabaseWorkspaceView (keyed by session UUID), `.restorationBehavior(.disabled)`
- `results` — ResultsGridView (keyed by result set UUID), detachable
- `settings` — SettingsView, singleton Window

## Data Grid Pattern
- `LazyVStack(alignment: .leading, pinnedViews: .sectionHeaders)` for sticky column headers.
- `GeometryReader` to measure available width, compute content-based column widths.
- Empty filler columns on right + filler rows on bottom (DBeaver/spreadsheet style).
- Frozen row numbers in separate VStack outside horizontal ScrollView.
- Row selection via `.onTapGesture` with accent color highlight.
- Alternating row stripes using `Color.primary.opacity(0.02)`.

## Record Editor Pattern
- `.sheet()` modal with NavigationStack + List + Sections.
- Staging model: edits tracked in `[StagedEdit]`, applied as batch UPDATE.
- Type-specific editors: text (TextField), JSON (TextEditor + format/validate), booleans (Toggle), dates, numbers.
- NULL shown as TextField placeholder — typing clears NULL automatically.
- PK detection via separate `connection.columns()` metadata query (not from SELECT result columns).

## SQL Highlighting Pattern
- `SQLHighlighter.tokenize()` produces `[SQLToken]` with kind + range.
- `SQLHighlighter.highlight()` produces `NSAttributedString` with colors per token type.
- `HighlightedTextEditor` wraps `UITextView` via `UIViewRepresentable`, re-highlights on every keystroke, preserves cursor.

## Query Execution Flow
- User writes SQL in QueryEditorView or clicks table in sidebar.
- `DatabaseSessionManager.executeQuery()` delegates to `connection.execute()`.
- `MySQLAdapter.execute()` routes utility commands (USE, SET, SHOW, DDL) through `simpleQuery` (COM_QUERY) and data queries through `query` (COM_STMT_PREPARE).
- USE statements update `session.currentDatabase`.
- Results stored in `session.queryHistory`, displayed inline or detachable.

## Database Connection Flow
- SSH tunnel (optional) established first via Citadel.
- MySQL connection via mysql-nio through tunnel or direct.
- Connection state tracked in `DatabaseSession` (@Observable).
- Passwords stored in Keychain via GlasSecretStore, connection configs in UserDefaults.
- SSH key auth: Ed25519 + RSA + Secure Enclave P256.

## Glass Material Pattern (visionOS 26)
- All windows use `.windowStyle(.plain)` — system handles glass chrome and corners.
- NO manual `.ultraThinMaterial` backgrounds on content windows (causes double-corner artifact).
- Ornaments via `.toolbar { ToolbarItemGroup(placement: .bottomOrnament) }` — auto Liquid Glass.
- NavigationSplitView sidebar auto-gets Liquid Glass floating treatment.
- Sheets get automatic glass backgrounds.

## Platform Constraints (visionOS)
- `.inspector()` — explicitly `@available(visionOS, unavailable)`. Use `.sheet()` instead.
- `.navigationSubtitle()` — unavailable. Combine into title string.
- `.smartQuotesDisabled()` — unavailable. Use `.keyboardType(.asciiCapable)`.
- `.buttonStyle(.glassProminent)` — unavailable. Use `.borderedProminent`.

## Repo Layout
- Runtime app code in `glassdb/` (23 Swift files).
- Shared package code in `Packages/GlassDBKit/` (DB protocol, adapters, models).
- Vendored SSH packages in `Packages/Citadel/` and `Packages/swift-nio-ssh/`.
- Shared Keychain package at `../GlasSecretStore/` (local path dependency).
