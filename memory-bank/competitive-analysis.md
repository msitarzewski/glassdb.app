# Competitive Analysis & Feature Roadmap

**Created**: 2026-03-15 (discovery session)
**Sources**: DBeaver CE, TablePlus, DataGrip (JetBrains), Sequel Ace, pgAdmin 4, MySQL Workbench

---

## Sidebar / Navigator Tree Comparison

### DBeaver (most complete)
```
Connection (color-coded by type)
 └── Database / Schema
      ├── Tables
      │    └── Table Name
      │         ├── Columns (name, type, PK/FK icons)
      │         ├── Indexes
      │         ├── Foreign Keys
      │         ├── Triggers
      │         ├── References (reverse FK)
      │         └── Partitions
      ├── Views
      ├── Stored Procedures / Functions
      ├── Sequences
      ├── Data Types (user-defined)
      └── Roles / Users
```

**Context menu actions per item:**

| Item | Actions |
|------|---------|
| Connection | Connect/Disconnect, Edit, Create Database, SQL Editor, Refresh, Rename, Copy, Delete |
| Database | Set as Active, SQL Editor, Create Table, Create Schema, Refresh |
| Table | Open Data, Edit Structure, Generate SQL (SELECT/INSERT/DDL), Export, Import, Rename, Drop, Refresh, Count Rows |
| Column | Copy Name, Set as Filter |
| View | Open Data, View DDL, Drop |
| Stored Procedure | View Source, Execute, Drop |

### TablePlus (simplest, fastest)
- Flat sidebar — database switchable via dropdown, not tree
- Tab bar at top to switch object types (Tables, Views, Functions, Procedures)
- No column-level visibility in sidebar
- Context menu: Open, Structure, Info, Duplicate, Truncate, Drop, Export, Import

### DataGrip (IDE-level)
- Similar to DBeaver tree + inline quick docs on hover
- Schemas as first-class nodes (important for PostgreSQL)
- File-based SQL scripts alongside database objects in same tree
- Color-coded datasources

### Sequel Ace (Mac-native, MySQL only)
- No sidebar tree — top-level connection picker, database dropdown
- Flat table list in left panel
- Very clean, minimal chrome

---

## Context-Sensitive Detail Surface

### DBeaver — Multi-Tab Per Object (the gold standard)

**Clicking a Table opens tabs:**

| Tab | Contents |
|-----|----------|
| **Data** | Scrollable data grid with inline editing, filtering, sorting, pagination. Row count in status bar. Add/delete rows. |
| **Properties** | Column definitions (name, type, nullable, default, comment) as editable grid |
| **DDL** | Auto-generated CREATE TABLE, read-only, copy button |
| **Indexes** | Index list with columns, type (BTREE, HASH), uniqueness |
| **Foreign Keys** | FK definitions with referenced table/column |
| **Triggers** | Trigger definitions with source code |
| **References** | Tables that reference THIS table via FK |
| **Partitions** | Partition info if applicable |
| **ER Diagram** | Mini ER diagram showing related tables |

**Clicking a Database:** Properties (char set, collation, size), dashboard with table count/total size.

**Clicking a Connection:** Driver info, server version, connection URL.

### TablePlus — Toolbar Switching
- Click table → immediate data grid
- Top toolbar switches: Data, Structure, Triggers, Relations, Indexes, Info
- **Staging model** — edits collected with colored indicators, committed as batch on Cmd+S. Safer than DBeaver's immediate-write.

### DataGrip — IDE + Table Editor
- Table editor: Data, DDL, Columns, Keys, Indexes, Foreign Keys tabs
- Double-clicking table inserts name into active query
- "Modify Table" dialog for GUI-based ALTER TABLE

### Sequel Ace — Four Tabs
- Structure, Content, Relations, Triggers, Info
- Clean Mac-native tab design

---

## DBeaver Navigation Model (Deep Dive)

### Active Database
- Set per connection, shown in toolbar dropdown
- Active database node **bolded** in navigator tree
- SQL editors opened from a database inherit that database as context
- Toolbar breadcrumb: `[Connection] | [Database] | [Schema]`

### Tab Model
- Each opened object gets its own tab (like browser tabs)
- Tabs show: icon + object name + modified indicator (asterisk)
- Tabs can be pinned, split horizontally/vertically, moved to new window
- SQL Editor tabs separate from object tabs
- Close: Ctrl+W

### Properties Panel
- Separate side panel (toggle via Window menu)
- Read-only key-value pairs for selected navigator item
- Supplementary to main editor tabs (like Xcode inspector)

### Toolbar
1. New Connection
2. Active Connection dropdown
3. Active Database/Schema dropdown
4. SQL Editor (open new)
5. Commit / Rollback (transaction controls)
6. Auto-commit toggle
7. Execute SQL / Execute Script
8. Explain Plan
9. Export Results
10. Navigate Back/Forward

---

## Feature Comparison Matrix

