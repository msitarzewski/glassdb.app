# Tasks

Task records for glassdb. Open items live at this level; completed dated work is
archived in monthly folders (see [2026-08/README.md](./2026-08/README.md)).

## To Do

- [ ] **SSH credential sharing model in the connection form** — database
  passwords must never offer "Shared with glas.sh"; SSH credentials become the
  shareable class via a glas.sh catalog picker or manual entry with a
  share-on-create checkbox. No migration needed (no users).
  See [ssh-credential-sharing-model.md](./ssh-credential-sharing-model.md).

- [ ] **Shared SSH key picker** — the "Use a glas.sh credential" menu covers
  password credentials only; offer the shared App Group `StoredSSHKey` catalog
  on the SSH-Key auth path, excluding device-bound Secure Enclave keys.
  See [shared-ssh-key-picker.md](./shared-ssh-key-picker.md).

## In Progress

- [ ] **Workspace tab strip hidden under titlebar backgrounds (Mac)** — the
  window policy dropped `.fullSizeContentView`, so NavigationSplitView's
  per-column titlebar backgrounds sat on the tab strip; fixed by aligning
  the policy with glas.sh, pending review.
  See [workspace-tab-strip-titlebar-overlap.md](./workspace-tab-strip-titlebar-overlap.md).

- [ ] **GlassEditorKit adoption (M3)** — Phase 1 (JSON field) complete and
  approved 2026-08-13; DDL display, the SQL editor surface, and the
  `SQLHighlighter` provider seam remain.
  See [glasseditorkit-m3-adoption.md](./glasseditorkit-m3-adoption.md).

- [ ] **Unified SQL Workspace** — Command-W close, seed-only-Overview, and
  File-menu ⌘N document creation completed and approved 2026-08-11; U3 surface
  generalization and U7 loaded-result analysis remain open.
  See [unified-sql-workspace.md](./unified-sql-workspace.md).

## Completed

- [x] **iOS build: required-field helper outside the macOS guard (2026-09-02)** —
  `requiredFieldLabel` from the required-markers slice was defined inside the
  `#if os(macOS)` form block while the shared compact sections call it on
  every platform; moved verbatim below the guard. iOS simulator build passes
  against the pinned packages; Mac 135/135.

- [x] **SQL editor gutter alignment on Mac (2026-08-11)** — visible digit-sized
  gutter band, asymmetric insets, draw-order fix for the misplaced digit
  column found in live testing.
  See [sql-editor-gutter-alignment.md](./sql-editor-gutter-alignment.md).
- [x] **Mac File menu owns SQL document lifecycle (2026-08-11)** — ⌘N/⌘⇧N/⌘O/⌘S
  in File, Query keeps execution verbs, single workspace publisher fixes the
  multi-editor ⌘O/⌘S defect.
  See [mac-file-menu-sql-documents.md](./mac-file-menu-sql-documents.md).
- [x] **Connection Overview statistics performance (2026-08-11)** — one
  aggregate query per engine; 391-database Overview now loads in ~4 seconds.
  See [connection-overview-statistics-performance.md](./connection-overview-statistics-performance.md).
- [x] **Immediate audit remediation (2026-08-06)** — privacy manifest, SSH
  credential isolation, iPhone recovery routing, CI and scanning.
  See [immediate-audit-remediation.md](./immediate-audit-remediation.md).
- [x] **Connection library parity (2026-08-09)** — adaptive All/Favorites/
  Recent/Collections library plus glas.sh-aligned refinement.
  See [2026-08/090826_connection-library-parity.md](./2026-08/090826_connection-library-parity.md).
