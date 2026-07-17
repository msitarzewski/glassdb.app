# C7: Engines, Platforms & Native UI

**Status**: in progress
**Depends on**: C1-C6
**Source IDs**: V02, M08, G05, B01-B02, P01-P07

## Goal

Evolve the shared engine/model layer into capability-based interfaces while preserving glassdb's actual product: a native Vision Pro database client. Non-visionOS shells are architecture guidance for separate future releases, not shipping claims for `codex-completions`.

The only shipping shell is visionOS 26+ on arm64. A native macOS shell is deferred; no macOS, Intel, or Catalyst artifact is produced by this release.

## Implementation Plan

### Engine breadth

- [ ] Stabilize C2 capabilities for transactions, metadata, streaming, cancellation, explain, server version, and engine-specific extensions.
- [ ] Add PostgreSQL through postgres-nio with native schemas, types, TLS, SSH, parameters, explain, and cancellation.
- [ ] Add SQLite file workflows after PostgreSQL without forcing network-connection assumptions into shared APIs.
- [ ] Publish an engine capability matrix; hide or explain unsupported actions rather than failing late.

### Shipping platform and future-shell decision

- [x] Keep models, security, and engine contracts reusable without claiming nonexistent app shells.
- [x] Keep the shipping application visionOS-only, set its deployment target to 26.0, and make both app and test targets arm64-only.
- [x] Exclude Catalyst; no Intel or macOS archive is produced by this release.
- [x] Retain ordinary query/results grids in Vision Pro windows and preserve multiwindow workspaces.
- [x] Record native macOS, iPadOS, and focused iOS recommendations as future product decisions; do not create shells that contradict the stated Vision Pro mission.
- [x] Add iOS 26 to GlasSecretStore's package declarations for future shared-engine consumers without claiming an iOS glassdb app.

### System UI strategy

- [ ] Use Apple-recommended system window textures for Connections (`glassdb/glassdbApp.swift:19`), Settings (`glassdb/glassdbApp.swift:55`), detached results, and other general application windows.
- [ ] Preserve `.windowStyle(.plain)` or an equivalent native implementation specifically for the `query-editor` scene at `glassdb/glassdbApp.swift:29`, whose `DatabaseWorkspaceView` is the SQL authoring and row-management surface.
- [ ] Use system Liquid Glass for workspace navigation and controls without reintroducing an opaque standard window background behind the user-selected transparent database-workspace surface.
- [ ] Wire `windowOpacity` from `glassdb/SettingsManager.swift:22` to the `query-editor` workspace with a continuous range that includes `0.0` (fully transparent) through `1.0` (fully opaque).
- [ ] Replace the blur-only toggle at `glassdb/SettingsManager.swift:23` with a persisted continuous blur-intensity setting and slider whose range includes no blur and the supported maximum.
- [ ] Apply opacity and blur changes live to open database workspaces without altering general app windows, recreating sessions, or losing workspace state.
- [ ] Define accessible contrast treatments for text, grids, editor surfaces, focus, selection, ornaments, alerts, and destructive confirmations at every supported transparency/blur value; do not solve legibility by disabling full transparency.
- [ ] Preserve and migrate existing `windowOpacity` and `blurBackground` preferences so current users do not lose their appearance choices.
- [ ] Evaluate visionOS 27 RealityKit improvements for ER/explain volumes and SwiftUI adaptive toolbar/document APIs for the query environment.
- [ ] Preserve visionOS 26 deployment until a documented feature/maintenance decision changes it.

## Exit Criteria

- [ ] Platform and engine claims correspond to the visionOS shipping target and tested capabilities.
- [ ] MySQL, PostgreSQL, and SQLite share contracts without lowest-common-denominator leakage.
- [ ] The visionOS app passes its input, windowing, security, and accessibility acceptance suite.
- [ ] No Catalyst or non-visionOS application target is advertised or shipped.
- [ ] Release artifacts contain only arm64 and declare visionOS 26.0 minimum deployment.
- [ ] General application windows pass HIG/material review, and database-workspace content remains legible across its supported appearance range.
- [ ] The Vision Pro `query-editor` workspace demonstrably supports 0% opacity plus continuous opacity and blur adjustment, with persistence and live updates; other windows remain unaffected.

## Evidence Log

| Date | Engine/Platform | Scenario | Result | Test/Commit |
|---|---|---|---|---|
| 2026-07-17 | visionOS 26.5 + 27.0 | final arm64 app suites | 44/44 passed on each runtime | `/private/tmp/glassdb-final-265`; `/private/tmp/glassdb-final-270` |
| 2026-07-17 | Release artifact | CPU/deployment/framework linkage | clean Release build; arm64 only; min 26.0; SDK 27.0; FoundationModels weak | `/private/tmp/glassdb-publish-release/.../glassdb.app` |
| 2026-07-17 | MySQL/PostgreSQL/SQLite | engine contracts and live/local execution | 21/21 package; live MySQL 8.4.10 and PostgreSQL 17.10 passed | `GlassDBKitTests` |
| 2026-07-17 | App icons | visionOS solid image stacks | glassdb and sibling glas.sh passed `actool` | asset compiler output |
