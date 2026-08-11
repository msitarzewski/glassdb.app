# Unified SQL Workspace

**Status:** Command-W close slice complete and human-approved 2026-08-11 (Mac 118/118; iPhone/iPad/Vision 114/114 each; seed-only-Overview and ⌘T workspace tab creation included). U3 generalization and the U7 loaded-result analysis items remain open.
**Prepared on:** `agent/command-w-editor-close`
**Scope:** Replace the nested SQL-document tabs and duplicate result grids with one top-level workspace tab system and one table-browser-derived SQL editor/results implementation.

## Objective

Make the table browser's Data experience the single canonical SQL editor and results surface across table browsing, freeform SQL documents, and detached results, while retaining the capabilities that are valid for each context.

The finished workspace has one visible tab row. Each table or SQL document occupies one top-level workspace tab. `QueryEditorView` no longer owns a second tab strip or a second grid implementation.

## Locked Product Decisions

These requirements were clarified and approved on 2026-08-09:

1. The table browser Data UI is the template. The basic SQL editor is not the template.
2. `DatabaseWorkspaceView` owns the only tab strip in the database workspace.
3. Every SQL document is a uniquely identified top-level workspace tab beside table tabs.
4. The nested SQL tab strip, its `+` button, and its separate close behavior are removed.
5. The highlighted table-browser editor, split layout, control bar, and grid become the only SQL editor/results implementation.
6. Query-only features such as history, saved queries, Explain, formatting, completion, document import/export, and script execution are retained inside the canonical surface.
7. Table-only behavior remains capability-gated. A freeform query is never silently rewritten or made editable merely because its result reports source metadata.
8. Command-W closes the active top-level SQL or table editor. Unsaved SQL receives the existing save prompt. The connection Overview remains as the non-document fallback.
9. Browsing, filtering, sorting, refreshing, or paging a table must not automatically issue an exact `COUNT(*)`.

## Current-State Evidence

- The first/top-level tab system is `WorkspaceTabState` in `glassdb/DatabaseWorkspaceView.swift:99` and is rendered by `workspaceTabBar` at `glassdb/DatabaseWorkspaceView.swift:493`.
- `WorkspaceSelection.query` is currently a singleton value at `glassdb/DatabaseWorkspaceView.swift:17`, so it cannot represent multiple top-level SQL documents.
- `QueryEditorView` owns a second document system through `QueryDocumentTab` at `glassdb/QueryEditorView.swift:293`, `[QueryDocumentTab]` state at `glassdb/QueryEditorView.swift:343`, and query-tab lifecycle functions at `glassdb/QueryEditorView.swift:1254`.
- The nested New Query action calls `createTab()` at `glassdb/QueryEditorView.swift:502` rather than creating a workspace tab.
- The basic SQL result renderer is `inlineResultsGrid` at `glassdb/QueryEditorView.swift:1003`.
- The canonical table editor/grid begins with `DataTabView` at `glassdb/TableDetailView.swift:1100`; its server query state, grid presentation state, selection, import, comparison, and paging state begin at `glassdb/TableDetailView.swift:1133`.
- The detached results window contains a third renderer at `glassdb/ResultsGridView.swift:151`.
- The table loader currently starts an exact count alongside the data query at `glassdb/TableDetailView.swift:3033`.
- Result columns already carry optional source schema/table/column provenance at `Packages/GlassDBKit/Sources/GlassDBKit/QueryResult.swift:70`.
- The historical split is recorded in `memory-bank/activeContext.md#Round 6-8` and `memory-bank/activeContext.md#Round 9`.

## Reuse Analysis

### Memory Bank reuse

- `memory-bank/tasks/immediate-audit-remediation.md` cannot be extended because it is a completed audit-remediation evidence ledger with different scope, acceptance criteria, and branch history. Reopening it would make its completed status inaccurate.
- `memory-bank/releases/codex-completions/C6-data-grid.md` cannot serve as this task because it is a release capability/evidence ledger for the desktop grid, not a migration plan for tab ownership and editor consolidation.
- `memory-bank/releases/platforms-plus-plus/P4-native-tables-record-workflows.md` cannot be extended because it governs platform-native table feasibility and outstanding device validation across a broader release.
- `memory-bank/releases/platforms-plus-plus/P5-sql-editor-schema-management.md` cannot be extended because it combines editor feasibility, schema management, and platform acceptance. Its exit criteria and evidence must remain truthful independently of this focused migration.
- No active task file tracks the corrected single-tab/single-editor requirement. A separate task file is therefore required.

