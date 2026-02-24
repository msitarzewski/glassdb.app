# v0.2 — PostgreSQL + Data Browsing

**Target**: Fast-follow after v0.1 App Store launch
**Engine**: MySQL + PostgreSQL
**Platform**: visionOS 2.0+, Swift 6.2

## Milestones

| Milestone | Name | Status | Description |
|-----------|------|--------|-------------|
| M0 | PostgreSQL Adapter | not-started | postgres-nio behind existing DatabaseProtocol |
| M1 | Table Data Browser | not-started | Browse/edit table data with pagination |
| M2 | Inline Editing | not-started | Edit cell values directly in results grid |
| M3 | Ship v0.2 | not-started | TestFlight → App Store update |

## Scope

### Must Have
- [ ] PostgreSQL support via postgres-nio (`PostgreSQLAdapter.swift` in GlassDBKit)
- [ ] Engine selector in ConnectionFormView (MySQL / PostgreSQL)
- [ ] Default port switching (3306 MySQL, 5432 PostgreSQL)
- [ ] PostgreSQL schema introspection (databases, tables, columns)
- [ ] Table data browsing (SELECT * with LIMIT/OFFSET pagination)
- [ ] Inline cell editing (UPDATE single row)

### Should Have
- [ ] PostgreSQL-specific syntax highlighting keywords
- [ ] Connection testing ("Test Connection" button before save)
- [ ] Query explain plan visualization (EXPLAIN output)
- [ ] Saved queries library (name, tag, organize)

### Won't Have (deferred to v0.3+)
- ER diagram visualization
- Stored procedure editor
- Database backup/restore
- User/privilege management
- Data import wizard
- SQLite / MongoDB / other engines

## Key New Files
- `Packages/GlassDBKit/Sources/GlassDBKit/PostgreSQLAdapter.swift`
- `glassdb/TableDataView.swift`

## Architecture Notes
- `DatabaseProtocol.swift` already defines `DatabaseEngine` + `DatabaseConnection` — PostgreSQL adapter slots in without touching existing MySQL code
- `DatabaseEngineType` enum in `Models.swift` has `.postgresql` commented out, ready to uncomment
- Connection form just needs an engine picker; all SSH/TLS/Keychain logic is engine-agnostic
