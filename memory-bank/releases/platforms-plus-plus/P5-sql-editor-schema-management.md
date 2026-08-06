# P5: SQL Editor and Schema Management

**Status**: in progress — shared SQL/schema implementation and automated safety regression complete; physical editor/accessibility acceptance remains
**Goal**: G5
**Depends on**: P2-P4

## Objective

Deliver a premier daily-driver SQL and schema experience using native text, navigation, inspector, menu, document, undo, and accessibility behavior while preserving glassdb’s database-specific intelligence and safety.

## SQL Editor Native Feasibility

- [ ] Prototype SwiftUI `TextEditor` with `AttributedString` and attributed selection for syntax highlighting.
- [ ] Verify selection preservation during token recoloring, formatting, completion, diagnostics, and external query injection.
- [ ] Adopt native find/replace, undo/redo, copy/paste, drag/drop, dictation behavior, keyboard selection, and text services.
- [ ] Disable autocorrection, capitalization, smart punctuation, and Writing Tools rewriting for executable SQL.
- [ ] Verify monospaced Dynamic Type, line wrapping, scrolling, large documents, multiple selections where applicable, and VoiceOver.
- [ ] Test native document APIs/file import/export for SQL documents without changing query-history semantics.

Retain a UIKit/AppKit editor bridge only if native TextEditor cannot provide required live syntax attributes, selection fidelity, line numbers, completion positioning, or diagnostic overlays. Any bridge must use standard text-system behavior rather than a custom editor engine.

## Query Environment

- [ ] Preserve parser-backed statement selection, Command-Return execution, formatting, history, saved queries, explain, limits, timeout/cancel semantics, and AI draft-only safety.
- [ ] Provide native iPad menu bar commands and keyboard discoverability.
- [ ] Provide touch-accessible Run/Stop, history, saved-query, format, and explain actions without overcrowding the iPhone toolbar.
- [ ] Use OS 27 overflow/priority only as an enhancement; retain a native OS 26 arrangement.
- [ ] Keep errors copyable, actionable, private, and accessible; connection loss must be intercepted before execution when known.

## Schema and Database UX

- [ ] Reuse the native database overview and Swift Charts, adapting layout with `Grid`, `ViewThatFits`, and system containers.
- [ ] Keep database → table hierarchy native and searchable.
- [ ] Make a table tap default to Data; database tap opens the operational overview.
- [ ] Present Structure, DDL, Indexes, and Foreign Keys through contextual navigation/toolbars appropriate to device width.
- [ ] Use iPad inspector for column/index/foreign-key editing and iPhone navigation destinations for long forms.
- [ ] Preserve SQL preview, capability gates, confirmation, server error propagation, refresh, and rollback semantics.

## Editor Loop

`NATIVE TEXT SPIKE → LIVE HIGHLIGHT → SELECTION/UNDO/FIND → COMPLETION/DIAGNOSTIC → LARGE FILE → INPUT/ACCESSIBILITY → KEEP OR EXCEPTION`

## Exit Criteria

- [ ] Editor architecture has an evidence-backed native or minimal-bridge decision.
- [ ] SQL editing remains daily-driver capable on touch and hardware keyboard.
- [ ] No editor feature bypasses mutation classification or confirmation policy.
- [ ] Database dashboard and schema tools adapt without custom system chrome.
- [ ] iPhone avoids nested tab bars and iPad uses inspectors/windows appropriately.

## Evidence Log

| Date | Editor/Schema Scenario | Result | Native API/Exception | Evidence |
|---|---|---|---|---|
| 2026-07-21 | Compact database → table navigation | Pass (compile) | Native `List`, `NavigationLink`, `navigationDestination`, toolbar `Menu`, and searchable hierarchy | `SchemaBrowserView.swift:176` selects the compact hierarchy and `SchemaBrowserView.swift:189` implements database drill-in; iPhoneOS 27 arm64 build succeeded. |
| 2026-07-21 | Table default action and secondary schema actions | Pass (compile) | Table tap selects Data; copy, refresh, and destructive operations use native contextual actions | `SchemaBrowserView.swift:212` presents the compact table list and the shared native table action menu; generic visionOS 27 regression build also succeeded. |
| 2026-07-21 | SQL editor safety and document behavior | Pass (automated) | Retained minimal UIKit/AppKit text-system bridge because live syntax attributes, line numbers, caret completion placement, and selection fidelity are not supplied together by SwiftUI `TextEditor`; native undo/copy/paste/text services remain underneath | Parser, selection, formatter, completion, bounded results, document byte recheck, history redaction, mutation classification, and error-presentation tests passed in all five 101-test suites. |
| 2026-07-21 | Database overview and schema mutation | Pass (automated) | Native `List`, navigation, Charts, forms, menus, preview, confirmation, and capability gates | Overview statistics, table destinations, MySQL/PostgreSQL/SQLite schema SQL generation, identifier/type validation, primary/generated protections, and rollback/error propagation tests passed. |
