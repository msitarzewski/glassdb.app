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

## Split Editor+Results Pattern (DataTabView)
- SQL editor (top) + results grid (bottom) in Data tab, DBeaver/SQL Pro Studio layout.
- Draggable resize handle between editor and results panes.
- Dark background on editor area for visual contrast.
- Editor is always visible above results — not a separate mode to switch to.

## Pagination Pattern
- Page navigation bar with previous/next controls in toolbar.
- Rows-per-page input field, total row count display.
- LIMIT/OFFSET injected into queries automatically.
- `isAutoQuery` flag: when query already contains LIMIT (e.g., sidebar "Browse Data"), pager syncs with it instead of double-limiting.
- Row numbers continue across pages (offset-based, not reset per page).

## Multi-Query Execution
- SQL-aware tokenization preserves semicolons in strings, comments, identifiers, and compound routine bodies.
- Statements execute sequentially and stop on failure; the latest result is displayed and every execution is recorded in history.
- Empty statements (trailing semicolons) filtered out.

## Auto-Repeat Pattern
- Context menu on the table-data Execute button offers a fixed “Run every 10s” action.
- A cancellable task repeats the current table query at that interval.
- Stopped on manual execute, disconnect, or view disappear.

## Toolbar-to-Tab Communication (NotificationCenter)
- TabView on visionOS swallows child view `.toolbar` items — they never appear.
- Solution: parent `DatabaseWorkspaceView` owns the bottom ornament toolbar.
- Toolbar buttons post `NotificationCenter` notifications (e.g., `.executeQuery`, `.addRow`).
- Child tab views receive via `.onReceive(NotificationCenter.default.publisher(for:))`.
- Settings gear and AI sparkle button also live in workspace ornament.

## AI Assistant Pattern
- `AIAssistant.swift` weak-links Foundation Models and runtime-gates generation to visionOS 27+ so visionOS 26 can launch safely.
- Same architectural pattern as glas.sh AIAssistant.
- The current UI supplies privacy-bounded metadata for the selected table; row samples are opt-in at the model layer.
- Generated SQL enters the editor and is classified by deterministic app policy before execution.
- Error-explanation and query-summary methods exist but are not yet surfaced in the product UI.
- Entry point: AI sparkle button in workspace ornament.

## Query Execution Flow
- User writes SQL in QueryEditorView or clicks table in sidebar.
- `DatabaseSessionManager.executeQuery()` delegates to `connection.execute()`.
- `MySQLAdapter.execute()` routes utility commands (USE, SET, SHOW, DDL) through `simpleQuery` (COM_QUERY) and data queries through `query` (COM_STMT_PREPARE).
- USE statements update `session.currentDatabase`.
- Results are displayed inline or detachable; durable history persists independently of session lifetime.

## Database Connection Flow
- SSH tunnel (optional) established first via Citadel.
- MySQL/PostgreSQL connect through their NIO adapters; SQLite opens a managed private copy.
- Connection state tracked in `DatabaseSession` (@Observable).
- Passwords stored in Keychain via GlasSecretStore, connection configs in UserDefaults. The shared access group/App Group is a same-device bridge; eligible-secret cross-device sync and its stable family catalog remain C3 work.
- SSH key auth: Ed25519, RSA, and Secure Enclave-wrapped P256 material.

## Glass Material Pattern (visionOS 26)
- Only the `query-editor` database workspace uses `.windowStyle(.plain)` and user-controlled 0...1 opacity/blur.
- Connections, Settings, detached results, alerts, and sheets keep system-provided materials.
- Ornaments via `.toolbar { ToolbarItemGroup(placement: .bottomOrnament) }` — auto Liquid Glass.
- NavigationSplitView sidebar auto-gets Liquid Glass floating treatment.
- Sheets get automatic glass backgrounds.

## Platform Constraints (visionOS)
- `.inspector()` — explicitly `@available(visionOS, unavailable)`. Use `.sheet()` instead.
- `.navigationSubtitle()` — unavailable. Combine into title string.
- `.smartQuotesDisabled()` — unavailable. Use `.keyboardType(.asciiCapable)`.
- `.buttonStyle(.glassProminent)` — unavailable. Use `.borderedProminent`.

## Repo Layout
- Runtime app code in `glassdb/` (22 top-level Swift files at this release snapshot).
- Shared package code in `Packages/GlassDBKit/` (DB protocol, adapters, models).
- Vendored SSH packages in `Packages/Citadel/` and `Packages/swift-nio-ssh/`.
- Shared Keychain package at `../GlasSecretStore/` (local path dependency).
