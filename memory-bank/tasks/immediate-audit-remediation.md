# Immediate Audit Remediation

**Status:** Automated remediation complete; external release gates remain open
**Branch:** `agent/immediate-audit-remediation`
**Scope:** Immediate codebase and repository fixes identified by the 2026-08-06 audit.

## Objective

Close the actionable privacy, security, navigation, automation, documentation, and repository-hygiene gaps without broadening the product scope or weakening the existing release gates.

## Reuse Analysis

- `memory-bank/releases/platforms-plus-plus/P9-integration-release-validation.md` remains the release evidence ledger and is not an execution checklist.
- `memory-bank/releases/codex-completions/C9-release-validation.md` is historical completion evidence and must not be rewritten as current task state.
- No `memory-bank/tasks` directory or existing task file was available to extend.

## Task List

- [x] **T1 — Privacy manifest:** add and validate the app privacy manifest, declare required-reason API use, and include it in the app bundle.
- [x] **T2 — SSH credential isolation:** prevent database credentials from ever serving as implicit SSH credentials; add regression coverage.
- [x] **T3 — iPhone workspace routing:** route “Show Connections” through the single-window iPhone router; add regression coverage for route selection.
- [x] **T4 — CI and security scanning:** add a reproducible GitHub Actions workflow and a narrow scanner allowlist for known vendored fixtures/false positives.
- [x] **T5 — Documentation and dependency provenance:** reconcile current platform claims, mark the old scaffold as historical, and record the actual mysql-nio fork revision/upstream outcome.
- [x] **T6 — Repository and build-warning hygiene:** ignore profiler artifacts and classify the remaining Xcode 27 beta App Intents diagnostic without adding an unused framework dependency.
- [x] **T7 — Full QA:** run app and package tests, privacy/config validation, secret/dependency scans, and repository diff checks; record remaining external release gates.

## Acceptance Criteria

- Database passwords cannot be forwarded to the SSH server when SSH credentials are absent.
- iPhone connection navigation stays inside the single-window router.
- The built app contains a valid `PrivacyInfo.xcprivacy` with the required UserDefaults reasons.
- CI exercises the app/package test suites and security checks on a compatible Apple Silicon runner.
- Secret scanning passes without globally suppressing private-key detection.
- Current documentation matches the implemented platform matrix and dependency state.
- Automated QA is green; physical-device, live-service, signing, accessibility, and human approval gates remain explicitly open until performed.

## Evidence Log

| Task | Evidence | Result |
|---|---|---|
| T1 | Source and built macOS/iOS `PrivacyInfo.xcprivacy` passed `plutil`; built bundles contain UserDefaults reasons `CA92.1` and `1C8F.1` | Pass |
| T2 | `sshAuthenticationNeverFallsBackToTheDatabasePassword` in the 103-test app suite | Pass |
| T3 | `workspaceConnectionsRouteUsesTheInAppRouterOnlyOnPhone` plus generic arm64 iOS Simulator build | Pass |
| T4 | Full-history and current-source Gitleaks scans found no leaks; workflow YAML parsed successfully | Pass |
| T5 | Current README/AGENTS/Progress reconciled; scaffold marked historical; live fork revision recorded as `69489876bebca3b54c46680e519669789060d0ae` | Pass |
| T6 | `*.profraw` ignored. Xcode 27 beta still emits “no AppIntents.framework dependency” even when its installed `--quiet-warnings` control is applied; no unused product dependency was added solely to hide this toolchain diagnostic | Pass with toolchain diagnostic |
| T7 | macOS app 103/103; GlassDBKit 25/25 with 3 live-service skips; generic iOS build; OSV no issues (1 local/unscannable); Gitleaks history/current tree clean; `git diff --check` clean | Pass |

## Remaining External Gates

- Correctly signed physical-device installation and launch.
- Live MySQL/PostgreSQL, TLS, SSH tunnel, Tailscale, and path-loss validation.
- Assistive-technology and Instruments review.
- iOS 26 runtime fallback pass.
- Explicit human release approval before TestFlight, App Store, or signed distribution.
