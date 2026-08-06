# Platforms Plus Plus — Native iPhone, iPad, and Apple UX

**Status**: automated implementation and simulator validation complete; signed-device, live-server, accessibility-hardware, and human release gates remain open
**Release name**: `platforms-plus-plus`
**Target baseline**: iOS/iPadOS 26.0+, with additive iOS/iPadOS 27 features guarded by availability
**Architecture**: one shared native SwiftUI application target; iPhone and iPad device families; no Catalyst
**Release principle**: Apple defaults first. Custom UI is permitted only for a documented database-specific capability that Apple does not provide.

## Release Goal

Ship a daily-driver native iPhone and iPad database manager that preserves the shared Glass-family transport, credential, query, mutation, and safety core while presenting each workflow through Apple-standard navigation, windows, toolbars, menus, forms, tables, inspectors, text editing, sharing, accessibility, and input behavior.

The release is complete only when:

1. iPhone and iPad build and run from the existing shared app target at iOS/iPadOS 26.0 or newer.
2. iPad behaves as a resizable, multiwindow productivity app with a menu bar, keyboard, pointer, touch, drag/drop, and state restoration.
3. iPhone provides a focused compact experience rather than a squeezed desktop or Vision Pro interface.
4. Native controls replace custom chrome and interaction models wherever Apple provides an adequate API.
5. Every retained custom component has a written exception, an Apple-API feasibility result, accessibility coverage, and regression tests.
6. macOS and visionOS retain feature parity and their platform-specific identity, including the Vision Pro live-workspace opacity and blur controls.

## Product Invariants

- The Vision Pro live database workspace continues to support 0–100% opacity and continuous blur. This setting must not leak into ordinary iPhone/iPad navigation or system bars.
- General application chrome uses system materials, bars, containers, safe areas, symbols, menus, and controls. Do not hand-paint Liquid Glass.
- iPhone/iPad support shares the existing `GlassDBKit`, Citadel, GlasSecretStore, connection, session, query, mutation, and audit behavior. No parallel engine implementation.
- MySQL, PostgreSQL, SQLite, TLS, SSH tunnels, host-key verification, typed values, safe mutations, and error propagation must behave consistently across platforms.
- Eligible GlasSecretStore credentials may participate in family sharing/synchronization as implemented by their policy. Secure Enclave and user-presence secrets remain device-bound.
- The approved *Magic / First Class* direction presents **My Connections** across
  glas.sh and glassdb. It remains an open C3/P6 requirement: today’s same-device
  compatibility records and `ThisDeviceOnly` credentials are not cross-device
  completion evidence.
- No fake data, stub implementation, placeholder actions, silent errors, or unverified completion claims.
- No Catalyst shipping artifact. iPhone and iPad are native iOS-family destinations.

## Apple Guidance Baseline

The release applies the relevant 2025/2026 platform guidance and current HIG:

