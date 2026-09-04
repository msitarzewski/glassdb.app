# Tasks

Task records for glassdb. Open items live at this level; completed dated work is
archived in monthly folders (see [2026-08/README.md](./2026-08/README.md)).

## To Do

- [ ] **Breadcrumb navigation misbehaves** — reported during the 2026-08-20
  dogfood session ("weird stuff happens when navigating"), repro never
  captured. Suspects: `openWorkspace` replacing the single database tab,
  preview-vs-open interaction with `tabState.previewed`, and the trail being
  built from `tabState.displayed` (which includes previews) rather than
  `selected`. Needs the exact crumb, starting surface, and outcome.

- [ ] **Grid rows paint above the results header** — visible in the
  2026-09-02 dogfood screenshot as rows 6–7 showing behind `created_at`;
  the grid's vertical content leaks upward past its container. Separate
  clipping defect, not touched by the tab-strip work.

- [ ] **Shared SSH key picker** — the "Use a glas.sh credential" menu covers
  password credentials only; offer the shared App Group `StoredSSHKey` catalog
  on the SSH-Key auth path, excluding device-bound Secure Enclave keys.
  See [shared-ssh-key-picker.md](./shared-ssh-key-picker.md).

## In Progress

- [ ] **Unified SQL Workspace** — Command-W close, seed-only-Overview, and
  File-menu ⌘N document creation completed and approved 2026-08-11; U3 surface
  generalization and U7 loaded-result analysis remain open.
  See [unified-sql-workspace.md](./unified-sql-workspace.md).

## Completed

- [x] **Workspace tab strip hidden under titlebar backgrounds, Mac
  (2026-09-02, corrected 2026-09-04)** — `MacDatabaseWorkspaceWindowPolicy`
  now keeps `.fullSizeContentView` so NavigationSplitView's per-column
  titlebar backgrounds sit under the toolbar instead of over the tab strip;
  the titlebar material view is kept and anchored to the content layout
  guide after its removal exposed the wallpaper. Also fixed the collapsed-
  sidebar dead band and mid-titlebar toolbar buttons from 2026-08-20.
  Merged `911e06d` + `9075003`; Mac 136/136; signed Release installed.
  See [workspace-tab-strip-titlebar-overlap.md](./workspace-tab-strip-titlebar-overlap.md).
- [x] **2026-08-20 dogfood polish (merged 2026-09-02, PRs #15–#19)** —
  validation gating restored on the connection form's action buttons plus
  the shared-key-picker task record; "Required" markers on Name, Host,
  Username, SSH host/username; Mac Connections Settings gear opens Settings
  via `SettingsLink`; continuous Appearance sliders; workspace breadcrumb
  bar with `WorkspaceBreadcrumb.trail(to:connectionName:)`. Each branch
  passed the Mac suite on its own (134–135 tests); merged main 135/135.
- [x] **GlassEditorKit adoption (M3), Phases 1–3 (2026-08-13/14)** — JSON
  field (PR #11) and the SQL editor swap with the `StatementBoundaryProvider`
  seam (PR #13); `SQLHighlighter` stays glassdb's policy engine per D-008.
  See [glasseditorkit-m3-adoption.md](./glasseditorkit-m3-adoption.md).
- [x] **SSH credential sharing model in the connection form (2026-08-14/18,
  PR #12)** — database passwords never offer "Shared with glas.sh"; SSH
  credentials are the shareable class via the glas.sh catalog menu or manual
  entry with share-on-create; three explicit SSH auth modes; connection
  library column widths mirror glas.sh.
  See [ssh-credential-sharing-model.md](./ssh-credential-sharing-model.md).

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
