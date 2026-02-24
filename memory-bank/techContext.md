# Tech Context

## Stack
- **Platform**: visionOS 2.0+
- **Language**: Swift 6.2
- **UI**: SwiftUI + visionOS ornaments + glass materials
- **Database client**: mysql-nio (Vapor ecosystem, async NIO-based)
- **SSH tunneling**: Citadel (vendored, shared with glas.sh)
- **NIO**: swift-nio-ssh (vendored patched, shared with glas.sh)
- **State management**: @Observable (Observation framework), NOT ObservableObject
- **Persistence**: Keychain (passwords), UserDefaults/JSON (connections, settings)
- **IDE**: Xcode with visionOS SDK + visionOS Simulator

## Key Patterns (from glas.sh)
- `.windowStyle(.plain)` on all Scene declarations
- `.background(.ultraThinMaterial, in: .rect(cornerRadius: 24))` for glass panels
- `WindowPresenceTrackingModifier` for window lifecycle
- `Window` for singleton windows, `WindowGroup(for: UUID.self)` for multi-instance
- `NavigationSplitView` for sidebar + detail layouts
- Keychain via Security framework with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`

## Dependencies
- mysql-nio: https://github.com/vapor/mysql-nio (^1.0.0)
- Citadel: vendored local package
- swift-nio-ssh: vendored local package (patched for toolchain compat)
- Future: postgres-nio for PostgreSQL support
