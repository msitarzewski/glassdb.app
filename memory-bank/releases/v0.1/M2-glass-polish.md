# M2: Glass Polish

**Status**: Done (2026-03-15, PR #1 merged)
**Depends on**: M1 (end-to-end flow)
**Prerequisite for**: M3

## Goal
The app looks and feels like a native visionOS glass-first spatial app, not a flat SwiftUI prototype in a floating window.

> **Note**: Liquid Glass migration was completed via the visionOS 26 SDK migration PR (#1), which brought the app to full visionOS 26 compliance with Liquid Glass ornaments and updated material APIs.

## Tasks

### Glass Materials
- [x] Apply `.background(.ultraThinMaterial, in: .rect(cornerRadius: 24))` to all window root views
- [x] ConnectionManagerView — sidebar glass, detail pane glass
- [x] QueryEditorView — editor area glass, toolbar glass
- [x] ResultsGridView — grid area glass with subtle row alternation
- [x] SchemaBrowserView — tree/list glass
- [x] SettingsView — form glass

### Ornament Chrome
- [x] Connection status ornament on Query Editor (connected/disconnected indicator, DB name)
- [x] Toolbar ornament on Query Editor (Execute, Format, History buttons)
- [x] Results count ornament on Results Grid (row count, execution time)
- [x] Session selector ornament on Schema Browser

### Spatial Layout
- [x] Default window positions that make spatial sense (editor center, schema right, results left)
- [x] Window sizing refinement for each window type
- [x] Consistent corner radii and padding across all windows

### Visual Polish
- [x] Connection color tags visible in sidebar (dot indicator)
- [x] Favorite connections pinned to top of list
- [x] Connection state indicators (green dot = connected, spinner = connecting, red = error)
- [x] Smooth transitions between connection states

## Reference
- glas.sh `TerminalWindowView.swift:41` — glass material pattern
- glas.sh `glas_shApp.swift` — `.windowStyle(.plain)` on all scenes
