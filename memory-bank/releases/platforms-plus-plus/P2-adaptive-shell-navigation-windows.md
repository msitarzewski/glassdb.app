# P2: Adaptive Shell, Navigation, and Windows

**Status**: in progress — automated iPhone/iPad/Mac/Vision navigation and scene regression green; physical iPad resize/input/restoration acceptance remains
**Goal**: G2
**Depends on**: P1

## Objective

Deliver platform-native information architecture: a focused compact iPhone flow and a resizable, multiwindow iPad productivity shell using system navigation, tabs, windows, menus, and restoration.

## iPhone Plan

- [x] Use `NavigationStack` for the connection library and drill-in detail.
- [ ] Define no more than a small stable set of top-level connected areas, expected to be Overview, Browse, and SQL, using native `TabView` only if user testing confirms these are true peers.
- [ ] Keep table Data/Structure/DDL/Indexes/Foreign Keys as contextual navigation or toolbar modes, not a nested tab bar.
- [ ] Make the first connected screen the connection/server overview, not an empty query editor.
- [ ] Preserve back behavior, navigation titles, state restoration, and deep-link safety.
- [ ] Support portrait and landscape without requiring rotation instructions.

## iPad Plan

- [x] Use `NavigationSplitView` for schema navigation and workspace detail.
- [ ] Use `preferredCompactColumn` so narrow/resized windows collapse predictably.
- [ ] Use system sidebar visibility and edge-swipe behavior; do not add a competing gesture.
- [ ] Preserve at most two visible hierarchy levels in the sidebar; place deeper data in content/detail navigation.
- [ ] Support multiple per-connection workspace windows with `WindowGroup(for:)` and native activation.
- [ ] Restore selected connection, workspace, tab/destination, sidebar visibility, and safe query drafts per scene.
- [ ] Add iPad menu bar commands by reusing existing command actions rather than leaving `.commands` macOS-only.
- [ ] Verify system window controls, safe areas, resizing, full screen, and windowed multitasking.

## Workspace Tabs

- [ ] Run a native `TabView`/`Tab` feasibility spike for dynamic SQL/database/table workspaces, close, reorder, selection, restoration, and Command-W.
- [ ] Prefer system tab customization/reordering and context actions.
- [ ] If inline close buttons or arbitrary document tabs remain essential and unsupported, document the exception and keep the smallest possible custom content layer without replacing the system toolbar/tab bar.

## Navigation Loop

Test each meaningful state at these widths:

`iPHONE PORTRAIT → iPHONE LANDSCAPE → iPAD NARROW → iPAD HALF → iPAD LARGE → iPAD MULTIWINDOW → MAC → VISION`

At each width verify orientation, title, primary action, back/sidebar control, selection, and restoration.

## Exit Criteria

- [ ] No squeezed desktop sidebar or ornament appears on iPhone.
- [ ] iPad continuously adapts across window sizes without clipped or overlapping chrome.
- [ ] Multiple iPad windows can target the same connection without sharing scene-local navigation state incorrectly.
- [ ] Menu bar, keyboard shortcuts, sidebar commands, and restoration behave as system users expect.
- [ ] Mac and Vision multiwindow behavior remains intact.

## Evidence Log

| Date | Layout/Window Scenario | Result | Evidence |
|---|---|---|---|
| 2026-07-21 | iPhone compact connection library and drill-in detail | Pass (compile) | `ConnectionManagerView.swift:149` selects `NavigationStack` for compact width and preserves `NavigationSplitView` at regular width; iPhoneOS 27 arm64 build succeeded. Runtime navigation QA remains open. |
| 2026-07-21 | iPhone primary workspace and Settings routing | Pass (compile) | `ConnectionManagerView.swift:674` routes phone workspaces through the single-scene router while iPad retains native windows; iPhoneOS 27 arm64 build succeeded. |
| 2026-07-21 | Mac and Vision regression compile | Pass (compile) | macOS 27 test target built successfully; generic visionOS 27 arm64 build succeeded. The full Mac unit run had one reconnect lifecycle failure outside this UX slice, while the focused UX tests passed. |
| 2026-07-21 | Four-platform integrated regression | Pass (automated) | macOS, iPhone 17 Pro, iPad Pro 13-inch, visionOS 26.5, and visionOS 27 each passed the 101-test app suite. Workspace window identity, tab isolation/close fallback, overview routing, and session ownership cases passed. |
| 2026-07-21 | iPhone/iPad visual smoke | Pass (simulator) | Native compact connection stack and regular split-view empty state launched and were visually inspected through Simulator captures. Physical resize, pointer, menu-bar, and restoration acceptance remains a device gate. |
| 2026-08-09 | Adaptive database connection library | Pass (automated) | One saved catalog now projects All/Favorites/Recent/Collections and search into iPhone stack, Mac/iPad split, and Vision mode-tab/spatial layouts. Final suites passed Mac 105/105 and iPhone/iPad/Vision 103/103 each; physical interaction acceptance remains open. |
