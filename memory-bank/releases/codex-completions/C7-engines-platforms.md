# C7: Engines, Platforms & Native UI

**Status**: in progress
**Depends on**: C1-C6
**Source IDs**: V02, M08, G05, B01-B02, P01-P07

## Goal

Evolve the shared engine/model layer into capability-based interfaces while preserving glassdb's glass-first Vision Pro identity and delivering the same professional database workflows through a native Mac shell.

`codex-completions` contains feature-parity native shells for visionOS 26+ and macOS 27+, both arm64-only. The shells share connection management, engines, SQL tooling, mutations, results, settings, and security behavior while using platform-native scene, control, editor, and window adaptations. No Intel or Catalyst artifact is produced.

## Implementation Plan

### Engine breadth

- [x] Stabilize C2 capabilities for transactions, metadata, cancellation, explain, server version, and engine-specific extensions; retain incremental streaming as an explicit non-capability.
- [x] Add PostgreSQL through postgres-nio with native schemas, types, TLS, SSH, parameters, explain, and abortive cancellation.
- [x] Add managed-copy SQLite file workflows without forcing network-connection assumptions into shared APIs.
- [x] Publish capability-based behavior in the UI; hide or explain unsupported actions rather than failing late.

### Shipping platform and future-shell decision

- [x] Keep models, security, and engine contracts reusable without claiming nonexistent app shells.
- [x] Preserve the native Vision Pro application at visionOS 26.0+ and add a feature-parity native Mac application at macOS 27.0+; keep app and test targets arm64-only.
- [x] Exclude Catalyst and Intel; the Mac shell is native AppKit/SwiftUI rather than a Catalyst build.
- [x] Retain ordinary query/results grids in Vision Pro windows and preserve multiwindow workspaces.
- [x] Adapt scenes, keyboard commands, inspectors, controls, text editing, menus, icons, and entitlements for native macOS while retaining shared database feature parity.
- [x] Keep iPadOS and focused iOS recommendations as future product decisions; do not claim nonexistent shells.
- [x] Add iOS 26 to GlasSecretStore's package declarations for future shared-engine consumers without claiming an iOS glassdb app.

### System UI strategy

- [x] Use Apple-recommended system window textures for Connections, Settings, detached results, and other general application windows.
- [x] Preserve a transparent-capable native implementation specifically for the `query-editor` scene, whose `DatabaseWorkspaceView` is the SQL authoring and row-management surface.
- [x] Use system Liquid Glass/native materials for workspace navigation and controls without reintroducing an opaque standard window background behind the user-selected database-workspace surface.
- [x] Wire persisted `windowOpacity` to live database workspaces with a continuous range that includes `0.0` (fully transparent) through `1.0` (fully opaque).
- [x] Provide persisted continuous blur intensity from no blur through the supported maximum.
- [x] Apply opacity and blur changes live to database workspaces without altering general app windows, recreating sessions, or losing workspace state.
- [ ] Define accessible contrast treatments for text, grids, editor surfaces, focus, selection, ornaments, alerts, and destructive confirmations at every supported transparency/blur value; do not solve legibility by disabling full transparency.
- [x] Preserve and migrate existing `windowOpacity` and `blurBackground` preferences so current users do not lose their appearance choices.
- [ ] Evaluate visionOS 27 RealityKit improvements for ER/explain volumes and SwiftUI adaptive toolbar/document APIs for the query environment.
- [x] Preserve visionOS 26 deployment until a documented feature/maintenance decision changes it.

## Exit Criteria

- [x] Platform and engine claims correspond to the native visionOS/macOS targets and tested capabilities.
- [x] MySQL, PostgreSQL, and SQLite share contracts without lowest-common-denominator leakage.
- [ ] The visionOS and macOS applications pass their signed input, windowing, security, entitlement, and accessibility acceptance suites.
- [x] No Catalyst, Intel, iPadOS, or iOS application target is advertised or shipped.
- [x] Release builds contain only arm64 and declare visionOS 26.0 / macOS 27.0 minimum deployment as applicable.
- [ ] General application windows pass HIG/material review, and database-workspace content remains legible across its supported appearance range.
- [ ] The Vision Pro `query-editor` workspace demonstrably supports 0% opacity plus continuous opacity and blur adjustment, with persistence and live updates; other windows remain unaffected.

## Evidence Log

| Date | Engine/Platform | Scenario | Result | Test/Commit |
|---|---|---|---|---|
| 2026-07-19 | native macOS + visionOS shared workspace | transparent database canvas, native material chrome, persistent tabs, database dashboard, table metadata/mutation tools, staged column/filter managers | 84/84 native Mac tests passed; fresh arm64 Mac and visionOS simulator builds passed; development-signed Mac bundle passed strict verification | local Xcode results and artifacts |
| 2026-07-18 | native macOS + visionOS 27 simulator | final arm64 app suites | 56/56 passed on Mac; 55/55 passed on visionOS 27 | local Xcode test results |
| 2026-07-18 | Release builds | native Mac archive and Vision Pro build | unsigned macOS Release archive passed; generic visionOS Release build passed | local Xcode artifacts |
| 2026-07-18 | MySQL/PostgreSQL/SQLite | engine contracts and live/local execution | 24/24 package tests; live MySQL 8 and PostgreSQL 17 integrations 2/2 | `GlassDBKitTests`; disposable containers |
| 2026-07-18 | MySQL passwordless auth | `caching_sha2_password` with empty credential | official mysql-nio 1.9.1 rejected the connection as password-bearing; pinned fork `3ad138f` passed the gated GlassDBKit test against MySQL 9.7.1; user confirmed the fresh Mac app connects | focused mysql-nio tests; local live test; upstream draft PR #126 |
| 2026-07-18 | Native Mac parity | shared workflows with AppKit/SwiftUI adaptations | connection, schema, SQL editor, results grid, row management, settings, and security surfaces compile and pass 56 native app tests | native macOS target |
| 2026-07-18 | Native Mac Settings | repeated native Settings presentation and exact Release launch | finite 760×680 content sizing; ten Debug launches and Release probe survived with no new `.ips` or constraint-loop log | local runtime regression |
| 2026-07-19 | App icons | platform-specific compiled assets | Mac duplicate `MacAppIcon` resource collision removed; flattened Mac icon restored; Vision Pro solid image stack retained; both platform builds passed asset compilation | asset compiler output |

## Residual Platform Gates

- The macOS Release archive is unsigned. Mac application signing, provisioning, and device registration remain required before distribution acceptance.
- Shared App Group and Keychain behavior must be exercised between correctly signed glassdb and glas.sh builds; unit readback/rollback evidence does not substitute for the entitlement-bound runtime test.
- Foundation Models reached its runtime path, but direct generation returned model-manager error 1008 in the unsigned/direct validation context.
- Physical Vision Pro opacity, blur, legibility, eye-and-hand interaction, restoration, and accessibility acceptance remain open. The 0–100% transparency and continuous blur product invariant remains mandatory.
- Cross-device credential synchronization is not implemented; Secure Enclave and user-presence records remain intentionally device-bound.
- The temporary mysql-nio fork pin must be replaced by an upstream release after PR #126 passes maintainer-approved CI and merges.
