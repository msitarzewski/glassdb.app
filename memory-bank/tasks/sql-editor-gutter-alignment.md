# SQL Editor Gutter Alignment on Mac

**Status:** To do — filed 2026-08-11 from human visual review on `agent/command-w-editor-close`
**Discovered by:** Human testing of the table Data surface; the SQL editor's text appears to start far right of everything below it
**Scope:** Make the SQL editor's line-number gutter read as an intentional region and align the editor's leading edge with the rest of the workspace surface on Mac.

## Diagnosis (2026-08-11)

- Line numbers default to on (`glassdb/SettingsManager.swift:117`) and flow into the table Data editor (`glassdb/TableDetailView.swift:1446`).
- With line numbers enabled, the Mac `LineNumberTextView` sets `textContainerInset = NSSize(width: 56, height: 12)` (`glassdb/HighlightedTextEditor.swift:394`, `updateTextInset()`), so SQL text starts 56pt in while the control bar and results grid below sit at ~12pt leading — a ~44pt visual mismatch.
- The gutter is invisible: the number is drawn in `secondaryLabelColor` at reduced size, right-aligned before the text (`glassdb/HighlightedTextEditor.swift:385`), with no background tint or separator. A one-line query shows a single faint "1", so the region reads as accidental empty margin.
- AppKit `NSTextView.textContainerInset` is symmetric — the 56pt is applied to the trailing edge too, adding dead right-side space nothing else on the surface has. The iOS path is already asymmetric (`UIEdgeInsets` `left: 56/12, right: 12`, `glassdb/HighlightedTextEditor.swift:184-186`), so this is Mac-only.
- The 56pt width is fixed regardless of digit count and aligns with nothing else in the surface.

## Direction (reuse `LineNumberTextView`; no new views)

1. Give the gutter a visible treatment — subtle background tint plus hairline separator — matching the visual language of the results grid's frozen row-number column directly below it.
2. Make the Mac inset asymmetric (leading gutter width, ~12pt trailing), e.g. via a `textContainerOrigin` override or an `NSRulerView`-based gutter, mirroring the existing iOS behavior.
3. Size the gutter to the current digit count (with a sane minimum) instead of fixed 56pt.
4. Apply identically everywhere `HighlightedTextEditor` is used (table Data surface and SQL documents) so the canonical editor keeps one look.
5. Keep the `showLineNumbers` setting semantics unchanged; with numbers off the existing 12pt inset already aligns.

## Acceptance Sketch

- With line numbers on, the editor's text leading edge and the gutter's visual region align sensibly with the control bar and grid below; no unexplained trailing dead space on Mac.
- Line numbers are legible against the dark editor background rather than reading as empty margin.
- Mac and iPad/iPhone/Vision editors keep consistent behavior; existing editor tests (highlighting, selection preservation, font size) stay green.
