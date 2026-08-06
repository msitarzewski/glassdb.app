# P7: iOS/iPadOS 27 Enhancements and Platform Polish

**Status**: in progress — high-value guarded priority adopted and OS 27 regression green; local iOS 26 runtime comparison remains unavailable
**Goal**: G7
**Depends on**: P2-P6

## Objective

Adopt the 2027-release SwiftUI capabilities that materially improve glassdb while preserving a fully native, tested iOS/iPadOS 26 fallback.

## OS 27 Enhancements

- [x] Apply toolbar `visibilityPriority` so Run/Stop, Save/Done, and recovery actions survive resizing.
- [ ] Use `toolbarOverflowMenu` for permanently secondary commands rather than a hand-built More button.
- [ ] Use `.topBarPinnedTrailing` for the one critical trailing action where appropriate.
- [ ] Evaluate `toolbarMinimizeBehavior` for long result/schema scrolling; use only if controls remain discoverable and safe.
- [ ] Use reorderable container APIs for user-reorderable workspace/schema items when the underlying state supports deterministic persistence.
- [ ] Use arbitrary-view swipe actions only where they match the action’s object and remain available elsewhere.
- [ ] Evaluate new Document APIs for large SQL documents only if they improve safety/performance without forking OS 26 behavior.
- [ ] Apply State/ContentBuilder migration guidance where it improves correctness/build performance.

## Platform Polish

- [ ] Confirm standard controls adopt the current design without custom backgrounds.
- [ ] Remove custom toolbar/sidebar/tab material that interferes with Liquid Glass.
- [ ] Keep data content visually subordinate to system chrome while respecting database-workspace appearance settings on Mac/Vision.
- [ ] Use SF Symbols with semantic rendering and accurate labels/tooltips.
- [ ] Verify pointer lift/highlight effects come from native controls.
- [ ] Verify search placement, scope, suggestions, and compact behavior follow current system patterns.

## Availability Loop

For each OS 27 API:

`ADD GUARDED ENHANCEMENT → RUN OS 27 → RUN OS 26 FALLBACK → RESIZE/INPUT/ACCESSIBILITY → KEEP OR REMOVE`

An enhancement that degrades the OS 26 path or duplicates system behavior is removed.

## Xcode 27 SDK Audit and Recommendation

Audited 2026-07-21 against installed Xcode 27.0 (`27A5209h`) and the iOS, macOS, and visionOS 27.0 SDKs. The project deployment floors remain iOS/iPadOS 26.0, macOS 27.0, and visionOS 26.0, so every iOS/visionOS 27 adoption below requires an availability branch with the existing native implementation retained as fallback.

### Adopt after P2-P6 integration stabilizes

1. **Toolbar visibility priority — high value.** `ToolbarItemVisibilityPriority` and `ToolbarContent.visibilityPriority(_:)` are iOS 27.0, macOS 26.1, watchOS/tvOS/visionOS 27.0; the useful `.high` and `.low` values are iOS 27.0 and macOS 26.1 only. Extend the existing `databaseHighVisibilityPriority()` helper so Execute and the active Cancel/Recovery action receive `.high` on iOS 27. The iOS 26 fallback remains the existing `ToolbarItem` placement unchanged. This directly improves safety and discoverability under iPad window resizing.
2. **System toolbar overflow — high value.** `toolbarOverflowMenu(content:)` and `ToolbarOverflowMenu` are iOS 27.0 and visionOS 27.0, unavailable on macOS/tvOS/watchOS. Move permanently secondary SQL actions—document open/save, history, saved queries, formatting, tab management—into system overflow on iOS 27 while retaining the current native `Menu` on iOS 26. Execute and Cancel must remain visible rather than entering overflow.
3. **Prevent execution controls from minimizing — high safety value.** `toolbarMinimizeBehavior(_:for:)` is any-Apple-OS 27, while `.never`, `.onScrollDown`, and `.onScrollUp` are unavailable on macOS, tvOS, watchOS, and visionOS. Apply `.never` only to iOS query and mutation workspaces after device QA. The OS 26 fallback is the current non-minimizing native toolbar. Do not use scroll-triggered minimization for Run, Stop, Save, or destructive actions.
4. **Transferable clipboard integration — medium value.** The `copyable`, `cuttable`, and Transferable `pasteDestination` overloads are iOS 27.0 and macOS 13.0, unavailable on visionOS/tvOS/watchOS. Apply them only to focused result/record selections so hardware-keyboard Edit commands and drag/drop use the system pipeline. Keep existing explicit Copy buttons, `PasteButton`, and pasteboard handling as the iOS 26 and visionOS fallback.

### Defer or reject for this release

