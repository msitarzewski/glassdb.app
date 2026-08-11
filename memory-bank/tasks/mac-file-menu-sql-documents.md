# Mac File Menu Owns SQL Document Lifecycle

**Status:** Complete — implemented and human-approved 2026-08-11 on `agent/overview-stats-filemenu-gutter`. File menu owns New SQL Document ⌘N, New Connections Window ⌘⇧N, Open ⌘O, Save ⌘S, and Close Active Tab; Query keeps execution verbs. The workspace is the single focused-scene publisher (per-document handler registration), fixing the multi-editor ⌘O/⌘S defect — verified live with two editors. Focus follows new documents via a focus-token claim.
**Discovered by:** Human testing of the seed-only-Overview / ⌘N change (same session, uncommitted)
**Scope:** Route ⌘N correctly and move SQL document management (New/Open/Save/Close) into the Mac File menu per the macOS Human Interface Guidelines.

## Defect (current uncommitted state)

- ⌘N always opens a new Connections window, everywhere. The Query menu's "New Query Tab" item declares ⌘N but never receives it.
- Cause: "New Connections Window ⌘N" is the **system-generated** File > New item SwiftUI creates for the primary `WindowGroup("Connections", id: "main")` at `glassdb/glassdbApp.swift:35`. It is always enabled, and File-menu key-equivalent matching precedes the Query menu, so it captures ⌘N unconditionally.
- The workspace-level `newQueryTab` action (`DatabaseWorkspaceCommandActions`, `glassdb/Constants.swift`; published at `glassdb/DatabaseWorkspaceView.swift:255`) is correct and should be retained — only the menu placement/shortcut routing is wrong.
- Interim stopgap (2026-08-11, human-approved): the Query-menu item is back on ⌘T, wired through the workspace-level `newQueryTab` action, so a menu-bar shortcut works with zero SQL tabs open. ⌘N remains captured by the system File item until this task replaces the `.newItem` group. The in-editor button's local ⌘T (`glassdb/QueryEditorView.swift:534`) duplicates the menu shortcut harmlessly in the interim.

## Related Defect: Query-menu document actions die with two or more editors alive (2026-08-11, pre-existing on main)

- Human-reported: ⌘O (Open SQL Document…) worked once, then stopped; the ⌘W save/don't-save prompt kept working.
- Mechanism: every SQL tab's `QueryEditorView` stays alive in the workspace ZStack (hidden at opacity 0) and each publishes the same scene value — `focusedSceneValue(\.databaseCommandActions, isWorkspaceActive ? commandActions : nil)` at `glassdb/QueryEditorView.swift:545`. With one editor there is one publisher and the Query menu works; once a second editor exists (exactly what opening a document creates), hidden instances publish `nil` into the same key and SwiftUI's resolution among competing publishers is focus-dependent, so `actions` resolves nil and every `actions`-backed item (Open ⌘O, Save ⌘S, menu Execute) goes dead.
- Proof of shape: `databaseWorkspaceCommandActions` has exactly one publisher (`glassdb/DatabaseWorkspaceView.swift:255`) and its items (⌘T new tab, ⌘W close) never failed.
- Both halves predate `agent/command-w-editor-close` (merged in PR #8); `QueryEditorView.swift` is untouched on that branch.
- Fix folds into this task: make the workspace the **single publisher** for document verbs too — route open/save/execute-target through workspace-owned actions that delegate to the active document, and stop publishing `databaseCommandActions` from editor instances.

## Direction (per macOS HIG: File menu owns document lifecycle)

1. Replace the system item via `CommandGroup(replacing: .newItem)` in the `.commands` block at `glassdb/glassdbApp.swift:44`:
   - **File > New SQL Document ⌘N** — calls the focused workspace's `newQueryTab`; disabled when no workspace scene is focused.
   - **File > New Connections Window ⌘⇧N** (or retain ⌘N only when the library window is focused) — explicit `openWindow(id: "main")` replacement for the system item.
2. Relocate document verbs from the Query menu into File: "Open SQL Document… ⌘O", "Save SQL Document… ⌘S", and tab close alongside the existing Command-W routing. Query menu keeps execution verbs (Execute, Explain, Cancel, History, Saved Queries, Format).
3. Reconcile with the branch's Command-W router (`MacDatabaseCommandWRouter`) so File > Close and workspace tab close remain one coherent surface.
4. Decide fate of the in-editor ⌘T duplicate at `glassdb/QueryEditorView.swift:534` (likely remove in favor of the single File-menu shortcut).
5. Keep iPhone/iPad/Vision Pro behavior unchanged; this is Mac menu-bar surface only (`DatabaseCommands` is already `#if os(macOS)`).

## Acceptance Sketch

- Workspace window focused: ⌘N creates an Untitled SQL tab; library window focused: ⌘N (or ⌘⇧N per chosen design) opens/raises the Connections window; no shortcut is silently swallowed.
- File menu shows the document lifecycle for SQL documents; Query menu contains no document-management items.
- Existing Mac suite stays green; add focused coverage for the command-routing surface where testable.
