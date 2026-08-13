# August 2026 Tasks

## Tasks Completed

### 2026-08-13: GlassEditorKit Adoption Phase 1 (JSON Field)

- First consumer adoption of the shared Glass-family editor package:
  revision-pinned dependency, JSON record fields with tree-sitter
  highlighting, resizable fields/sheet, header-inline actions.
- Drive-by global-coordinate drag fixes for all three resize surfaces.
- Mac 123/123; iPhone/iPad/Vision matrix green; upstream findings recorded.
- See [../glasseditorkit-m3-adoption.md](../glasseditorkit-m3-adoption.md).

### 2026-08-11: Overview Statistics, File-Menu Lifecycle, and Editor Gutter

- One aggregate statistics query per engine replaces the 391-round-trip
  Overview walk (~4 s cold load, was 40+); cache fan-out preserves all
  per-database consumers.
- Mac File menu owns SQL document lifecycle (⌘N/⌘⇧N/⌘O/⌘S/Close Active Tab);
  single workspace command publisher fixes the multi-editor ⌘O/⌘S defect.
- Visible digit-sized editor gutter with correct draw order and focus
  handling, caught and repaired through live function testing.
- Final code: Mac 122/122, iPhone/iPad/Vision 118/118 each, GlassDBKit 28/28,
  security review clean.
- See the three task records at the tasks root.

### 2026-08-11: Command-W Editor Close and Workspace Tab Seeding

- Command-W closes the selected top-level SQL/table tab with save prompts;
  Overview is the non-document fallback.
- Workspace windows seed only Overview; ⌘T creates SQL documents on demand
  through a workspace-level action that works with zero editors open.
- Passed Mac 118/118 and iPhone/iPad/Vision Pro 114/114 each with zero
  failures or skips; Mac runtime warnings proven pre-existing.
- Follow-ups filed: Overview statistics performance, Mac File-menu SQL
  document lifecycle, editor gutter alignment.
- See [../unified-sql-workspace.md](../unified-sql-workspace.md).

### 2026-08-09: Connection Library Parity

- Added a single-catalog All/Favorites/Recent/Collections connection library with
  scoped search and deterministic selection behavior.
- Delivered adaptive iPhone, iPad, Mac, and Vision Pro navigation and grouped
  connection detail without changing credential authority.
- Passed 414 platform test executions with zero failures or skips.
- Approved the 2026-08-10 glas.sh-aligned row/detail refinement after a combined
  preview; 115/115 Mac tests and Mac/iPhone/iPad/Vision Pro builds passed.
- See [090826_connection-library-parity.md](./090826_connection-library-parity.md).
