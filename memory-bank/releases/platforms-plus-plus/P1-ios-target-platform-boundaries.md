# P1: iOS-Family Target and Platform Boundaries

**Status**: done
**Goal**: G1
**Depends on**: P0

## Objective

Make the existing shared native app target compile, launch, and package for iPhone and iPad at iOS/iPadOS 26.0+, without Catalyst and without allowing iOS to enter visionOS-only APIs.

## Work Plan

### Project and package settings

- [x] Add `iphoneos` and `iphonesimulator` to supported platforms.
- [x] Set `IPHONEOS_DEPLOYMENT_TARGET = 26.0` and device families `1,2` for Debug, Release, and tests.
- [x] Preserve native macOS and visionOS destinations and arm64 shipping requirements.
- [x] Add iPhone/iPad app icon, launch, orientation, local-network description, and platform metadata by reusing the canonical 1024-pixel Mac icon artwork.
- [x] Verify GlassDBKit, Citadel, swift-nio-ssh, mysql-nio, postgres-nio, NIOSSL, SQLite, and GlasSecretStore resolve and link for device and simulator.
- [x] Verify the slice introduces no new required-reason API or privacy-manifest diagnostic; no speculative manifest was added.

### Explicit platform boundaries

- [x] Replace ambiguous platform branches around platform-exclusive APIs with explicit macOS, visionOS, and iOS branches.
- [x] Restrict `.bottomOrnament`, `.windowStyle(.plain)`, spatial restoration/default-launch behavior, Look to Scroll, and vision-only window sizing to visionOS.
- [x] Restrict AppKit window/material bridges and `NSEvent` modifier logic to macOS.
- [x] Establish iOS toolbar placements using `.topBarLeading`, `.primaryAction`, and `.bottomBar` as appropriate.
- [x] Keep shared UIKit utilities behind `canImport(UIKit)` while separating iOS and visionOS interaction policy.

### Scene and startup spine

- [x] Add an iOS-family root router in the existing app file, following the sibling pattern without copying terminal-specific logic.
- [x] Present Settings inside the single-window iPhone hierarchy while preserving a native iPad Settings scene.
- [x] Ensure connection/session/settings managers and the iOS router are initialized once and injected consistently across iOS scenes.
- [x] Add stale route handling by returning the iPhone root to Connections when its requested session is no longer live.

## Build Loop

For every boundary fix:

`iPHONE SIM BUILD → iPAD SIM BUILD → MAC BUILD → VISION BUILD → FOCUSED TEST → DIFF AUDIT`

Do not batch dozens of availability fixes before testing all four destinations.

## Exit Criteria

- [x] iPhone and iPad Debug simulator builds pass; the shared Release artifact passes for generic iOS simulator and unsigned iOS device destinations.
- [x] Test target compiles for the iOS-family simulator destination.
- [x] No iOS branch references visionOS ornaments/windows or AppKit.
- [x] Native arm64 Mac and visionOS simulator regression builds pass.
- [x] Generated app metadata accurately describes supported platforms, iOS 26.0 minimum, device families 1/2, orientations, icon, and local-network purpose.

## Evidence Log

| Date | Destination | Build/Test | Result | Artifact |
|---|---|---|---|---|
| 2026-07-21 | iPhone 17 simulator, iOS 27.0, arm64 | Debug build | Pass | `/private/tmp/glassdb-p1-iphone-build.log` |
| 2026-07-21 | iPad Air 11-inch (M4) simulator, iPadOS 27.0, arm64 | Debug build | Pass | `/private/tmp/glassdb-p1-ipad-build.log` |
| 2026-07-21 | Generic iOS simulator, arm64 | Release build | Pass | `/private/tmp/glassdb-p1-ios-release-simulator.log` |
| 2026-07-21 | Generic iOS device, arm64, unsigned | Release build | Pass | `/private/tmp/glassdb-p1-ios-release-device.log` |
| 2026-07-21 | iPhone 17 simulator, iOS 27.0, arm64 | App and unit-test target `build-for-testing` | Pass | `/private/tmp/glassdb-p1-ios-build-for-testing.log` |
| 2026-07-21 | Generic native macOS, arm64 | Debug regression build and Mach-O inspection | Pass | `/private/tmp/glassdb-p1-mac-build.log`; executable reports only `arm64`, macOS 27.0 |
| 2026-07-21 | Generic visionOS simulator, arm64 | Debug regression build and metadata inspection | Pass | `/private/tmp/glassdb-p1-vision-build.log`; executable reports only `arm64`, visionOS 26.0 |
| 2026-07-21 | iOS simulator and device Release bundles | Metadata inspection | Pass | `iPhoneSimulator`/`iPhoneOS`, minimum 26.0, device families 1/2, all four orientations, `MacAppIcon`, truthful local-network purpose string |
