# Quick Start

## Key Commands
- Build: Open `glassdb.xcodeproj`, select visionOS Simulator, ⌘R
- Test: ⌘U in Xcode

## Pattern Reference (from glas.sh)
- Database workspace: `.windowStyle(.plain)` with persisted opacity/blur; general windows use system materials
- Multi-window: `Window` (singleton) or `WindowGroup(id:, for: UUID.self)` (multi-instance)
- State: `@Observable` class + `@Environment()` injection
- Keychain: GlasSecretStore; current `WhenUnlockedThisDeviceOnly` records share across authorized apps on one device, while eligible-secret cross-device sync remains C3 work
- Window tracking: `WindowPresenceTrackingModifier` (onAppear/onDisappear lifecycle)

## Sister Project
glas.sh repo: https://github.com/msitarzewski/glas.sh
