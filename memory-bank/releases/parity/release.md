# Parity Release — Full Market Competitive Feature Set

**Goal**: Feature parity with DBeaver CE / TablePlus / DataGrip across all platforms
**Platforms**: visionOS 26+, iPadOS, macOS (iOS stretch)
**Engines**: MySQL + PostgreSQL (+ SQLite stretch)
**Baseline**: [competitive-analysis.md](../../competitive-analysis.md)

---

## Release Structure

| Release | Theme | Status |
|---------|-------|--------|
| **v0.1** | MVP — MySQL on visionOS | M4 in-progress |
| **P1** | Core Parity — the features users expect | Not started |
| **P2** | Power User — the features that drive retention | Not started |
| **P3** | Multi-Engine + Multiplatform | Not started |
| **P4** | Advanced — the features that differentiate | Not started |

---

## P1: Core Parity (every database client has these)

*"If it's missing, users won't take the app seriously."*

### P1.1 — SQL Autocomplete
The #1 retention feature across all competitors. Users will abandon glassdb without it.
- [ ] Keyword completion (SELECT, FROM, WHERE, JOIN, etc.)
- [ ] Table name completion (from current database schema cache)
- [ ] Column name completion (context-aware — after SELECT, WHERE, ON, etc.)
- [ ] Database name completion (after USE, FROM db.)
- [ ] Alias-aware completion (after defining `t` as alias for `table`, complete `t.column`)
- [ ] Popup suggestion list with Tab/Enter to accept
- [ ] Schema cache that refreshes on database switch or manual refresh

### P1.2 — Query History (Persisted)
Every competitor has this. Users expect to find yesterday's query.
- [ ] Persist executed queries to disk (SQL text, timestamp, execution time, row count, error, database, connection)
- [ ] QueryHistoryView — searchable/filterable list
- [ ] Tap history entry → load into editor
- [ ] Per-connection and per-database filtering
- [ ] Clear history (single entry or all)
- [ ] History limit setting (already exists in SettingsManager)

### P1.3 — Multiple Query Tabs
DBeaver, TablePlus, DataGrip all support this.
- [ ] Tab bar in query editor area (or TabView)
- [ ] New tab button (Cmd+T)
- [ ] Close tab (Cmd+W)
- [ ] Each tab has independent query text, results, execution state
- [ ] Tab title shows first line of query or "Untitled"
- [ ] Tabs persist within session (not across app restarts for v1)

### P1.4 — Inline Data Editing (TablePlus Staging Model)
The upgrade from the current sheet-based editor.
- [ ] Click cell → inline edit mode (TextField appears in cell)
- [ ] Tab to move between cells
- [ ] Modified cells highlighted (orange/yellow background)
- [ ] New row insertion (+ button at bottom)
- [ ] Row deletion (context menu or Delete key)
- [ ] Staged changes panel showing pending INSERT/UPDATE/DELETE
- [ ] Apply All / Discard All buttons
- [ ] Undo individual changes before apply
- [ ] Generate SQL preview of pending changes

### P1.5 — Data Filtering & Sorting
Every competitor has column-level filtering.
- [ ] Click column header to sort ASC/DESC/none (cycle)
- [ ] Sort indicator arrow in column header
- [ ] Column filter popover (text match, equals, contains, NULL/NOT NULL)
- [ ] WHERE clause builder (visual) or raw WHERE input field
- [ ] Active filter indicators on column headers
- [ ] Clear all filters button

### P1.6 — JSON/SQL Export Formats
CSV is done. Users expect JSON and SQL INSERT.
- [ ] Export as JSON (array of objects)
- [ ] Export as SQL INSERT statements
- [ ] Export as SQL INSERT with ON DUPLICATE KEY UPDATE
- [ ] Export selected rows only
- [ ] Copy rows to clipboard (as TSV for paste into spreadsheets)

### P1.7 — View Support
Views are first-class objects in every competitor.
- [ ] Views listed in sidebar under each database (separate from Tables)
- [ ] Click view → shows data (read-only grid)
- [ ] View DDL tab (SHOW CREATE VIEW)
- [ ] View columns in sidebar tree
- [ ] Context menu: Browse Data, View DDL, Copy Name, Drop View

---

## P2: Power User (features that drive daily adoption)

*"These are why users choose DBeaver/DataGrip over Sequel Ace."*

