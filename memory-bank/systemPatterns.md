# System Patterns

## Window Architecture
- Multi-window app model with database-focused windows.
- Connection manager as primary singleton window.
- Query editor windows openable per-connection (WindowGroup keyed by session UUID).
- Results grid windows detachable from editor (WindowGroup keyed by result set UUID).
- Schema browser as singleton window.
- Settings as singleton window.

## Glass Material Pattern
- All windows use `.windowStyle(.plain)` for glass-first appearance.
- Content areas use `.background(.ultraThinMaterial, in: .rect(cornerRadius: 24))`.
- Ornament-based chrome for contextual controls.

## Database Connection Flow
- SSH tunnel (optional) established first via Citadel.
- MySQL connection via mysql-nio through tunnel or direct.
- Connection state tracked in DatabaseSession (@Observable).
- Passwords stored in Keychain, connection configs in JSON/UserDefaults.

## Query Execution Flow
- User writes SQL in QueryEditorView.
- Execute sends query through DatabaseSession.
- Results returned as QueryResult model.
- Results can be viewed inline or detached to separate spatial window.

## UI Structure (adapted from glas.sh)
- Connection manager: NavigationSplitView with sidebar sections + detail grid.
- Query editor: Main content area with SQL editor + ornament-based toolbar.
- Results grid: Scrollable data grid with column headers, sortable.
- Schema browser: Tree/outline view (database → table → column).

## Repo Layout Pattern
- Runtime app code in `glassdb/`.
- Shared package code in `Packages/GlassDBKit/` (DB protocol, adapters).
- Vendored SSH packages in `Packages/Citadel/` and `Packages/swift-nio-ssh/`.
