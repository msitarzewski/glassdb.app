# Tasks

Task records for glassdb. Open items live at this level; completed dated work is
archived in monthly folders (see [2026-08/README.md](./2026-08/README.md)).

## To Do

- [ ] **SQL editor gutter alignment on Mac** — the line-number gutter is an
  invisible fixed 56pt inset (symmetric on AppKit, so it pads the right edge
  too), leaving the editor text misaligned with the control bar and grid;
  give the gutter a visible treatment, asymmetric insets, and digit-count
  sizing. See [sql-editor-gutter-alignment.md](./sql-editor-gutter-alignment.md).
- [ ] **Mac File menu owns SQL document lifecycle** — the system-generated
  "New Connections Window ⌘N" File item swallows ⌘N everywhere, and the
  per-editor `databaseCommandActions` publication dies once two SQL editors
  are alive (⌘O/⌘S go dead; pre-existing on main); replace the `.newItem`
  group, move New/Open/Save/Close SQL-document verbs into the File menu per
  HIG, and make the workspace the single publisher for document actions.
  See [mac-file-menu-sql-documents.md](./mac-file-menu-sql-documents.md).
- [ ] **Connection Overview statistics performance** — the Overview cold path
  runs one `SHOW TABLE STATUS` round trip per database (391 serial queries on
  the local multi-tenant server); replace with one aggregate
  `information_schema.TABLES` query per engine and batch the UI updates.
  See [connection-overview-statistics-performance.md](./connection-overview-statistics-performance.md).

## In Progress

- [ ] **Unified SQL Workspace** — Command-W close, seed-only-Overview, and ⌘T
  document creation completed and approved 2026-08-11; U3 surface
  generalization and U7 loaded-result analysis remain open.
  See [unified-sql-workspace.md](./unified-sql-workspace.md).

## Completed

- [x] **Immediate audit remediation (2026-08-06)** — privacy manifest, SSH
  credential isolation, iPhone recovery routing, CI and scanning.
  See [immediate-audit-remediation.md](./immediate-audit-remediation.md).
- [x] **Connection library parity (2026-08-09)** — adaptive All/Favorites/
  Recent/Collections library plus glas.sh-aligned refinement.
  See [2026-08/090826_connection-library-parity.md](./2026-08/090826_connection-library-parity.md).