### Application-code reuse

- Extend the existing table Data implementation in `glassdb/TableDetailView.swift`; it is the canonical interaction and visual source.
- Refactor `glassdb/QueryEditorView.swift` into a single-document controller/adaptor that uses the canonical surface. Preserve its parser-backed execution, history, saved-query, Explain, completion, formatting, and document workflows.
- Extend `glassdb/DatabaseWorkspaceView.swift` so its existing workspace tab model owns uniquely identified SQL documents and all editor close behavior.
- Reuse `glassdb/ResultsGridView.swift` as the detached wrapper around the shared grid rather than retaining a private detached renderer.
- Reuse `GridQueryState`, `GridServerQueryBuilder`, filter/sort/aggregate descriptors, `GridColumnLayout`, export support, and selection models already defined with the table Data implementation.
- No new application source file is planned. Shared types should remain in the existing files during the migration. A later source-file extraction requires separate reuse analysis and approval if file size or compiler constraints provide concrete justification.

## Target Architecture

```text
DatabaseWorkspaceView
  owns the only workspace tab collection
  |
  +-- Overview tab (permanent fallback)
  +-- Table tab: database + table identity
  |     `-- canonical SQL editor/results surface in table capability mode
  +-- SQL document tab: document UUID + document state
        `-- canonical SQL editor/results surface in freeform capability mode

Detached ResultsGridView
  `-- the same shared results grid in read-only loaded-result mode