- **`topBarPinnedTrailing`** is iOS/visionOS 27.0 only. It duplicates the planned high visibility priority for Run/Stop and would split execution placement between top and bottom toolbars. Reject unless resize QA proves priority alone insufficient.
- **Reorderable containers** (`reorderable`, `reorderContainer`, `ReorderDifference`) are iOS/macOS/watchOS/visionOS 27.0. Defer until workspace ordering has deterministic persistence, undo, and scene restoration; adding gesture-only reorder now would create state loss.
- **`swipeActionsContainer` and the presentation callback overload** are iOS/macOS/watchOS/visionOS 27.0. Existing connection, SSH-key, and compact record actions already live in native `List` rows and remain discoverable elsewhere. Adoption would add no user capability today.
- **Async Observation document protocols** (`Document`, `ReadableDocument`, `WritableDocument`, `DocumentReader`, `DocumentWriter`, `URLDocumentConfiguration`) are iOS/macOS/visionOS 27.0. Current SQL import/export already enforces a 10 MiB limit, rechecks bytes read, uses security-scoped URLs, and uses native `fileImporter`/`fileExporter`. Migrating would fork the OS 26 document path without a demonstrated performance or safety win; revisit only if true large-document editing becomes a requirement.
- **`TabsPickerStyle.tabs`** is iOS/macOS/tvOS/visionOS 27.0. The five table modes are contextual destinations, not peer app tabs; using it risks the nested-tab hierarchy P2 explicitly avoids. Keep the native compact `Menu` and regular-width controls.
- **`CrossFadeNavigationTransition` and type-erased `AnyNavigationTransition`** are OS 27 additions but provide polish without improved task completion, safety, or discoverability. Reject as novelty.
- **State/ContentBuilder migration-only declarations** expose compiler/framework plumbing but no current correctness problem or user-visible benefit. Do not churn stable view state solely to consume them.

## Exit Criteria

- [ ] Every OS 27 API has an explicit availability guard and passing OS 26 fallback.
- [ ] Toolbar behavior is system-managed at every width.
- [ ] No custom material conflicts with system Liquid Glass.
- [ ] Enhancements improve discoverability, adaptivity, or performance rather than existing for novelty.
- [ ] Mac/Vision appearance and toolbar regressions are absent.

## Evidence Log

| Date | API/Enhancement | OS 27 Result | OS 26 Fallback | Decision |
|---|---|---|---|---|
| 2026-07-21 | `ToolbarContent.visibilityPriority(_:)` / `.high` | Declared at `SwiftUI.swiftinterface:13288-13323`; maps directly to Execute at `QueryEditorView.swift:389-402` | Existing toolbar placement via `databaseHighVisibilityPriority()` returning `self` on iOS | Adopt after integration; highest value |
| 2026-07-21 | `toolbarOverflowMenu(content:)` | iOS/visionOS 27 declaration at `SwiftUI.swiftinterface:31449-31462`; current SQL secondary actions are at `QueryEditorView.swift:438-501` | Existing native Queries `Menu` | Adopt selectively; never overflow Run/Stop |
| 2026-07-21 | `toolbarMinimizeBehavior(.never, for:)` | Declared any-Apple-OS 27 at `SwiftUI.swiftinterface:14082-14109`; `.never` is iOS-only | Current OS 26 toolbar behavior | Adopt only for execution/mutation workspaces after device QA |
| 2026-07-21 | `copyable` / `cuttable` / Transferable `pasteDestination` | iOS 27, macOS 13 declarations at `SwiftUI.swiftinterface:13820-13844` | Existing Copy actions, `PasteButton`, and `PlatformClipboard` | Adopt for focused grid selections; preserve explicit controls |
| 2026-07-21 | `.topBarPinnedTrailing` | iOS/visionOS 27 declaration at `SwiftUI.swiftinterface:7877-7882` | Existing `.primaryAction` / bottom-bar placement | Defer; currently redundant |
| 2026-07-21 | Reorderable container APIs | iOS/macOS/watchOS/visionOS 27 declarations at `SwiftUI.swiftinterface:12827-12929` | Existing stable, non-reorderable workspace order | Defer until persisted ordering exists |
| 2026-07-21 | `swipeActionsContainer` / presentation callback | iOS/macOS/watchOS/visionOS 27 declarations at `SwiftUI.swiftinterface:21246-21258` | Existing native List swipe actions | Reject for now; no missing capability |
| 2026-07-21 | Async `Document` protocols | iOS/macOS/visionOS 27 declarations at `SwiftUI.swiftinterface:1752-1982` | Current bounded `FileDocument`, `fileImporter`, and `fileExporter` path | Defer; OS split adds cost without measured gain |
| 2026-07-21 | `.pickerStyle(.tabs)` | iOS/macOS/tvOS/visionOS 27 declaration at `SwiftUI.swiftinterface:16619-16631` | Current compact Menu and contextual navigation | Reject for table modes; risks nested-tab UX |
| 2026-07-21 | Execute visibility priority adoption | `databaseHighVisibilityPriority()` applies `.visibilityPriority(.high)` on iOS 27 | Helper returns the unchanged toolbar content on iOS 26 | Adopted; iPhone and visionOS 27 101-test regressions passed. An iOS 26 simulator runtime is not installed, so physical/runtime fallback acceptance remains open. |
