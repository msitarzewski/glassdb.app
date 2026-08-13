# GlassEditorKit Adoption (M3)

**Status:** Phase 1 complete and human-approved 2026-08-13 on `agent/glasseditorkit-m3-phase1`. Phases 2–4 (DDL display, SQL editor, `SQLHighlighter` seam) remain open.
**Package:** [GlassEditorKit](https://github.com/msitarzewski/GlassEditorKit) — the shared Glass-family text-editing engine; sibling repo at `../GlassEditorKit`. Its `INTEGRATION.md` Part A is the authoritative plan; D-008 resolved option 2 (statement parsing and the SQL policy engine stay in glassdb).
**Pinned revision:** `ae094a8` ("Highlight by default: GlassEditorModel drives tree-sitter automatically"), wired as a revision-pinned remote reference in `glassdb.xcodeproj` following the GlasSecretStore/GlassConnectionKit pattern, so CI resolves it with no workflow changes.

## Phase 1 — JSON field (complete)

- `RecordEditorView`'s non-NULL JSON branch renders `GlassEditorView` with `language: .json`; per-column `GlassEditorModel`s are built beside the staged edits (including NULL columns so NULL→typed transitions find a model). The staging model remains the sole source of truth: editor changes route through the shared `fieldBinding` semantics, Format pushes back through an echo guard, and `RecordJSONText` dirty detection is untouched.
- Line numbers follow the app's existing `showLineNumbers` setting — one setting, one engine, both editor surfaces.
- Syntax highlighting is tree-sitter via the package's built-in driver (default-on as of the pinned revision; the earlier pin `7c9463d` predated the driver and rendered monochrome).
- Field UX: Format/Validate moved inline into the field header (column name middle-truncates on one line to avoid wrapping); Set to NULL stays below as the generic nullable-field affordance. A drag pill resizes the field 120–800pt, anchored at live rendered height via `onGeometryChange`; the record editor sheet is resizable (width 680–1100, height to 960).
- Defensive `.clipped()` guards the field against the package gutter overlay drawing outside a capped frame (macOS 14+ no-clip default).

## Drive-by repairs (pre-existing on main, exposed during Phase 1 testing)

- All three hand-rolled drag surfaces measured drags in local coordinate space while the handle rode the edge being moved — a feedback loop causing jumpy resizing. Table column resize, the workspace editor/results divider (which also compounded cumulative translation per tick), and the new JSON pill now use `coordinateSpace: .global` plus a drag-start anchor.

## Upstream findings for GlassEditorKit (to land in the package)

1. **Gutter overlay must clip internally.** In a height-capped frame the line-number overlay draws past the editor's bounds (macOS no-clip default); consumers currently need `.clipped()`. glas.sh (M4) will hit this in any sheet.
2. INTEGRATION.md A1/A3/A4 line references drifted before adoption began (glassdb's 2026-08-11 gutter/focus rework); the A3 parity list's behaviors held but the citations are stale, and glassdb's newer gutter behaviors (visible band, digit-count sizing, draw-before-super) are now part of the Phase 2 parity bar.

## Evidence (final state)

- Mac 123/123; iPhone/iPad/Vision Pro matrix on the final revision recorded in the PR; GlassEditorKit package suite 297 green in 33 suites (1 recorded known issue).
- New `glassEditorModelMirrorsJSONStagingSemantics` test exercises the package inside glassdb's test host.
- Live function-verified: connect, query, highlighted JSON with green strings/amber numbers, header Format/Validate, pill resize.

## Remaining phases (INTEGRATION.md Part D order)

- [ ] Phase 2: DDL display (`TableDetailView` read-only highlight consumer)
- [ ] Phase 3: the SQL editor surface (replace `HighlightedTextEditor`; keep `SQLHighlighter` as policy per D-008; attach providers)
- [ ] Phase 4: `SQLHighlighter` seam via `StatementBoundaryProvider`
