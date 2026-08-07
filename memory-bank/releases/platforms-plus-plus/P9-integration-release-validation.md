# P9: Integration, Stub Repair, and Release Validation

**Status**: in progress — automated release candidate integrated and green; signed-device/live-server/human approval gates remain
**Goal**: G9
**Depends on**: P0-P8

## Objective

Integrate every milestone into one truthful release candidate, repair incomplete or placeholder behavior found in final review, and obtain objective evidence and human approval before distribution.

## Final Integration

- [ ] Rebase/merge milestone work without discarding unrelated user changes.
- [x] Reconcile app target settings, entitlements, icons, Info metadata, package resolution, schemes, and test plans.
- [x] Verify one shared target produces native iPhone, iPad, Mac, and Vision Pro artifacts with correct minimum OS and architecture metadata.
- [ ] Run clean Debug, Release, test, and archive builds for every supported destination.
- [ ] Verify signed physical-device installation and launch where provisioning exists.

## Complete-Code Audit

Search application, tests, and touched packages for:

- [x] `TODO`, `FIXME`, `HACK`, `XXX`, `future`, `stub`, `placeholder`, `not implemented` in authored application/GlassDBKit production scope.
- [ ] `fatalError`, `preconditionFailure`, force unwraps/casts, empty catches, suppressed errors, and debug-only behavior.
- [ ] disabled controls with no recovery path, dead toolbar/menu actions, and unavailable actions shown as functional.
- [x] mock/sample/fake production data.
- [ ] duplicate state, platform forks, obsolete custom controls, and unused bridge code.
- [ ] unbounded buffers, tasks, retries, results, history, or exports.
- [ ] documentation claims lacking executable evidence.

Repair every in-scope finding, rerun its owning milestone loop, and rerun the full regression suite. Do not merely list repairable stubs as known issues.

## Custom Exception Register

- [x] Consolidate all retained custom-component exceptions from P2-P5.
- [x] Confirm Apple APIs evaluated, missing capability, accessibility/input/performance evidence, and removal condition.
- [x] Reject any exception based only on visual preference or implementation convenience.

## Release Validation Matrix

- [ ] iOS 26 minimum iPhone and iPad.
- [x] iOS/iPadOS 27 current iPhone and iPad.
- [x] macOS 27 Apple Silicon.
- [x] visionOS 26.5 available minimum-family runtime and visionOS 27 current.
- [ ] MySQL, PostgreSQL, managed-copy SQLite.
- [ ] Direct, TLS, SSH tunnel, local network, and direct Tailscale host.
- [ ] New install, upgrade, downgrade/rollback, credential migration, restoration, and multiwindow recovery.
- [ ] Canonical glas.sh/iPhone -> glassdb/Vision Pro tunnel selection, reverse
  direction, delayed secret, iCloud account change, deletion/rotation, and Secure
  Enclave local enrollment when the My Connections program enters the candidate.
- [ ] Accessibility, performance, security, and device-only gates from P8.

## Documentation Reconciliation

- [x] Update this dashboard and every milestone evidence log.
- [x] Update `activeContext.md`, `progress.md`, platform matrix, known limitations, and release instructions from verified evidence.
- [x] Preserve historical `codex-completions` claims rather than retroactively rewriting its evidence.
- [x] Document which OS 27 enhancements are active and how OS 26 falls back.
- [x] Document credential sharing/synchronization/device-bound behavior accurately.
- [x] Record the approved My Connections direction without presenting it as
  implemented or changing public product claims.
- [x] Document any external provisioning or hardware gate separately from implementation completion.

## Final Loop

`CLEAN BUILD → ALL TESTS → DEVICE MATRIX → STUB SCAN → CUSTOM EXCEPTION REVIEW → DOC CLAIM AUDIT → RESIDUAL RISK REVIEW → HUMAN APPROVAL`

Any fix restarts the affected focused tests and the full four-platform regression pass.

## Exit Criteria

- [ ] P0-P8 are done with complete evidence.
- [ ] All release exit gates in the tracker pass or have explicit external blockers and human disposition.
- [x] No repairable in-scope stub/TODO/future behavior remains.
- [x] Custom exceptions are minimal, justified, and tested by the automated matrix; physical accessibility acceptance remains in P8.
- [x] Public platform, engine, security, credential, AI, and UX claims match artifacts and runtime evidence.
- [ ] Human release approval is recorded before TestFlight/App Store submission or signed distribution.

## Evidence Log

| Date | Gate/Suite | Environment | Result | Artifact/Commit |
|---|---|---|---|---|
| 2026-07-21 | Shared target and metadata | Mac, iPhone/iPad, visionOS simulator and generic unsigned device | PASS; all produced executables are arm64; iOS minimum 26.0 and families 1/2; Vision minimum 26.0; local-network purpose present | `/private/tmp/glassdb-platforms-*` |
| 2026-07-21 | Full application matrix | macOS 27, iPhone 17 Pro iOS 27, iPad Pro 13-inch iOS 27, Vision Pro 26.5 and 27 | PASS; 101 tests on every destination | P8 artifacts |
| 2026-07-21 | Post-advisory regression | swift-nio 2.100.0, Mac/iPhone/Vision app suites, GlassDBKit, Citadel, Xcode Analyze, OSV | PASS; OSV reports no issues | `/private/tmp/glassdb-platforms-security-*` |
| 2026-07-21 | Complete-code scan | authored app, tests, GlassDBKit; vendor markers classified separately | PASS; no in-scope stub/TODO/fatalError/preconditionFailure/empty catch; `git diff --check` clean | `/private/tmp/glassdb-platforms-incomplete-scan.txt` |
| 2026-07-21 | Credential contract | glassdb + GlasSecretStore tests and source entitlement comparison with glas.sh | PASS automated; signed cross-app read remains external | P6 evidence |
| 2026-08-06 | Immediate audit remediation | macOS 27 app, generic iOS Simulator build, GlassDBKit, source/built privacy manifests, OSV, Gitleaks history/current tree, repository diff | PASS; app 103/103; GlassDBKit 25/25 with 3 live skips; iOS build and all static checks green | `memory-bank/tasks/immediate-audit-remediation.md` |

## Retained Custom-Component Exceptions

1. **Regular-width database grid** — SwiftUI `Table`, `TableColumnForEach`, customization, sorting, and selection were evaluated. The native table does not provide the existing frozen synthetic row gutter, arbitrary frozen columns, rectangular selection, spreadsheet paste mapping, or persisted freeform widths. The custom data plane remains on regular width; surrounding controls, menus, sheets, sharing, and compact iPhone results are native. Remove this exception when Apple exposes those behaviors together and the 100K/data-fidelity suite remains green.
2. **SQL text-system bridge** — SwiftUI `TextEditor` does not provide live attributed syntax, line numbers, caret-anchored completion/diagnostics, and selection preservation together. The minimal UIKit/AppKit bridge retains native text services and the shared parser/safety core. Remove it when SwiftUI supplies those capabilities without selection or undo regressions.
3. **Vision/Mac live database canvas appearance** — product-defining opacity (including fully transparent) and continuous blur apply only to the live database content, while app chrome remains system material. This is domain appearance, not replacement toolbar/window chrome. Preserve it unless a system API can express the same independent content-plane control.

Vendored Apple swift-nio-ssh state-machine preconditions, protocol `unimplemented` messages, upstream TODO comments, and Citadel example/test markers are dependency implementation details, not glassdb placeholder features. Shipping paths are covered through Citadel and GlassDBKit tests; they were not rewritten locally during an application release audit.
