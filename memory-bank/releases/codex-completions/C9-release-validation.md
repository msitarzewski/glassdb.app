# C9: Release Validation

**Status**: in progress
**Depends on**: C0-C8
**Source IDs**: V01-V05 and all release exit gates

## Goal

Prove the completed native Vision Pro and Apple-silicon Mac release is secure, correct, compatible, performant, and documented accurately before TestFlight, signed Mac distribution, or production use.

## Validation Plan

### Build and static quality

- [x] Build both native application targets in Debug and Release with Xcode 27: native Mac Debug/tests plus unsigned Release archive, and visionOS Debug/tests plus generic Release build.
- [ ] Test each target on its applicable minimum and latest supported runtime, including physical-device acceptance where required.
- [x] Inspect build settings/artifacts for visionOS 26.0+, macOS 27.0+, Apple Silicon-only slices, and no Intel or Catalyst shipping artifacts.
- [ ] Run strict Swift concurrency checks and resolve all app, GlassDBKit, GlasSecretStore, Citadel, and swift-nio-ssh warnings or record time-bounded upstream waivers.
- [ ] Run dependency audit, license review, secret scan, and static analysis.

### Automated and integration tests

- [x] Keep the original package coverage green and record expanded totals: GlassDBKit aggregate coverage 25/25 (22 current local non-live passes plus three previously recorded gated live passes) and GlasSecretStore 68/68.
- [x] Run the shared app transport, host-trust, credential migration, typed-value, parser, mutation, AI-policy, persistence-integrity, platform-shell, and Mac form/layout suites: latest native Mac suite 84/84 on macOS 27 arm64; frozen cross-platform checkpoint 59/59 on the visionOS 26.4 arm64 simulator; fresh shared-workspace visionOS arm64 build passed on 2026-07-19.
- [x] Run the claimed live-server matrix: MySQL 8 and PostgreSQL 17 integrations passed 2/2; managed-copy SQLite is covered by GlassDBKit and app tests. MySQL 5.7 remains unclaimed.
- [ ] Inject certificate/key rotation, network loss, timeout, cancellation, reconnect, transaction conflict, disk-full, Keychain denial, and process termination.

### Scale and UX

- [x] Test server-bounded/paged 1K, 10K, and 100K result/export workflows with latency and allocation-conscious algorithms; incremental driver streaming remains an explicit post-release gap.
- [ ] Profile repeated connect/query/disconnect, multiwindow workspaces, detached results, grid edits, imports/exports, and AI sessions for leaks.
- [ ] Complete keyboard, pointer, touch, visionOS interaction, VoiceOver, contrast, motion, and dynamic-type checks per platform.
- [ ] Exercise the Vision Pro `query-editor` workspace at opacity endpoints and intermediate values, blur endpoints and intermediate values, multiple simultaneous workspaces, relaunch, and window restoration; verify 0% opacity remains available and controls/content remain usable.
- [ ] Verify Connections, Settings, detached results, and other general app windows retain their Apple-recommended materials and do not inherit database-workspace opacity or blur.
- [ ] Run a production-data safety exercise covering preview, confirmation, optimistic conflict, rollback, audit record, and recovery from unknown server state.

### Documentation and release decision

- [ ] Re-audit every source ID in the master tracker against current code and objective evidence.
- [x] Update the release tracker and C7/C9 platform/validation records from verified evidence; public/App Store copy remains gated on signed/device acceptance.
- [ ] Publish known limitations, supported server/OS matrix, migration/rollback plan, and incident-response path.
- [ ] Obtain explicit release approval after reviewing residual risks; TestFlight is not an automatic consequence of a green build.

## Exit Criteria

