# Workspace Tab Strip Hidden Under Titlebar Backgrounds (Mac)

**Status:** Merged to `main` 2026-09-04 (`911e06d`), followed by the titlebar-material correction on `agent/workspace-titlebar-material` the same day. Signed Release installed to /Applications.
**Discovered by:** Human dogfooding — the workspace tab strip showed as an empty 40pt band above the breadcrumb (screenshot 2026-09-02 20:07); the 2026-08-20 handoff's "dead band under the titlebar with the sidebar collapsed" and "reload/sidebar buttons mid-titlebar" are the same defect
**Scope:** `MacDatabaseWorkspaceWindowPolicy` only; no view-tree changes

## Diagnosis

- Accessibility inspection of the live window showed the strip laid out in its 40pt band with all four tab buttons at real sizes, while a pixel capture of that band was bare canvas. The strip was present and interactive but painted over.
- Hosting the real `DatabaseWorkspaceView` offscreen and dumping the AppKit hierarchy revealed two private `NSTitlebarBackgroundView`s, one per split column, that `NavigationSplitView` places at the top 40pt of its `NSSplitView`. SwiftUI assumes the split view extends under the toolbar (`.fullSizeContentView`). The policy removed that style, so the split view began *below* the toolbar and the titlebar backgrounds landed on the tab strip instead of under the toolbar.
- Reproduced in a debug build driven through accessibility with a throwaway SQLite connection: collapsing the sidebar dimmed the tabs to ghosts and moved the reload/sidebar toolbar buttons mid-titlebar; re-expanding restored them. The fully blank expanded state from the screenshot was not reproduced from a fresh launch, but shares the overlay mechanism.

## Fix

- `MacDatabaseWorkspaceWindowPolicy.apply` now inserts `.fullSizeContentView` and sets `titlebarAppearsTransparent = true`, mirroring glas.sh's `MacTerminalWindowPolicy` (`Platforms/macOS/MacTerminalWindowPolicy.swift`). The hand-built `MacDatabaseWorkspaceTitlebarMaterialView` stays, re-anchored: under full-size content `contentView.top` coincides with the window top, so its bottom now follows `window.contentLayoutGuide.topAnchor` (the titlebar/toolbar band) and it can never reach the tab strip.
- Verified live in the debug build: tabs render with the sidebar expanded, collapsed (tabs at the leading edge, toolbar buttons leading), and re-expanded.

## Evidence

- New regression test `workspaceTitlebarBackgroundsStayOutOfTheContentLayoutRect` hosts the real workspace with a connected in-memory SQLite session under the policy and asserts no titlebar background intersects `window.contentLayoutRect`; `macDatabaseWorkspacePolicyPreservesInteractiveNativeChrome` asserts the new style contract.
- Full macOS suite on the branch: 136/136. Against the old policy the same suite fails exactly the two policy tests (134/136), so the guard is real.
- iOS simulator build was verified only on `agent/ios-required-field-label`; this branch inherits a pre-existing iOS compile error from main until that lands.

## Correction (2026-09-04)

- The first merge deleted the titlebar material view outright. Dogfooding immediately showed the desktop wallpaper through the titlebar band: the window is non-opaque with a clear background, so with `titlebarAppearsTransparent` AppKit draws nothing behind the toolbar. The material was never redundant; only its anchor was wrong. Restored and anchored to the content layout guide; `macDatabaseWorkspacePolicyPreservesInteractiveNativeChrome` now also asserts the material has height and stays outside `contentLayoutRect`. Verified in the debug build: titlebar band composites at the canvas's alpha with the sidebar expanded and collapsed; tabs and toolbar placement unchanged. Mac 136/136.

## Follow-ups

- Breadcrumb navigation misbehavior from the 2026-08-20 handoff remains open and separate.
- Grid rows paint above the results header (visible in the dogfood screenshot as rows 6–7 behind `created_at`); separate clipping defect, not addressed here.
