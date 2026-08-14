# GlassEditorKit Adoption (M3)

**Status:** Phases 1–3 complete. Phase 1 (JSON field) approved 2026-08-13. Phases 2–3 (DDL decision + the SQL editor) implemented and human-approved 2026-08-14 on `agent/glasseditorkit-m3-phase2` after an intensive live-review loop. The `StatementBoundaryProvider` seam is wired; `SQLHighlighter` remains whole per D-008.
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

## Phase 2–3 record (2026-08-14)

- **DDL display**: kept `SQLHighlighter.highlight` (D-008 keeps the tokenizer anyway; native text-selection copy behavior preserved; zero risk beats engine-consistency for a non-editing surface).
- **SQL editor**: `HighlightedTextEditor.swift` deleted; `GlassEditorAdapters.swift` provides the three provider pass-throughs (completion ranking, lint, statement boundaries — classification never leaves glassdb), the surface wrapper with A7 glass mapping (`.blur(strength:)`), focus-token behavior, and the platform representables over the package's public engines.
- **The binding-bridge saga** (three repair rounds, each producing a guard test): (1) SwiftUI `.onChange` outbound sync never fired in the alive-ZStack workspace → replaced with direct `withObservationTracking`; (2) schema identifiers were empty on table tabs — a pre-existing gap from the unification merge (`completionIdentifiers = []` hardcoded) — fixed with a shared loader for both surfaces; (3) diff-based inbound sync reverted user keystrokes under State-commit batching (editor read-only) → architecture inverted: the model is the single source of truth, `update*View` applies no content diffs, all external writers route through the imperative `SQLEditorController` choke points. A deferred-commit harness test pins the round-3 failure mode.
- **Editor features added during live review**: dotted-reference completion (`db.table` qualified candidates), Tab-accepts-top-suggestion (guarded local key monitor), ghost-text preview of the pending completion (caret-anchored `CATextLayer`), horizontal scrolling for long lines, selection-aware Format (control bar + compact iOS layout), and the suggestion pills relocated to a bottom overlay inside the editor (gutter-aware leading inset via `EditorMetrics.gutterWidth`, edge fades, zero layout reflow).
- **Platform reach**: bar/pills/Format/insets are shared SwiftUI; UIKit honors no-wrap natively. Tab-accept and ghost preview are macOS-only pending package key/inline-suggestion hooks.

## Upstream findings for GlassEditorKit (Phase 2 additions)

3. The engine's deferred model-revision sync restores the pre-replace caret, clobbering selections applied between — consumers must call `syncTextViewFromModel` synchronously; an atomic replace-with-selection API would remove the footgun.
4. No key-command hook on the text view (Tab interception needs a consumer-side NSEvent monitor; blocks iPad hardware-keyboard Tab-complete).
5. No inline-suggestion surface (ghost text is a consumer-side layer).
6. `hasHorizontalScroller` is hardcoded false even when `wrapsLines == false` — long lines clip until the consumer overrides.

## Remaining

- [ ] Phase 4 cleanup: exercise `StatementBoundaryProvider` end-to-end once the package consumes spans for anything user-visible
- [ ] Lazy per-qualifier table completion for non-focus databases (typing `otherdb.` currently completes nothing; prefetching 391 databases is not sane)
