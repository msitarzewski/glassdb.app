# August 2026 Tasks

## Tasks Completed

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
