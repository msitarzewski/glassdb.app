# P4: Native Tables, Results, and Record Workflows

**Status**: in progress — compact native list and regular-width grid exception are automated-green; physical/live-data accessibility and interaction matrix remains
**Goal**: G4
**Depends on**: P2, P3

## Objective

Use SwiftUI’s native table stack for arbitrary database results wherever it meets professional requirements, while retaining only evidence-backed custom behavior that the platform cannot supply.

## Native Table Feasibility Spike

Build against real `QueryResult` and table data using:

- [x] `Table` with stable row identity evaluated against the installed iOS 27 SDK.
- [x] `TableColumnForEach` for arbitrary runtime SQL columns evaluated against the installed iOS 27 SDK.
- [x] `TableColumnCustomization` with scene-persisted visibility and ordering evaluated against the installed iOS 27 SDK.
- [x] Native single/multiple selection and edit mode evaluated and adopted for the compact record list.
- [ ] Native sorting wired to bound server-side sort descriptors.
- [ ] Native headers, vertical/horizontal scrolling, keyboard/pointer selection, and accessibility.
- [ ] Native context menus, swipe actions, copy, drag/drop, ShareLink, and file export.

Test arbitrary schemas: zero columns, one column, hundreds of columns, duplicate labels, long identifiers, NULL/binary/JSON/date/number values, wide Unicode, 100/1K/10K rows, empty results, error results, and multiple result sets where supported.

## iPhone Results

- [x] Design the compact first column as a readable record summary because SwiftUI Table hides later columns in compact width.
- [x] Tap a row to open record detail/edit; do not force spreadsheet horizontal navigation on a phone.
- [x] Enter edit mode for multirow selection and export, consistent with iOS HIG.
- [x] Provide explicit filter/column/copy/import/analysis actions through native toolbar/menu presentations.

## iPad Results

- [ ] Use multicolumn Table with native resizing/customization where available.
- [ ] Preserve selection across sort/filter/page changes only when identity remains valid.
- [ ] Present row editing in an inspector on regular width and adaptive sheet/navigation when compact.
- [ ] Preserve server-bound filtering/sorting as the default and loaded-page display filtering as an explicit alternate mode.

## Record and Mutation Safety

- [ ] Reuse `RecordEditorView`, staged edits, typed binding, JSON semantic formatting/compaction, optimistic predicates, transaction, preview, confirmation, audit, and error correction.
- [ ] Use type-appropriate native editors and formatters.
- [ ] Preserve row selection as distinct from row editing.
- [ ] Support add, update, NULL/default, copy, compare, export, and conflict recovery without changing engine safety policy.

## Custom Exception Decision

Evaluate these advanced behaviors explicitly:

- arbitrary frozen columns;
- frozen synthetic row-number gutter;
- rectangular cell selection;
- spreadsheet paste/fill;
- arbitrary column resize persistence;
- large-result performance and virtualization;
- transparency-specific pinned header legibility on Mac/Vision.

If native Table cannot support a must-have behavior, retain a platform-scoped custom data plane only after recording why. Do not retain manual toolbar, menu, pointer, or modal chrome around it.

## Data Loop

`REAL RESULT → NATIVE TABLE → SELECT/SORT/FILTER/EDIT → COPY/EXPORT → ACCESSIBILITY → SCALE → COMPARE TO CURRENT GRID → DECIDE`

## Exit Criteria

- [ ] Native Table is the default iPhone/iPad results implementation unless the exception record proves otherwise.
- [ ] Compact results are useful and readable rather than a truncated desktop grid.
- [ ] Selection/edit/export semantics are native and deterministic.
- [ ] Data fidelity and mutation safety match existing Mac/Vision behavior.
- [ ] Scale targets pass without unbounded rendering or memory regressions.

## Evidence Log

| Date | Dataset/Workflow | Native Result | Custom Exception | Evidence |
|---|---|---|---|---|
| 2026-07-21 | Installed SwiftUI 27 declaration audit | `Table`, runtime `TableColumnForEach`, customization, sorting, and multi-selection are available | Native Table does not expose the existing grid's frozen synthetic gutter, arbitrary frozen columns, rectangular range selection, spreadsheet paste mapping, or persisted freeform widths | Xcode 27 SDK declarations plus current requirements at `TableDetailView.swift#DataTabView` |
| 2026-07-21 | iPhone compact results | Replaced the squeezed spreadsheet with a native `List(selection:)`, readable labeled record summaries, Edit-mode multirow selection, tap-to-edit, and native context actions | None for compact width | Generic iOS 27 simulator build passed; iPhone 17 Pro launch/screenshot passed; focused connection-form simulator tests passed. Live result navigation remains pending. |
| 2026-07-21 | iPad regular results | Retained the proven professional grid and all staged mutation safeguards | Platform-scoped data-plane exception retained for frozen columns/gutter, rectangular selection, paste mapping, and persisted widths; surrounding toolbar/menu/sheet chrome remains native SwiftUI | Generic iOS 27 simulator build and iPad Pro 13-inch launch/screenshot passed. Live wide-table QA remains pending. |
| 2026-07-21 | iOS table destinations | Replaced the nested table-mode `TabView` with a native toolbar `Menu`/`Picker` and retained each visited mode's state | None | Generic iOS 27 simulator build passed. |
| 2026-07-21 | Data fidelity, mutation, selection, import/export, and scale | Compact and regular paths reuse one typed query/mutation core | Regular-width custom data plane remains the documented exception; no custom system toolbar or presentation was added | Five 101-test app suites passed, including typed filters, sort validation, optimistic mutations, JSON compaction, TSV/CSV/JSON/SQL fidelity, 1K/10K/100K scale, range paste, and Mac row-selection semantics. |