### P2.1 — Table Creation GUI
Visual table designer without writing DDL.
- [ ] Column editor grid (name, type picker, nullable toggle, default, PK, auto-increment)
- [ ] Add/remove/reorder columns
- [ ] Index designer (name, columns, type, unique)
- [ ] Foreign key designer (column, referenced table/column, ON DELETE/UPDATE)
- [ ] Engine/collation/charset pickers
- [ ] Preview generated CREATE TABLE SQL before executing
- [ ] ALTER TABLE mode for modifying existing tables

### P2.2 — Table Modification (ALTER TABLE)
- [ ] Add column dialog
- [ ] Drop column (with confirmation)
- [ ] Rename column
- [ ] Change column type
- [ ] Add/drop index
- [ ] Add/drop foreign key
- [ ] Rename table
- [ ] Preview ALTER TABLE SQL before executing

### P2.3 — Stored Procedures & Functions
- [ ] List procedures/functions in sidebar per database
- [ ] View source code (syntax highlighted)
- [ ] Execute procedure with parameter input dialog
- [ ] View DDL (SHOW CREATE PROCEDURE/FUNCTION)
- [ ] Drop procedure/function

### P2.4 — Triggers
- [ ] List triggers in sidebar per table
- [ ] View trigger source (syntax highlighted)
- [ ] Trigger timing/event metadata (BEFORE/AFTER, INSERT/UPDATE/DELETE)
- [ ] Drop trigger

### P2.5 — Transaction Controls
DBeaver's toolbar has Commit/Rollback/Auto-commit.
- [ ] Auto-commit toggle in toolbar
- [ ] Manual BEGIN/COMMIT/ROLLBACK buttons
- [ ] Transaction state indicator (in-transaction badge)
- [ ] Warning on window close with uncommitted transaction

### P2.6 — Data Import
- [ ] Import from CSV file
- [ ] Import from JSON file
- [ ] Import from SQL file (execute script)
- [ ] Column mapping UI (source column → target column)
- [ ] Preview first N rows before import
- [ ] Progress indicator for large imports
- [ ] Error handling (skip/abort on error)

### P2.7 — Saved Queries / Bookmarks
- [ ] Save query with name and tags
- [ ] Saved queries panel in sidebar or drawer
- [ ] Organize by folder/tag
- [ ] Quick-load into editor
- [ ] Bookmark tables/databases for quick access

### P2.8 — Connection Folders & Organization
- [ ] Group connections into folders (Development, Staging, Production)
- [ ] Color coding per environment (green=dev, yellow=staging, red=prod)
- [ ] Connection cloning/duplication
- [ ] Import/export connection configs

### P2.9 — Server Variables & Status
- [ ] SHOW VARIABLES viewer (searchable, filterable)
- [ ] SHOW STATUS viewer
- [ ] SHOW PROCESSLIST viewer
- [ ] Kill process button

---

## P3: Multi-Engine + Multiplatform

*"Reach every user on every device."*

### P3.1 — PostgreSQL Engine
- [ ] PostgreSQLAdapter via postgres-nio behind existing DatabaseProtocol
- [ ] Engine selector in ConnectionFormView
- [ ] PostgreSQL-specific schema introspection (schemas as first-class, sequences, materialized views)
- [ ] PostgreSQL syntax highlighting keywords (RETURNING, ILIKE, ::cast, etc.)
- [ ] Default port switching (3306/5432)