```

### Tab ownership

- Replace the singleton query destination with a uniquely identified query destination, provisionally `.query(id: UUID)`.
- Store SQL document state by document ID at the workspace level. Reuse the useful fields from `QueryDocumentTab`: SQL text, saved baseline, selected range, result, title, and unsaved status.
- Derive each query tab title from its first non-empty SQL line, falling back to `Untitled SQL`.
- Keep query and table tabs in the same ordered workspace collection.
- Make SQL documents closable. Overview is the permanent fallback when the last document/object tab closes.
- Route New Query, Command-T, imported SQL, saved-query openings, history openings, generated SQL drafts, and schema/context actions through one top-level query-document creation API.

### Canonical editor/results surface

- Generalize the table Data surface without changing its established visual hierarchy: SQL editor above, resize handle, grid control bar, results grid, and status/pager below.
- Keep one SQL text editor implementation, one results control bar, and one results renderer.
- Supply execution and mutation behavior through explicit context/capability configuration rather than duplicating views.
- Keep controller ownership separate where behavior differs: the freeform controller owns document execution/history; the table controller owns generated base-table queries, metadata, paging, and safe mutation callbacks.

### Capability matrix

| Capability | Freeform SQL document | Table browser | Detached result |
|---|---:|---:|---:|
| Canonical split editor/results layout | Yes | Yes | Results only |
| Syntax highlighting and completion | Yes | Yes | No |
| Execute statement/script and cancel | Yes | Yes | No |
| Explain, format, history, saved queries | Yes | Yes where applicable | No |
| Loaded-result filter and sort | Yes | Yes | Yes |
| Selection, copy, compare, export | Yes | Yes | Yes |
| Column hide/reorder/resize/freeze | Yes | Yes | Yes |
| Server-generated filter/sort/paging | No initially | Yes | No |
| Grouping and aggregates | Loaded result only initially | Server-backed | Loaded result only |
| Auto-repeat | Off by default; capability-gated | Existing bounded table behavior | No |
| Add/edit/delete/paste/import rows | No | Only with verified table metadata and row identity | No |
| Exact total count | Explicit action only | Explicit action only | Not applicable |

### Freeform-query safety boundary

- Filtering and sorting in an arbitrary SQL document initially affect only the bounded loaded result.
- Label loaded-result operations clearly and preserve the truncation warning when `QueryResult.isTruncated` is true.
- Do not append or inject `WHERE`, `ORDER BY`, `GROUP BY`, `LIMIT`, or `OFFSET` into arbitrary SQL.
- Source provenance may enable an `Open in Table Browser` handoff, but it does not by itself enable mutation.
- Editing requires one unambiguous base table, complete metadata, stable primary-key identity in the result, non-generated writable columns, and the existing mutation safety pipeline. Otherwise the result remains read-only with an explanation.

## Sequential Task List

- [x] **U0 — Characterize and protect existing behavior**
  - Add focused regression coverage for current workspace ordering, query document state, save prompts, Command-W routing, parser-backed execution, table filters/sorts, selection, export, and safe mutations.
  - Record a baseline Mac build and the configured cross-platform build/test matrix before structural edits.
  - Preserve the existing implementation until each replacement path has equivalent automated evidence.

- [x] **U1 — Remove automatic exact-count queries**
  - Replace the parallel count request in `DataTabView.loadData()` with `pageSize + 1` sentinel fetching.
  - Use the sentinel row only to determine whether a next page exists; never display it as result data.
  - Display an unknown or explicitly estimated total by default.
  - Add an explicit `Calculate Exact Total` action with cancellation, timeout/error handling, and a production-cost warning.
  - Verify that initial load, refresh, filtering, sorting, and page navigation issue no implicit count statement.

- [x] **U2 — Make workspace tabs the only document owner**
  - Give SQL destinations stable UUID identity so multiple SQL documents can coexist in the first tab row.
  - Move query document text, saved baseline, selection, current result, title, and dirty state into workspace-owned document state.
  - Add top-level query creation, selection, reordering preservation, and close behavior.
  - Route Command-T and every SQL-opening entry point through the top-level document API.
  - Route Command-W through the selected workspace tab and preserve the existing save/don't-save/cancel prompt.
  - Remove the assumption that the SQL destination is permanent; Overview becomes the fallback after the final closable tab closes.

- [ ] **U3 — Generalize the table browser's editor/results surface**
  - Treat the current `DataTabView` layout and interaction behavior as the visual acceptance baseline.
  - Introduce explicit table, freeform, and detached-result capabilities using existing source files.
  - Separate shared presentation state from table query-generation and mutation state without changing the visible table workflow.
  - Consolidate filtering, sorting, analysis, comparison, navigation, column management, copy, import/export, selection, responsive list/grid behavior, and result status rendering.
  - Preserve per-table grid-state persistence and introduce equivalent per-document presentation state.

- [x] **U4 — Migrate freeform SQL documents to the canonical surface**
  - Make `QueryEditorView` render exactly one workspace-owned document.
  - Remove its inner tab strip, inner `+`, `[QueryDocumentTab]`, `selectedTabID`, and nested tab lifecycle.
  - Replace `inlineResultsGrid` with the canonical table-derived grid.
  - Integrate history, saved queries, Explain, formatting, completion, open/save SQL document, script execution, safety confirmation, cancellation, AI draft insertion, and detach actions into the canonical surface.
  - Ensure freeform filters/sorts are explicitly loaded-result-only and cannot mutate SQL text.

- [x] **U5 — Migrate table and detached consumers**
  - Keep table-mode server filtering, ordering, grouping, paging, auto-repeat, record editing, add row, and import backed by the existing table metadata and safety pipeline.
  - Replace the detached window's private renderer with the shared grid in read-only mode.
  - Preserve result lookup by result-set UUID and current spatial-window behavior.

- [x] **U6 — Remove duplicate implementations**
  - Delete the old basic inline grid only after U4 evidence passes.
  - Delete the detached private renderer only after U5 evidence passes.
  - Remove the nested query-tab state/actions and obsolete Command-W/Command-Shift-W distinctions.
  - Consolidate duplicated width, cell formatting, accessibility labels, empty-state, and export logic.
  - Run dead-code and localization/accessibility-label review.

- [ ] **U7 — Full QA and approval handoff**
  - Run app tests, GlassDBKit tests, configured platform builds, `git diff --check`, and warning review.
  - Exercise multiple SQL/table tab ordering, switching, closing, save cancellation, imports, drafts, history, detach, reconnect, and state restoration.
  - Validate the table browser against its pre-migration behavior on a bounded real database.
  - Validate freeform loaded-result controls on joins, CTEs, aggregates, aliases, duplicate column labels, empty results, errors, and truncated results.
  - Confirm through captured UI evidence that only one tab row and one editor/results design remain.
  - Present the diff and QA evidence for human approval before updating completion documentation.

## Acceptance Criteria

- Only the `DatabaseWorkspaceView` tab row is visible; no SQL-document tab strip appears inside an SQL tab.
- Opening multiple SQL documents creates multiple top-level workspace tabs beside table tabs.
- Clicking a table and opening a freeform SQL document display the same table-browser-derived editor/results layout.
- There is one SQL text-editor implementation and one results-grid implementation in the live workspace.
- Query history, saved queries, Explain, formatting, completion, document import/export, script execution, cancellation, and safety prompts remain available.
- Table browsing retains server-backed filters, multi-column ordering, grouping/aggregates, paging, comparison, column management, export/import, and safe record mutations.
- Freeform filtering and sorting are honest loaded-result operations; arbitrary SQL is never silently rewritten.
- Command-W closes the focused top-level SQL or table tab. Dirty SQL prompts to save; Cancel preserves the tab and document.
- Closing the last closable tab leaves the connection Overview instead of closing the database window.
- No normal table load, refresh, filter, sort, or page action automatically executes exact `COUNT(*)`.
- Detached results use the same result grid and remain read-only.
- Existing bounded-result, mutation-safety, privacy, credential, and connection-lifecycle guarantees do not regress.
- Automated tests and every configured platform build pass, with remaining physical-device/accessibility gates stated explicitly.

## Migration and Rollback

- Implement one numbered task at a time and keep each task reviewable independently.
- U1 is an isolated safety change and can be reverted without affecting tab/editor consolidation.
- During U2-U5, retain the prior renderer behind the current call site until the replacement has characterization and parity evidence; do not maintain a user-facing preference for both implementations.
- Do not remove nested-tab or duplicate-grid code until its replacement passes the focused test suite and Mac visual check.
- If a phase fails, revert only that phase's diff and restore the last green call site. Do not roll back unrelated connection, statistics-cache, Command-W, or release-document changes already present on the branch.
- Preserve query text and save-prompt behavior throughout migration; no state-model change may intentionally discard an open document.

## Out of Scope

- Enabling edits for arbitrary joins, aggregates, views, or ambiguous query results.
- Building a general SQL AST rewriter for freeform filter/sort/paging.
- Replacing the existing syntax-highlighting text-system bridge without separate evidence and approval.
- Redesigning Structure, DDL, Indexes, or Foreign Keys modes.
- Changing connection-window or multi-window product architecture beyond editor-tab ownership.
- Holding the current release plan for this refactor unless a release owner explicitly makes it a gate.

## Evidence Log

| Task | Evidence | Result |
|---|---|---|
| U0 | Pre-change macOS suite passed; focused tab, close, paging, filtering, typed-sort, and cache coverage added in `glassdbTests/glassdbTests.swift`. | Complete |
| U1 | Table reads fetch `pageSize + 1`, trim the sentinel through `GridPageWindow`, expose exact count only through a warned 30-second action, and retain cached estimates. | Complete |
| U2 | `WorkspaceSelection.query(id:)`, workspace-owned `QueryDocumentTab` bindings, top-level creation/import/draft routing, and parent-owned save-before-close flow. | Complete |
| U3 | `DataTabView` is live in table, freeform, and results-only modes; loaded filtering/sorting, selection, compare, columns, copy, and export are shared. Loaded grouping/aggregate parity remains open. | In progress |
| U4 | `QueryEditorView` is a single-document controller over `DataTabView`; history, saved queries, Explain, format, completion, file I/O, script execution, cancellation, safety prompts, error assistance, and detach remain integrated. | Complete |
| U5 | `TableDetailView` retains table capabilities and `ResultsGridView` now wraps the shared `DataTabView` grid with the editor hidden. | Complete |
| U6 | Nested query-tab state/UI, basic inline grid, detached private grid, duplicate width logic, and Command-Shift-W close distinction removed. | Complete |
| U7 | macOS app suite, GlassDBKit package suite (25 tests), macOS build, iOS Simulator build, visionOS Simulator build, and `git diff --check` pass. ScreenCaptureKit blocked automated visual capture; human UI acceptance and real-database exercises remain. | In progress |
