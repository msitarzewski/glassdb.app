# C6: Desktop-Class Data Grid

**Status**: in progress
**Depends on**: C2, C4
**Source IDs**: M04, D01-D05

## Goal

Provide a high-volume, type-correct grid with server-side operations and safe transactional editing.

## Implementation Plan

### Server-side navigation

- [ ] Add multi-column ASC/DESC sorting with visible priority and server-generated ORDER BY.
- [ ] Add typed per-column filters plus raw WHERE mode, active-filter indicators, clear-all, and parameterized predicates.
- [ ] Preserve filters, sorts, selection, and scroll position across refresh where row identity permits.
- [ ] Keep paging/streaming bounded through C2; display exact versus estimated row counts honestly.

### Column and range workflows

- [ ] Support column resize, reorder, freeze, hide/show, reset, and persisted layout per connection/database/object.
- [ ] Add rectangular selection, keyboard extension, copy/paste TSV, fill, and safe paste previews.
- [ ] Export selected/all rows to CSV, JSON, and SQL with typed encoding; add import mapping and preview through C4.
- [ ] Add compare, grouping, and aggregate workflows without loading unbounded datasets into memory.

### Typed editing

- [ ] Provide editors for every C2 value family and distinct NULL, DEFAULT, empty, generated, and unavailable states.
- [ ] Stage insert/update/delete operations visibly with per-cell/row undo, discard all, and SQL preview.
- [ ] Apply batches only through C4's bound, optimistic, affected-row-verified transaction engine.
- [ ] Prevent editing when stable row identity or required metadata is unavailable; explain how to make the result editable.

## Exit Criteria

- [ ] Filtering, sorting, grouping, and aggregates are server-bounded and injection-safe.
- [ ] Column layout and range operations work by keyboard, pointer, touch, and visionOS input as applicable.
- [ ] Type/NULL/default/generated semantics survive edit, copy, import, export, refresh, and rollback.
- [ ] Large-grid profiling meets documented memory and interaction budgets.

## Evidence Log

| Date | Dataset/Workflow | Expected | Actual | Test/Commit |
|---|---|---|---|---|
| 2026-07-17 | 1K JSON + SQL export | type-correct bounded output | passed; 0.007s on visionOS 26.5 simulator | `gridScale1KJSONAndSQLExport` |
| 2026-07-17 | 10K typed map + TSV range | linear mapping/copy | passed; 0.116s | `gridScale10KTypedMappingAndRangeTSV` |
| 2026-07-17 | 100K CSV + 1K filters | no quadratic metadata/selection path | passed; 0.262s | `gridScale100KCSVAndBoundFilters` |
| 2026-07-17 | Import cap | accept 10,485,760 bytes; reject 10,485,761 before parse | passed | `gridImportPolicyRejectsOversizeBeforeParsing` |
