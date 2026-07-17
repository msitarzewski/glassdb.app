# C9: Release Validation

**Status**: in progress
**Depends on**: C0-C8
**Source IDs**: V01-V05 and all release exit gates

## Goal

Prove the completed release is secure, correct, compatible, performant, and documented accurately before TestFlight or production use.

## Validation Plan

### Build and static quality

- [ ] Build every shipping app target in Debug and Release with the supported Xcode/SDK matrix, including the verified Xcode 27 beta / visionOS 27 / Swift 6.4 environment.
- [ ] Test each target on its OS 26 minimum and the latest supported runtime.
- [ ] Inspect release archives to verify OS 26.0 minimum deployment, Apple Silicon device slices only, and no Intel or Catalyst shipping artifacts.
- [ ] Run strict Swift concurrency checks and resolve all app, GlassDBKit, GlasSecretStore, Citadel, and swift-nio-ssh warnings or record time-bounded upstream waivers.
- [ ] Run dependency audit, license review, secret scan, and static analysis.

### Automated and integration tests

- [ ] Keep the original 3 GlassDBKit and 62 GlasSecretStore tests green, then record the expanded suite totals.
- [ ] Run transport, host-trust, credential migration, typed-value, parser, mutation, AI-policy, and platform-shell suites from C1-C8.
- [ ] Test MySQL 5.7, 8.0, and 8.4 across direct/TLS/SSH paths; add PostgreSQL and SQLite matrices when C7 ships them.
- [ ] Inject certificate/key rotation, network loss, timeout, cancellation, reconnect, transaction conflict, disk-full, Keychain denial, and process termination.

### Scale and UX

- [ ] Test server-bounded/paged 1K, 10K, and 100K result/export workflows with latency and allocation-conscious algorithms; incremental driver streaming remains an explicit post-release gap.
- [ ] Profile repeated connect/query/disconnect, multiwindow workspaces, detached results, grid edits, imports/exports, and AI sessions for leaks.
- [ ] Complete keyboard, pointer, touch, visionOS interaction, VoiceOver, contrast, motion, and dynamic-type checks per platform.
- [ ] Exercise the Vision Pro `query-editor` workspace at opacity endpoints and intermediate values, blur endpoints and intermediate values, multiple simultaneous workspaces, relaunch, and window restoration; verify 0% opacity remains available and controls/content remain usable.
- [ ] Verify Connections, Settings, detached results, and other general app windows retain their Apple-recommended materials and do not inherit database-workspace opacity or blur.
- [ ] Run a production-data safety exercise covering preview, confirmation, optimistic conflict, rollback, audit record, and recovery from unknown server state.

### Documentation and release decision

- [ ] Re-audit every source ID in the master tracker against current code and objective evidence.
- [ ] Update README, Memory Bank, privacy/security copy, settings descriptions, and App Store metadata only after verification.
- [ ] Publish known limitations, supported server/OS matrix, migration/rollback plan, and incident-response path.
- [ ] Obtain explicit release approval after reviewing residual risks; TestFlight is not an automatic consequence of a green build.

## Exit Criteria

- [ ] All C0-C8 milestones are done and their evidence logs are complete.
- [ ] Every gate in [the Codex Completions release tracker](README.md#release-exit-gates) passes or has an explicit residual-risk disposition.
- [ ] There are no unexplained warnings, skipped blocker tests, silent failures, or overstated claims.
- [ ] The release has a signed-off compatibility matrix, rollback plan, and residual-risk register.

## Evidence Log

| Date | Gate/Suite | Environment | Result | Artifact/Commit |
|---|---|---|---|---|
| 2026-07-17 | Final app functional/unit suites | visionOS 26.5 and 27.0, arm64 | 44/44 passed on both | `/private/tmp/glassdb-final-265`; `/private/tmp/glassdb-final-270` |
| 2026-07-17 | Engine unit/live suite | GlassDBKit + MySQL 8.4.10 + PostgreSQL 17.10 | 21/21 unit; both live integrations passed before final host-trust call-site correction | package logs; disposable Docker containers |
| 2026-07-17 | Secret/SSH packages | Swift 6.4 | GlasSecretStore 68/68 with host Keychain access; swift-nio-ssh 320/320 | package test logs |
| 2026-07-17 | Final Release build/artifact | Xcode 27 beta, generic visionOS device | clean build passed; arm64; min 26.0; SDK 27.0; weak FM | `/private/tmp/glassdb-publish-release` |
| 2026-07-17 | Pen/static scans | targeted current sources/diff/history | adversarial suites and gitleaks clean; history findings vendored fixtures | C9 security report |
