# Quick Start

## Key Commands
- Build: Open `glassdb.xcodeproj`, select visionOS Simulator, ⌘R
- Test: ⌘U in Xcode

## Pattern Reference (from glas.sh)
- Glass window: `.windowStyle(.plain)` + `.background(.ultraThinMaterial, in: .rect(cornerRadius: 24))`
- Multi-window: `Window` (singleton) or `WindowGroup(id:, for: UUID.self)` (multi-instance)
- State: `@Observable` class + `@Environment()` injection
- Keychain: Security framework, `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`
- Window tracking: `WindowPresenceTrackingModifier` (onAppear/onDisappear lifecycle)

## Sister Project
glas.sh repo: https://github.com/msitarzewski/glas.sh