### P3.2 — iPad Target
Primary multiplatform expansion — zero native iPad database clients exist.
- [ ] View modifier extensions wrapping visionOS-specific APIs (no #if os in views)
- [ ] `.inspector()` for record editor on iPad (native right drawer)
- [ ] Adaptive layout (sidebar collapses in compact width)
- [ ] Touch-optimized data grid (tap cells, swipe rows)
- [ ] iPad keyboard shortcuts (Cmd+Return, Cmd+T, etc.)

### P3.3 — macOS Target
Crowded market but "glas" brand ecosystem.
- [ ] NSViewRepresentable text editor (replaces UIViewRepresentable)
- [ ] `.inspector()` for record editor on Mac
- [ ] macOS menu bar integration
- [ ] Multiple windows (macOS windowing, not visionOS spatial)
- [ ] Drag-and-drop (files into import, rows between tables)

### P3.4 — iCloud Keychain Integration
- [ ] AuthenticationServices framework for credential storage
- [ ] ASCredentialIdentityStore for connection passwords
- [ ] Face ID / Touch ID authentication before connect
- [ ] Credentials sync across devices via iCloud Keychain
- [ ] "Save to Keychain" prompt on first successful connection

### P3.5 — SQLite Engine (stretch)
- [ ] SQLiteAdapter (Foundation's built-in SQLite or GRDB)
- [ ] Open .sqlite/.db files directly
- [ ] No connection config needed (just file path)
- [ ] CoreData database inspection

---

## P4: Advanced (features that differentiate)

*"These make glassdb better than DBeaver, not just equal."*

### P4.1 — ER Diagram Visualization
- [ ] Visual table relationship diagram
- [ ] Auto-layout based on foreign key relationships
- [ ] Click table in diagram → opens TableDetailView
- [ ] Export diagram as image
- [ ] On visionOS: 3D spatial diagram with depth for relationship layers

### P4.2 — Explain Plan Visualization
- [ ] EXPLAIN / EXPLAIN ANALYZE output
- [ ] Visual query plan tree (not just text table)
- [ ] Cost/row estimates highlighted
- [ ] Full table scan warnings
- [ ] Index usage indicators
- [ ] Compare plans side-by-side

### P4.3 — Schema Comparison
- [ ] Select two databases → diff view
- [ ] Column-level diff (added, removed, changed type)
- [ ] Index diff
- [ ] FK diff
- [ ] Generate migration SQL (ALTER TABLE statements)

### P4.4 — Database Dashboard
- [ ] Connection overview: uptime, version, connections, threads
- [ ] Table size chart (bar chart of table sizes)
- [ ] Growth trends (if data collected over time)
- [ ] Slow query log viewer
- [ ] Alert on table without indexes

### P4.5 — Spatial Multi-Window (visionOS exclusive)
- [ ] Pin results in 3D space next to source query
- [ ] Arrange multiple table browsers spatially
- [ ] Drag table from sidebar → opens floating detail window
- [ ] Spatial ER diagram in a volume
- [ ] Hand-tracked table relationship drawing

### P4.6 — AI-Powered Features (on-device, Foundation Models)
- [ ] Natural language → SQL query generation
- [ ] Query optimization suggestions
- [ ] Error explanation ("this query failed because...")
- [ ] Schema documentation generation
- [ ] Anomaly detection in query results

### P4.7 — Collaboration (stretch)
- [ ] Share queries via iCloud
- [ ] Team connection configs (shared via App Group)
- [ ] Query annotations / comments
- [ ] Shared query history

---

## Parity Scorecard

Track progress against the competitive analysis matrix:

| Feature | DBeaver | TablePlus | DataGrip | glassdb Status |
|---------|---------|-----------|----------|----------------|
| Data browsing | Yes | Yes | Yes | **v0.1 Done** |
| Inline editing | Yes | Yes (staged) | Yes | P1.4 |
| Table structure | Yes | Yes | Yes | **v0.1 Done** |
| Query editor | Yes | Yes | Yes | **v0.1 Done** |
| Syntax highlighting | Yes | Yes | Yes | **v0.1 Done** |
| DDL viewer | Yes | Yes | Yes | **v0.1 Done** |
| CSV export | Yes | Yes | Yes | **v0.1 Done** |
| JSON/SQL export | Yes | Yes | Yes | P1.6 |
| Row count | Yes | Yes | Yes | **v0.1 Done** |
| SSH tunnels | Yes | Yes | Yes | **v0.1 Done** |
| Autocomplete | Yes | Basic | Yes | P1.1 |
| Query history | Yes | Yes | Yes | P1.2 |
| Multiple tabs | Yes | Yes | Yes | P1.3 |
| Data filtering/sorting | Yes | Yes | Yes | P1.5 |
| Views | Yes | Yes | Yes | P1.7 |
| Table creation GUI | Yes | Yes | Yes | P2.1 |
| ALTER TABLE | Yes | Yes | Yes | P2.2 |
| Stored procedures | Yes | Yes | Yes | P2.3 |
| Triggers | Yes | Yes | Yes | P2.4 |
| Transactions | Yes | Yes | Yes | P2.5 |
| Data import | Yes | Yes | Yes | P2.6 |
| Saved queries | Yes | Yes | Yes | P2.7 |
| PostgreSQL | Yes | Yes | Yes | P3.1 |
| ER diagram | Enterprise | No | Yes | P4.1 |
| Explain plan | Yes | No | Yes | P4.2 |
| Schema comparison | Enterprise | No | Yes | P4.3 |
| iPad native | No | No | No | **P3.2 (unique!)** |
| visionOS spatial | No | No | No | **v0.1 Done (unique!)** |
| AI query assist | No | No | No | **P4.6 (unique!)** |
