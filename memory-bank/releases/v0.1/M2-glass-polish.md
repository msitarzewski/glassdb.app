# M2: Glass Polish

**Status**: Not Started
**Depends on**: M1 (end-to-end flow)
**Prerequisite for**: M3

## Goal
The app looks and feels like a native visionOS glass-first spatial app, not a flat SwiftUI prototype in a floating window.

## Tasks

### Glass Materials
- [ ] Apply `.background(.ultraThinMaterial, in: .rect(cornerRadius: 24))` to all window root views
- [ ] ConnectionManagerView — sidebar glass, detail pane glass
- [ ] QueryEditorView — editor area glass, toolbar glass
- [ ] ResultsGridView — grid area glass with subtle row alternation
- [ ] SchemaBrowserView — tree/list glass
- [ ] SettingsView — form glass

### Ornament Chrome
- [ ] Connection status ornament on Query Editor (connected/disconnected indicator, DB name)
- [ ] Toolbar ornament on Query Editor (Execute, Format, History buttons)
- [ ] Results count ornament on Results Grid (row count, execution time)
- [ ] Session selector ornament on Schema Browser

### Spatial Layout
- [ ] Default window positions that make spatial sense (editor center, schema right, results left)
- [ ] Window sizing refinement for each window type
- [ ] Consistent corner radii and padding across all windows

### Visual Polish
- [ ] Connection color tags visible in sidebar (dot indicator)
- [ ] Favorite connections pinned to top of list
- [ ] Connection state indicators (green dot = connected, spinner = connecting, red = error)
- [ ] Smooth transitions between connection states

## Reference
- glas.sh `TerminalWindowView.swift:41` — glass material pattern
- glas.sh `glas_shApp.swift` — `.windowStyle(.plain)` on all scenes