- [ ] All C0-C8 milestones are done and their evidence logs are complete.
- [ ] Every gate in [the Codex Completions release tracker](README.md#release-exit-gates) passes or has an explicit residual-risk disposition.
- [ ] There are no unexplained warnings, skipped blocker tests, silent failures, or overstated claims.
- [ ] The release has a signed-off compatibility matrix, rollback plan, and residual-risk register.

## Residual-Risk Register

- **Mac distribution**: the macOS Release archive is unsigned. Signing, provisioning, and Mac device registration remain open; the archive is build evidence, not a distributable artifact.
- **Shared entitlement runtime**: App Group metadata and shared Keychain transactions have automated bounds/readback/rollback coverage, but cross-app glassdb/glas.sh behavior must be verified with correctly signed applications.
- **Foundation Models**: framework linkage and availability gating work, but direct generation returned model-manager error 1008 in the unsigned/direct context. Successful on-device generation is not claimed.
- **Physical Vision Pro**: simulator/build tests do not complete the required opacity/blur, legibility, restoration, eye-and-hand, VoiceOver, or multiwindow acceptance on hardware. The live database workspace must retain 0% opacity and continuous opacity/blur adjustment; general windows must retain system materials.
- **Credential synchronization**: cross-device synchronization is not implemented. Current eligible sharing is designed for the same signed app family/device; Secure Enclave and user-presence secrets remain device-bound.
- **Citadel environment skips**: the suite reports 31 tests, 5 environment-gated skips, and 0 failures. Those skips are recorded and may not be treated as signed App Group/Keychain or external SSH acceptance evidence.
- **Temporary mysql-nio fork**: GlassDBKit and Xcode are pinned to reviewed commit `3ad138f`. Vapor mysql-nio PR #126 is draft and cleanly mergeable, but upstream CI is still `action_required` pending maintainer approval; replace the pin with an upstream release only after that release contains the fix.

## Evidence Log

| Date | Gate/Suite | Environment | Result | Artifact/Commit |
|---|---|---|---|---|
| 2026-07-19 | Shared workspace/data-management candidate | native macOS 27 arm64 host plus generic visionOS simulator arm64 build | Mac 84/84 with zero failures, skips, expected failures, or runtime warnings; both platform builds passed; development-signed Mac bundle passed strict signature verification | local Xcode result bundle and build artifacts |
| 2026-07-19 | Grid/record UX regressions | native Mac test host | semantic JSON compaction, query/display-only filters, plain/Shift/Command row selection, selected-row export, staged column manager, and pinned grid surfaces passed | focused tests within 84-test app suite |
| 2026-07-19 | GlassDBKit refresh | native arm64 Mac package run plus retained gated-live evidence | 22/22 non-live tests passed locally; all three gated live tests have previously recorded passes, for aggregate 25/25 coverage | Swift Testing output and prior disposable-server logs |
| 2026-07-18 | Final app functional/unit suites | native macOS 27 arm64 host and visionOS 26.4 arm64 simulator | Mac 60/60; visionOS 59/59; zero result-bundle errors, build/analyzer/runtime warnings, skips, or expected failures | local Xcode test results |
| 2026-07-18 | Native Mac UX and Settings layout | macOS 27 native controls and hosted finite-layout regression | grouped/tabbed Settings and bounded sheets/inputs completed ten stable layout cycles; connection sidebar defaults to 340 points with a 300-point minimum; Vision Pro opacity/blur controls remain wired and continuous | local source review and application tests; no screenshot artifact claimed |
| 2026-07-18 | Native Settings crash regression | macOS 27 Debug cycles and exact unsigned Release archive | ten fresh Debug Settings launches plus Release Settings probe survived; no new `.ips` or AppKit constraint-loop diagnostic | local runtime and unified-log evidence |
| 2026-07-18 | Engine unit/live suite | GlassDBKit + MySQL 8 + PostgreSQL 17 | 24/24 package; live integrations 2/2 | package logs; disposable Docker containers |
| 2026-07-18 | Passwordless MySQL regression | mysql-nio nil/empty/nonempty focused tests; official 1.9.1 negative control; pinned gated GlassDBKit test against loopback MySQL 9.7.1; fresh development-signed Mac build | focused tests passed; official dependency reproduced `using password: YES`; live GlassDBKit test passed 1/1; full suite passed 24/24; user confirmed the new Mac app connects | fork `3ad138f`; upstream draft PR #126 |
| 2026-07-18 | Secret/SSH packages | Swift 6.4 | GlasSecretStore 68/68; Citadel 31 tests with 5 environment-gated skips and 0 failures; swift-nio-ssh 320/320 | package test logs |
| 2026-07-18 | Final Release builds | Xcode 27, native macOS and generic visionOS | unsigned macOS Release archive passed; visionOS Release build passed | local Xcode artifacts |
| 2026-07-18 | Foundation Models direct probe | unsigned/direct native Mac context | model path reached; generation failed with model-manager error 1008 | direct runtime probe |
| 2026-07-17 | Pen/static scans | targeted current sources/diff/history | adversarial suites and gitleaks clean; history findings vendored fixtures | C9 security report |