| Feature | DBeaver | TablePlus | DataGrip | Sequel Ace | pgAdmin | MySQL WB | **glassdb v1.0** |
|---------|---------|-----------|----------|------------|--------|----------|-----------------|
| Data browsing + inline edit | Yes | Yes (staged) | Yes | Yes | Partial | Yes | Browse only |
| Table structure viewing | Yes | Yes | Yes | Yes | Yes | Yes | **Yes** |
| Query editor + results | Yes | Yes | Yes | Yes | Yes | Yes | **Yes** |
| DDL generation/viewing | Yes | Yes | Yes | Yes | Yes | Yes | **Yes** |
| Data export (CSV/JSON/SQL) | Yes | Yes | Yes | CSV/SQL | Yes | Yes | **CSV only** |
| Table statistics/row count | Yes | Yes | Yes | Yes | Yes | Yes | **Yes** |
| Schema comparison | Enterprise | No | Yes | No | No | Yes | No |
| ER diagrams | Enterprise | No | Yes | No | No | Yes | No |
| Table creation GUI | Yes | Yes | Yes | Yes | Yes | Yes | No |
| Import data | Yes | Yes | Yes | CSV | Yes | Yes | No |
| Syntax highlighting | Yes | Yes | Yes | Yes | Yes | Yes | **Yes** |
| Autocomplete (SQL) | Yes | Basic | Yes | Basic | Basic | Yes | No |
| Multiple result tabs | Yes | Yes | Yes | No | Yes | Yes | No |
| SSH tunnel support | Yes | Yes | Yes | Yes | Yes | Yes | **Yes** |
| Connection bookmarks | Yes | Yes | Yes | Yes | Yes | Yes | **Yes** |
| Dark mode | Yes | Yes | Yes | Yes | No | No | **Yes (spatial)** |

---

## Prioritized Feature Roadmap

### Must-Have v1.0 (ship-blocking) — STATUS: DONE

| # | Feature | Status |
|---|---------|--------|
| 1 | Connection manager (CRUD, test, save) | Done |
| 2 | Navigator tree (Connection → Database → Tables) | Done |
| 3 | Table data browser (scrollable grid, pagination) | Done |
| 4 | Table structure viewer (columns, types, keys) | Done |
| 5 | SQL query editor (syntax highlighting, execute, results) | Done |
| 6 | DDL viewer (SHOW CREATE TABLE) | Done |
| 7 | Active database selector | Done |
| 8 | Row count | Done |
| 9 | Result export (CSV) | Done |
| 10 | Connection state indicators | Done |

### Should-Have v1.1 (expected by experienced users)

| # | Feature | Status |
|---|---------|--------|
| 11 | Inline data editing (TablePlus staging model) | Not started |
| 12 | Index viewer | Done (v1.0) |
| 13 | Foreign key viewer | Done (v1.0) |
| 14 | SQL autocomplete (tables, columns, keywords) | Not started |
| 15 | Multiple query tabs | Not started |
| 16 | JSON/SQL export formats | Not started |
| 17 | View support in navigator | Not started |
| 18 | Query history (persisted) | Not started |
| 19 | Table creation GUI | Not started |
| 20 | Stored procedure/function viewer | Not started |
| 21 | iPad + Mac targets | Planned |
| 22 | iCloud Keychain integration | Planned |

### Nice-to-Have v2.0 (differentiators)

| # | Feature | Status |
|---|---------|--------|
| 23 | Data import (CSV, JSON, SQL) | Not started |
| 24 | ER diagram (visual relationships) | Not started |
| 25 | Schema comparison (diff databases) | Not started |
| 26 | Explain plan visualization | Not started |
| 27 | Database dashboard (size, stats) | Partial (DatabaseDetailView) |
| 28 | Trigger viewer/editor | Not started |
| 29 | User/role management | Not started |
| 30 | Server variables viewer | Not started |
| 31 | Data generation (test data) | Not started |
| 32 | Bookmarks/favorites for tables/queries | Not started |
| 33 | PostgreSQL support | Not started |
| 34 | Spatial multi-window pinning | Not started |

---

## Key UX Insights

### 1. Flatten the hierarchy for spatial UI
Traditional clients use deep trees because they live in 2D. visionOS enables **spatial hierarchy** — schema browser as floating sidebar, results pinned in space, query editor as primary surface. glassdb already does this with detachable ResultsGridView.

### 2. TablePlus staging model is the safest for editing
DBeaver's immediate-write has caused accidental data modifications. TablePlus stages changes visually, applies on explicit save. **glassdb's RecordEditorView already uses this pattern.**

### 3. The detail surface is the product's core identity
Users spend 80%+ of time in the detail surface (data grid + structure tabs), not the navigator. The TableDetailView 5-tab design is the right investment.

### 4. Context menus are essential for power users
Every successful client provides rich context menus on tree items. **glassdb has this on databases and tables.**

### 5. SQL autocomplete is the retention feature
Users report autocomplete (especially table/column names) is the single feature that determines adoption. **This is the #1 v1.1 priority.**

---

## Competitive Positioning

| Client | Strength | Weakness |
|--------|----------|----------|
| DBeaver | Feature completeness, multi-database | UI complexity, Java-heavy, slow startup |
| TablePlus | Speed, clean UI, Mac-native | Limited free tier, fewer advanced features |
| DataGrip | IDE integration, refactoring, autocomplete | Subscription cost, heavy resources |
| Sequel Ace | Free, Mac-native, simple | MySQL only, limited features, aging |
| pgAdmin | PostgreSQL depth, free | Web-based feel, poor UX |
| MySQL Workbench | Official MySQL tool, modeling | Dated UI, MySQL only, crashes |
| **glassdb** | **Only native visionOS/spatial client** | MySQL only (v1.0), no autocomplete yet |

**glassdb's opportunity**: Zero competition on visionOS. The spatial computing form factor enables query editing, results viewing, and schema browsing as separate spatial surfaces rather than competing for tab space. iPad (v1.1) is also wide open — no good native iPad database client exists.