- [What’s new in SwiftUI — WWDC25](https://developer.apple.com/videos/play/wwdc2025/256/): Liquid Glass adoption through standard controls, iPad menu bar commands, resizable windows, adaptive split navigation, and rich text editing.
- [Elevate the design of your iPad app — WWDC25](https://developer.apple.com/videos/play/wwdc2025/208/): responsive navigation, system window controls, pointer behavior, and iPad menu bar design.
- [Build a SwiftUI app with the new design — WWDC25](https://developer.apple.com/videos/play/wwdc2025/323/): native controls inherit the current design; avoid replacing them with imitations.
- [What’s new in SwiftUI — WWDC26](https://developer.apple.com/videos/play/wwdc2026/269/): toolbar visibility priority, overflow, pinned trailing actions, minimization, reorderable content, swipe actions, data-flow improvements, and the new Document model.
- [WWDC26 SwiftUI guide](https://developer.apple.com/wwdc26/guides/swiftui/): 2027-release toolbar and SwiftUI adoption path.
- [Sidebars](https://developer.apple.com/design/human-interface-guidelines/sidebars), [Toolbars](https://developer.apple.com/design/human-interface-guidelines/toolbars), [Windows](https://developer.apple.com/design/human-interface-guidelines/windows), [Lists and tables](https://developer.apple.com/design/human-interface-guidelines/lists-and-tables), [Entering data](https://developer.apple.com/design/human-interface-guidelines/entering-data), [Keyboards](https://developer.apple.com/design/human-interface-guidelines/keyboards/), and [Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility).

The source review established these facts:

- `Packages/GlassDBKit/Package.swift:8-12` already declares iOS 26 and the vendored Citadel package supports iOS 17 or newer.
- `glassdb.xcodeproj/project.pbxproj:391` and `:484` currently omit iPhone/iPad platforms.
- `glassdb/Constants.swift:469-480`, `glassdb/DatabaseWorkspaceView.swift:166-220`, and similar `!os(macOS)` branches currently conflate visionOS with future iOS.
- `glassdb/ConnectionManagerView.swift:37-211`, `glassdb/ConnectionFormView.swift:330-458`, `glassdb/SchemaBrowserView.swift:53-143`, and `glassdb/SettingsView.swift:126-177` already use strong native SwiftUI foundations.
- `glassdb/DatabaseWorkspaceView.swift:449-506`, `glassdb/TableDetailView.swift:2075-2301`, and `glassdb/HighlightedTextEditor.swift:12-188` are the principal custom-component feasibility targets.
- The sibling `../glas.sh/glas_shApp.swift:187-308` and `../glas.sh/glas_sh/ConnectionManagerView.swift:17-69` prove a shared-target iOS router and compact/regular adaptation pattern.

## Apple-Default Decision Rule

For every surface, use this order:

1. Use a native SwiftUI component and its default style.
2. Configure native placement, role, selection, sorting, formatting, validation, customization, and accessibility APIs.
3. Compose native components with `Grid`, `GroupBox`, `LabeledContent`, `ContentUnavailableView`, `Form`, or Swift Charts.
4. Bridge to UIKit only when SwiftUI lacks a required capability and UIKit provides a standard component.
5. Create or retain custom UI only when neither framework provides the capability.

A custom exception must record:

- the native APIs evaluated;
- the specific missing behavior;
- why losing that behavior would make glassdb materially worse;
- input, accessibility, performance, and appearance validation;
- the condition under which the exception can be deleted later.

Custom branding, syntax colors, chart composition, or domain-specific content are not automatically violations. Reimplementing a system button, toolbar, tab bar, table selection model, form control, sheet, alert, menu, pointer effect, scroll behavior, or window control is.

## Release Goals

| Goal | Objective | Completion signal |
|---|---|---|
| G0 | Freeze truthful baseline and Apple-default inventory | Existing Mac/Vision evidence preserved; custom inventory complete |
| G1 | Add the native iOS-family compile spine | iPhone and iPad Debug/Release builds pass at iOS 26 baseline |
| G2 | Deliver adaptive native shell and windows | Compact and regular navigation, iPad multiwindow, commands, restoration pass |
| G3 | Replace custom chrome and forms with Apple defaults | Control audit has no unjustified custom interaction component |
| G4 | Deliver native table and record workflows | Browse/select/sort/customize/edit/copy/export work with native behavior |
| G5 | Deliver premier SQL and schema tooling | Native editor feasibility resolved; SQL/schema workflows retain daily-driver quality |
| G6 | Prove network, credential, and lifecycle parity | Engines/TLS/SSH/Keychain/reconnect plus canonical cross-app tunnel journey pass on device |
| G7 | Adopt valuable OS 27 enhancements safely | Availability-gated enhancements pass; iOS 26 fallback remains native |
| G8 | Complete accessibility, performance, security, and pen QA | Required matrix passes with no unexplained blocker |
| G9 | Integrate, reconcile, and release | All goals/evidence complete; no stubs; explicit human release approval obtained |

Only one execution goal is active at a time. The release-level objective stays active across all milestones; milestone goals are sequential sub-objectives with objective exit evidence. A goal is never marked complete because code compiles, a token budget is ending, or the next milestone is attractive.

## Continuous Execution Model

This plan is designed for one continuous implementation run after the user explicitly approves implementation. That implementation approval authorizes in-scope work across P0-P9 without stopping between milestones. Stop only for:

- a destructive or external action not covered by the approved plan;
- an architectural discovery that materially changes scope;
- provisioning, signing, physical-device, or account access that requires the user;
- a product decision for which two valid choices create materially different behavior.

### Outer milestone loop

For P0 through P9:

`GOAL → PLAN → REUSE AUDIT → BUILD → DIFF → QA → ADVERSARIAL QA → CROSS-PLATFORM REGRESSION → STUB SCAN → EVIDENCE → NEXT GOAL`

### Inner implementation loop

Within each milestone:

1. Select the smallest complete vertical slice.
2. Identify the existing service/view/model to extend.
3. Identify the Apple default component and platform availability.
4. Implement without a second source of truth.
5. Build iPhone, iPad, Mac, and Vision Pro as soon as the slice compiles.
6. Run focused tests, then affected-platform suites.
7. Inspect the diff for duplicated components, platform leakage, unsafe state, and accessibility gaps.
8. Search touched code for `TODO`, `FIXME`, `future`, `stub`, `fatalError`, `preconditionFailure`, placeholder actions, and silent catches; repair every in-scope finding.
9. Repeat until the milestone exit criteria have objective evidence.

### Native-component challenge loop

Before retaining custom UI:

`NATIVE API SPIKE → BEHAVIOR MATRIX → ACCESSIBILITY/INPUT TEST → PERFORMANCE TEST → KEEP NATIVE OR DOCUMENT EXCEPTION`

The spike must test the real database shape, including arbitrary dynamic columns, large values, narrow windows, selection, editing, copy/export, and failure states. A screenshot is not sufficient evidence.

## Milestone Dashboard

| ID | Milestone | Status | Depends on | Primary result |
|---|---|---|---|---|
| P0 | [Baseline, Reuse, and Native-UI Audit](P0-baseline-native-ui-audit.md) | done | — | Frozen truth and component decision register |
| P1 | [iOS-Family Target and Platform Boundaries](P1-ios-target-platform-boundaries.md) | done | P0 | Native iPhone/iPad compile spine |
| P2 | [Adaptive Shell, Navigation, and Windows](P2-adaptive-shell-navigation-windows.md) | in progress | P1 | Automated shell/window coverage green; physical iPad interaction gate open |
| P3 | [Apple-Default Controls, Forms, Commands, and Sharing](P3-native-controls-forms-commands.md) | in progress | P2 | Native forms/commands implemented; manual accessibility/input gate open |
| P4 | [Native Tables, Results, and Record Workflows](P4-native-tables-record-workflows.md) | in progress | P2-P3 | Compact native list and tested professional-grid exception; live-device QA open |
| P5 | [SQL Editor and Schema Management](P5-sql-editor-schema-management.md) | in progress | P2-P4 | Shared SQL/schema workflows green; manual editor/device acceptance open |
| P6 | [Network, Credentials, and Lifecycle Parity](P6-network-credentials-lifecycle.md) | in progress | P1-P5 | Automated trust/lifecycle/credential parity green; signed My Connections and live-network gates open |
| P7 | [iOS/iPadOS 27 Enhancements and Platform Polish](P7-os27-platform-polish.md) | in progress | P2-P6 | Valuable guarded enhancement adopted; local iOS 26 runtime unavailable |
| P8 | [Accessibility, Performance, Security, and Pen QA](P8-accessibility-performance-security-qa.md) | in progress | P1-P7 | Automated scale/adversarial/static gates green; physical accessibility and Instruments gates open |
| P9 | [Integration, Stub Repair, and Release Validation](P9-integration-release-validation.md) | in progress | P0-P8 | Automated release candidate green; external gates and human approval open |

Allowed statuses: `not started`, `in progress`, `blocked`, `done`.

## Cross-Platform UX Contract

| Workflow | iPhone | iPad | Mac | Vision Pro |
|---|---|---|---|---|
| Connection library | `NavigationStack` + `List` | `NavigationSplitView` | native split view | spatial split view/window |
| Connected areas | native top-level `TabView` or stack destinations | split workspace with native tabs/toolbars | window/tab workspace | window/tab workspace + ornaments |
| Schema hierarchy | databases → tables navigation | sidebar/content/detail | resizable sidebar | sidebar appropriate to spatial window |
| Results | compact record-summary table/list | multicolumn `Table` first | desktop grid/native table decision retained | spatial grid/native table decision retained |
| Row editing | navigation destination or adaptive sheet | inspector/adaptive sheet | sheet/inspector | sheet |
| Settings | native sheet/navigation | native sheet | `Settings` scene | Settings window |
| Multiple windows | no product claim | per-connection/workspace windows | per-connection/workspace windows | per-connection/workspace windows |
| Commands | toolbar, menus, shortcuts where keyboard exists | menu bar + keyboard shortcuts | menu bar + keyboard shortcuts | shortcut overlay + ornaments |

## Release Exit Gates

- [x] One shared native target builds iPhone, iPad, Mac, and Vision Pro with accurate deployment/platform metadata.
- [ ] iPhone and iPad require iOS/iPadOS 26.0+, and OS 27 features are guarded with tested 26 fallbacks.
- [x] No iOS code reaches visionOS ornament/window APIs and no Vision Pro behavior is weakened by iOS adaptation.
- [ ] All standard controls, navigation, bars, menus, tables, forms, presentations, sharing, and accessibility use Apple defaults where defaults meet requirements.
- [ ] Every custom exception has completed the native-component challenge loop and is listed in P9.
- [ ] iPad supports arbitrary resizing, portrait/landscape, multiple windows, menu bar commands, keyboard, pointer, touch, and restoration.
- [ ] iPhone remains usable in portrait and landscape without squeezed desktop UI, nested tab bars, clipped toolbars, or hidden primary actions.
- [x] Connection forms never submit or connect from ordinary field editing; one explicit primary confirmation action exists.
- [x] Native table feasibility is documented; iPhone uses compact native summaries and regular-width platforms retain the tested database-grid exception.
- [ ] MySQL, PostgreSQL, SQLite, TLS, SSH tunnel, host trust, local-network permission, Keychain policies, suspend/resume, reconnect, and error recovery pass.
- [ ] The canonical glas.sh/iPhone -> glassdb/Vision Pro SSH-tunnel journey,
  reverse direction, delayed-secret recovery, account change, and device-bound
  enrollment pass before any My Connections availability claim.
- [ ] Dynamic Type, VoiceOver, Voice Control, Switch Control, Full Keyboard Access, Reduce Motion, Reduce Transparency, Increase Contrast, and minimum target sizes pass.
- [ ] Minimum and latest runtimes, physical iPhone/iPad, Mac, and Vision Pro regression gates pass or carry explicit external blockers.
- [x] No unexplained application warning, in-scope TODO/stub path, fake production data, empty catch, or overstated automated claim remains.
- [ ] Human release approval is recorded before TestFlight/App Store distribution.

## Evidence Log

| Date | Milestone | Evidence | Commit/PR | Result |
|---|---|---|---|---|
| 2026-07-21 | Planning audit | Apple WWDC25/26 and HIG review; source/platform/package audit; sibling iOS pattern review; iOS compile-probe findings | planning tree | plan created; implementation not started |
| 2026-07-21 | P0 baseline | Xcode 27.0 (27A5209h), Swift 6.4, iOS 27 and visionOS 26.4/26.5/27 runtimes inventoried; GlassDBKit 25-test suite passed with 3 environment-gated live-engine tests skipped | feature/multi-window-workspaces @ dbe4d00 + dirty implementation tree | implementation started; minimum iOS 26 runtime unavailable locally |
| 2026-07-21 | P1 native iOS-family target | iPhone/iPad Debug builds, generic simulator/device Release builds, iOS test-target compile, arm64 Mac/Vision regressions, and generated metadata inspection passed | dirty coordinated implementation tree; detailed logs in P1 | done |
| 2026-07-21 | P2-P7 implementation regression | macOS, iPhone 17 Pro, iPad Pro 13-inch, visionOS 26.5, and visionOS 27 application suites each passed all 101 tests; generic unsigned iOS and visionOS device builds passed | `/private/tmp/glassdb-platforms-*` | automated matrix passed |
| 2026-07-21 | Shared credential contract | GlasSecretStore passed 69 tests in 13 suites; glassdb tests proved UUID identities, atomic glassdb/glas.sh compatibility writes, rollback, access-group validation, and private/device-bound policy separation | `../GlasSecretStore`; app test logs | automated contract passed; signed cross-app device read remains open |
| 2026-07-21 | P8 security remediation | OSV found swift-nio 2.96.0 advisories; lock advanced to Apple swift-nio 2.100.0; OSV rerun reported no issues; GlassDBKit 25 tests, Citadel 31 tests, Xcode analyze, macOS 101, iPhone 101, and visionOS 27 101 all passed post-remediation | `Package.resolved`; `/private/tmp/glassdb-platforms-security-*` | passed |

## Current Release Disposition

The code and automated simulator/build matrix are complete for the current tree. The release is not approved for distribution yet. These gates require state this workspace cannot manufacture:

- correctly provisioned physical iPhone, iPad, Mac, and Vision Pro installs, including the signed glassdb/glas.sh shared-Keychain read;
- live MySQL/PostgreSQL, TLS failure/pinning, SSH key/password/host-rotation, direct Tailscale, path-loss, and local-network denial/re-enable exercises;
- physical accessibility/input review, Instruments allocations/leaks/hangs/energy runs, and an iOS 26 runtime fallback pass (only iOS 27 is installed locally);
- explicit human release approval before TestFlight, App Store, or signed distribution.

These are external acceptance gates, not hidden implementation stubs. Managed-copy SQLite, generated SQL safety, lifecycle recovery, credential rollback, scale, simulator UI, package, analyzer, and dependency-advisory paths have executable green evidence.
