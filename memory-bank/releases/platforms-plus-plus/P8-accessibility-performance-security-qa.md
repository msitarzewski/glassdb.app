# P8: Accessibility, Performance, Security, and Pen QA

**Status**: in progress — automated scale, adversarial, dependency, analyzer, and simulator matrix green; physical accessibility, Instruments, and live-network penetration gates remain
**Goal**: G8
**Depends on**: P1-P7

## Objective

Prove that the complete four-platform product is inclusive, responsive, secure, resilient, and safe under hostile and degraded conditions.

## Accessibility and Input Matrix

- [ ] VoiceOver reading order, labels, values, hints, headings, tables, charts, errors, validation, and actions.
- [ ] Voice Control names and visible labels.
- [ ] Switch Control traversal and activation.
- [ ] Full Keyboard Access across every interactive element.
- [ ] Standard keyboard shortcuts and menu discoverability.
- [ ] Touch targets at least 44×44 points on iPhone/iPad.
- [ ] Pointer effects, secondary click, hover, resize, selection, and drag/drop on iPad.
- [ ] Dynamic Type through accessibility sizes without clipped forms/toolbars or unusable tables.
- [ ] Bold Text, Button Shapes, Differentiate Without Color, Increase Contrast, Reduce Transparency, Reduce Motion, and Dark/Light modes.
- [ ] Chart accessibility summaries and nonvisual data alternatives.

## Layout Matrix

- [ ] Supported iPhone sizes in portrait/landscape on OS 26 and 27.
- [ ] Supported iPad sizes in full screen, narrow window, half screen, large window, and multiple windows.
- [ ] Software and hardware keyboards present/dismissed.
- [ ] Safe areas, status areas, system window controls, menu bar, toolbars, inspectors, sheets, and popovers.
- [ ] Localization stress with long English and representative right-to-left layout.

## Performance

- [ ] Cold/warm launch and connection-library responsiveness.
- [x] Repeated connect/query/disconnect and multiwindow ownership (automated lifecycle/ownership coverage).
- [x] 100/1K/10K row browse and export; wide-column and large-value cases (including a 100K-row CSV/filter stress case).
- [ ] SQL editor large-document typing, highlighting, completion, and find.
- [ ] Schema discovery across many databases/tables.
- [ ] Memory warnings, backgrounding, restoration, and leak checks.
- [ ] Instruments runs for allocations, leaks, hangs, energy, and main-thread stalls.
- [ ] Verify lazy containers have stable identity and do not produce dynamic subview-count slow paths.

## Security and Pen Testing

- [ ] TLS downgrade/pinning/certificate mismatch.
- [ ] SSH host-key first use/change/rotation and hostile key formats.
- [ ] Credential access denial, wrong access group, sync collision, delete race, and locked device.
- [ ] Local-network denial and hostile endpoint responses.
- [x] SQL injection attempts against generated mutation/filter/sort/schema paths covered by the shared builders.
- [x] Import/export delimiter, encoding, path, oversized payload, malformed JSON/SQL, NULL/binary/precision, and escaping cases.
- [x] Cancellation/timeout/transaction conflict and known-disconnected/closed-transport state handling.
- [x] Static analysis, secret scan, dependency/advisory review, strict-concurrency builds, and warning inventory.

## QA Loop

`FUNCTIONAL → UNIT → INTEGRATION → UI/INPUT → ACCESSIBILITY → SCALE → FAILURE INJECTION → SECURITY/PEN → FIX → FULL REGRESSION`

Repeat until a full pass produces no blocker or unexplained warning.

## Exit Criteria

- [ ] Required accessibility and input matrix passes on physical iPhone/iPad and applicable Mac/Vision hardware.
- [ ] Performance budgets and scale cases pass without leaks, hangs, or unbounded memory.
- [ ] Security/adversarial cases fail closed and recover clearly.
- [ ] No unexplained warning, skip, flaky test, or silent error remains.
- [ ] Residual risks have owners and explicit release disposition.

## Evidence Log

| Date | Suite/Device | Cases | Result | Artifact/Issue |
|---|---|---|---|---|
| 2026-07-21 | macOS 27 Apple Silicon | Full application suite, Settings layout, workspace/session ownership, credentials, SQL/schema safety, import/export, 100K scale | PASS; 101/101 | `/private/tmp/glassdb-platforms-security-mac-test.log` |
| 2026-07-21 | iPhone 17 Pro / iOS 27 simulator | Full application suite including compact routes, form gates, credentials, lifecycle, data fidelity, and scale | PASS; 101/101 | `/private/tmp/glassdb-platforms-security-iphone-test.log` |
| 2026-07-21 | iPad Pro 13-inch / iOS 27 simulator | Full shared application suite plus regular-width launch/split-view smoke | PASS; 101/101 | `/private/tmp/glassdb-platforms-ipad-test.log` |
| 2026-07-21 | Apple Vision Pro / visionOS 26.5 | Full shared application suite | PASS; 101/101 | `/private/tmp/glassdb-platforms-vision265-test.log` |
| 2026-07-21 | Apple Vision Pro / visionOS 27 | Full suite before and after transport advisory remediation | PASS; 101/101 post-remediation | `/private/tmp/glassdb-platforms-security-vision27-test.log` |
| 2026-07-21 | GlassDBKit | typed binding, SQLite real-file/WAL, TLS/SSH validation, trust, buffer bounds, engine capabilities | PASS; 25 tests in 3 suites; 3 opt-in live-server cases skipped because environments were absent | `/private/tmp/glassdb-platforms-glassdbkit-security-test.log` |
| 2026-07-21 | Citadel | local SSH/SFTP end-to-end, key parsing, rejection, invalid-state handling | PASS; 31 tests, 5 environment-gated skips | `/private/tmp/glassdb-platforms-citadel-security-test.log` |
| 2026-07-21 | GlasSecretStore | Keychain configuration, canonical Glass accounts, SSH keys/trust, migration, Secure Enclave integration | PASS; 69 tests in 13 suites | `../GlasSecretStore` `swift test` |
| 2026-07-21 | Dependency/static analysis | OSV source scan, exact lock resolution, Xcode Analyze, authored-code secret/stub/empty-catch scan | Initial swift-nio 2.96.0 advisories repaired by 2.100.0; rerun: no issues; Analyze succeeded | `/private/tmp/glassdb-platforms-security-analyze.log`; project `Package.resolved` |

## External Acceptance Gates

The following are not simulated as passes:

- physical VoiceOver, Voice Control, Switch Control, Full Keyboard Access, Dynamic Type/accessibility sizes, pointer, touch-target, Reduce Motion/Transparency, Increase Contrast, and RTL review;
- physical iPad resize/multiwindow/menu-bar/keyboard/pointer acceptance and physical Vision Pro ornament/gaze acceptance;
- Instruments allocations/leaks/hangs/energy/main-thread sessions;
- live hostile TLS/SSH/Tailscale/local-network/path-loss cases and signed Keychain/Secure Enclave behavior.

These gates require hardware, signed provisioning, external servers, or interactive assistive technologies. They remain explicit release blockers for human disposition, not automated passes.
