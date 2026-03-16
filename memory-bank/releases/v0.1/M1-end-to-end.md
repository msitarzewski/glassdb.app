# M1: End-to-End Flow

**Status**: Done (2026-03-15)
**Depends on**: M0 (clean build)
**Prerequisite for**: M2

## Goal
A user can select a saved connection, connect to a live MySQL server (directly or via SSH tunnel), type a SQL query, execute it, and see results.

## Tasks

### Connect Flow
- [x] ConnectionManagerView "Connect" button → calls `DatabaseSessionManager.connect()`
- [x] Show connection progress (ConnectionStage enum: resolving, SSH tunnel, authenticating, selecting DB)
- [x] On success → open workspace window via `openWindow(id: "query-editor", value: sessionID)`
- [x] On failure → display error in ConnectionManagerView with retry option
- [x] Password prompt (from Keychain or user input) before connect

### Query Execution
- [x] QueryEditorView "Execute" button → calls `DatabaseSessionManager.executeQuery()`
- [x] Display results inline in QueryEditorView
- [x] Show execution time, row count in status bar
- [x] Handle query errors gracefully (display inline, not crash)
- [x] Utility commands (USE, SET, SHOW) routed through simpleQuery

### Results Display
- [x] Results grid renders columns as headers, rows as data
- [x] Scrollable grid (horizontal + vertical) with lazy loading
- [x] NULL values visually distinct (tertiary color)
- [x] Detach results into standalone spatial window
- [x] Content-width columns with filler cells (DBeaver style)
- [x] Frozen row numbers

### Schema Browser
- [x] SchemaBrowserView loads databases on connect
- [x] Expand database → loads tables
- [x] Expand table → loads columns
- [x] Click table name → shows TableDetailView (Data tab)
- [x] Click database name → shows DatabaseDetailView
- [x] Context menus on databases and tables
- [x] Row count badges
- [x] Filter field

### Session Lifecycle
- [x] Disconnect button in connection manager
- [x] Clean up session + tunnel on disconnect
- [x] Stale session guards (ContentUnavailableView)

## Key Files
- `glassdb/DatabaseWorkspaceView.swift`
- `glassdb/ConnectionManagerView.swift`
- `glassdb/QueryEditorView.swift`
- `glassdb/ResultsGridView.swift`
- `glassdb/SchemaBrowserView.swift`
- `glassdb/TableDetailView.swift`
- `glassdb/DatabaseDetailView.swift`
- `glassdb/DatabaseSessionManager.swift`
- `Packages/GlassDBKit/Sources/GlassDBKit/MySQLAdapter.swift`
