# P0: Baseline, Reuse, and Native-UI Audit

**Status**: done
**Goal**: G0
**Depends on**: none

## Objective

Freeze a truthful pre-iOS baseline, reconcile current dirty work, and produce the binding component decision register that governs every later implementation choice.

## Reuse Baseline

Extend rather than duplicate:

- application/session/settings state in `glassdbApp.swift`, `DatabaseSessionManager.swift`, and `SettingsManager.swift`;
- connection CRUD and credential policy in `ConnectionManagerView.swift`, `ConnectionFormView.swift`, and GlasSecretStore;
- engine, TLS, SSH, typed values, capabilities, and mutations in GlassDBKit;
- adaptive iOS routing concepts proven by the sibling `../glas.sh/glas_sh/glas_shApp.swift:187-308`;
- existing native `NavigationSplitView`, `NavigationStack`, `List`, `Form`, `Table` candidates, `ContentUnavailableView`, `Charts`, alerts, file import/export, and command actions.

Do not fork models, managers, query execution, mutation logic, credential storage, or engine adapters for iOS.

## Work Plan

### Baseline truth

- [x] Inventory and resolve/checkpoint the existing dirty files without overwriting user work.
- [x] Record branch, commit, Xcode, Swift, SDK, package resolution, simulator runtimes, and device availability.
- [x] Run and preserve current Mac and Vision Pro builds/tests before adding iOS.
- [x] Record the current iOS compile probe and every unavailable API it exposes.
- [x] Record current known open issues, including connection-form confirmation semantics and any active Vision workspace issue.

### Native component register

- [x] Inventory every reusable control and every custom view/gesture/window bridge.
- [x] Assign each item: `native already`, `replace with native`, `native feasibility spike`, or `custom exception candidate`.
- [x] Map native replacements to OS 26 availability and OS 27 enhancement APIs.
- [x] Identify platform branches that incorrectly use `!os(macOS)` to mean visionOS.
- [x] Identify AppKit/UIKit imports and verify their compilation boundary.
- [x] Identify manual hit testing, pointer, selection, resize, scroll pinning, tabs, menus, dialogs, and materials that duplicate system behavior.

### UX and safety baselines

- [x] Capture reference behavior for connection, workspace, query, result, record, schema, settings, error, reconnect, import/export, and multiwindow flows.
- [x] Record protected Vision Pro opacity/blur behavior and native Mac window behavior.
- [x] Establish accessibility identifiers and screenshots only as supplemental evidence; record semantic behavior separately.

## Loop

`AUDIT FILE → FIND EXISTING PATTERN → MAP APPLE DEFAULT → CLASSIFY → VERIFY CURRENT BEHAVIOR → RECORD DECISION → NEXT FILE`

Repeat until every interactive surface has an owner and disposition.

## Exit Criteria

- [x] Baseline build/test evidence is reproducible.
- [x] No existing user change is lost or silently absorbed.
- [x] Component register covers all interactive surfaces and platform bridges.
- [x] Every planned new abstraction has a reuse justification.
- [x] G0 completion evidence is recorded before G1 starts.

## Evidence Log

| Date | Evidence | Result | Commit/Artifact |
|---|---|---|---|
| 2026-07-21 | Branch/toolchain/runtime inventory | `feature/multi-window-workspaces` at `dbe4d00`; Xcode 27.0 (27A5209h); Swift 6.4; iOS 27 and visionOS 26.4/26.5/27 simulators present; iOS 26 simulator runtime absent | local baseline |
| 2026-07-21 | GlassDBKit functional/unit baseline | 25 tests across QueryResult, SQLite adapter, binding, TLS, SSH trust, and transport-policy suites passed; 3 live MySQL/PostgreSQL tests skipped because their opt-in environments were not configured | `/private/tmp/platforms-plus-plus-glassdbkit-tests` |
| 2026-07-21 | Four-platform compile baseline | visionOS Simulator build passed; iOS reached asset compilation and exposed missing AppIcon; Mac caught active ConnectionForm compile errors; fixes assigned to milestone owners | `/private/tmp/platforms-plus-plus-{mac,vision,ios}` |
