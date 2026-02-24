# M1: End-to-End Flow

**Status**: Not Started
**Depends on**: M0 (clean build)
**Prerequisite for**: M2

## Goal
A user can select a saved connection, connect to a live MySQL server (directly or via SSH tunnel), type a SQL query, execute it, and see results. This is the "it actually works" milestone.

## Tasks

### Connect Flow
- [ ] ConnectionManagerView "Connect" button → calls `DatabaseSessionManager.connect()`
- [ ] Show connection progress (ConnectionStage enum: resolving, SSH tunnel, authenticating, selecting DB)
- [ ] On success → open Query Editor window via `openWindow(id: "query-editor", value: sessionID)`
- [ ] On failure → display error in ConnectionManagerView with retry option
- [ ] Password prompt (from Keychain or user input) before connect

### Query Execution
- [ ] QueryEditorView "Execute" button → calls `DatabaseSessionManager.executeQuery()`
- [ ] Display results inline in QueryEditorView OR detach to ResultsGridView window
- [ ] Show execution time, row count, column count in status bar
- [ ] Handle query errors gracefully (display in editor, not crash)

### Results Display
- [ ] ResultsGridView renders `QueryResult.columns` as headers, `QueryResult.rows` as data
- [ ] Scrollable grid (horizontal + vertical) for wide/long result sets
- [ ] NULL values visually distinct
- [ ] Detach results into standalone spatial window

### Schema Browser
- [ ] SchemaBrowserView calls `connection.databases()` on connect
- [ ] Expand database → calls `connection.tables(in:)`
- [ ] Expand table → calls `connection.columns(in:database:)`
- [ ] Tapping a table name inserts `SELECT * FROM \`table\`` into query editor

### Session Lifecycle
- [ ] Disconnect button in Query Editor ornament
- [ ] Clean up session + tunnel on disconnect
- [ ] Handle unexpected disconnection (network drop, server restart)

## Key Files
- `glassdb/ConnectionManagerView.swift`
- `glassdb/QueryEditorView.swift`
- `glassdb/ResultsGridView.swift`
- `glassdb/SchemaBrowserView.swift`
- `glassdb/DatabaseSessionManager.swift`
- `Packages/GlassDBKit/Sources/GlassDBKit/MySQLAdapter.swift`
