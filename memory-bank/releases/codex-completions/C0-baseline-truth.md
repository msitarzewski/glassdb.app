# C0: Baseline & Truthful Status

**Status**: in progress
**Depends on**: none
**Source IDs**: V01-V06, M01, M05, M08, P06

## Goal

Establish a reproducible baseline and make every public or Memory Bank completion claim match tested operational behavior.

## Implementation Plan

### Reproducible baseline

- [ ] Record exact Xcode, SDK, Swift, simulator/device, and package-resolution versions for the verified build.
- [ ] Re-run and preserve the visionOS app build, all GlassDBKit tests, and all GlasSecretStore tests.
- [ ] Add a warning inventory for Citadel/swift-nio-ssh; assign each warning a fix, upstream reference, or explicit temporary waiver.
- [ ] Record that the app target is currently xros-only at `glassdb.xcodeproj/project.pbxproj:299` while GlassDBKit declares visionOS/macOS/iOS at `Packages/GlassDBKit/Package.swift:8`.
- [ ] Capture the audit's clean-worktree commit as the comparison baseline and link every later implementation commit.

### Truthful feature accounting

- [ ] Build a settings-consumer matrix for auto-reconnect, close confirmation, result limits, line numbers, opacity, and background blur exposed from `glassdb/SettingsView.swift:24`.
- [ ] Treat database-workspace opacity and background blur as protected product functionality: preserve their stored settings and assign their complete runtime implementation to C7; they are not removal candidates.
- [ ] For each other unconsumed setting, either wire it to tested runtime behavior in its owning milestone or remove it from UI, persistence, and documentation.
- [ ] Reclassify AI, row editing, history, multi-statement execution, TLS, SSH trust, and cross-platform claims as partial until their owner milestones pass.
- [ ] Reconcile `memory-bank/activeContext.md`, `memory-bank/progress.md`, release plans, README, and App Store copy against the same status vocabulary.
- [ ] Review scene materials beginning at `glassdb/glassdbApp.swift:19`: Connections, Settings, detached results, and other general app windows should use Apple-recommended materials, while the `query-editor` scene at `glassdb/glassdbApp.swift:29` intentionally supports the transparent database workspace; defer implementation changes to C7.

## Exit Criteria

- [ ] A new contributor can reproduce the baseline using documented commands and versions.
- [x] Baseline preserves the original 3/3 GlassDBKit and 62/62 GlasSecretStore evidence. The final expanded suites are 21/21 GlassDBKit, 68/68 GlasSecretStore, and 44/44 app tests on both visionOS 26.5 and 27.0.
- [ ] No feature is labeled complete without an operational consumer and a named verification artifact.
- [ ] The baseline explicitly records full transparency and adjustable opacity/blur for the live database workspace—not every application window—as non-negotiable release requirements.
- [ ] The tracker links every audit source ID to exactly one primary implementation milestone.

## Evidence Log

| Date | Build/Test | Environment | Result | Artifact/Commit |
|---|---|---|---|---|
| 2026-07-17 | Final app suites | Xcode 27.0 beta 27A5209h; visionOS 26.5 and 27.0 simulators; arm64 | 44/44 passed on both runtimes | `/private/tmp/glassdb-final-265`; `/private/tmp/glassdb-final-270` |
| 2026-07-17 | Shared packages | Swift 6.4 | GlassDBKit 21/21; GlasSecretStore 68/68; swift-nio-ssh 320/320 | working trees on `codex-completions` |
| 2026-07-17 | Warning/stub inventory | app + vendored transport sources | Citadel/NIOSSH concurrency warnings resolved; AppIntents extractor warning dispositioned as Xcode tooling; touched-source stub scan clean | C9 report |
