# P3: Apple-Default Controls, Forms, Commands, and Sharing

**Status**: in progress — native form/command implementation and automated validation complete; manual accessibility and physical-input acceptance remains
**Goal**: G3
**Depends on**: P2

## Objective

Make every ordinary interaction feel system-native by removing duplicated chrome and relying on Apple controls, roles, placements, validation, menus, presentations, sharing, pointer effects, and input conventions.

## Forms and Data Entry

- [ ] Keep `Form`, `Section`, `LabeledContent`, `TextField`, `SecureField`, `Picker`, `Toggle`, `Stepper`, and `Slider` as the base controls.
- [ ] Use typed/format-based numeric fields for ports, limits, timeouts, sizes, and pagination.
- [ ] Apply appropriate keyboard types, submit labels, focus order, autocorrection, capitalization, text content types, and clear behavior.
- [ ] Validate at the field boundary and show native inline guidance before submission.
- [ ] Never prepopulate a password; preserve Keychain retrieval as a separate explicit state.
- [ ] Make connection creation expose one primary confirmation action. Save, Save & Connect, Test Connection, and Cancel must have unambiguous roles and shortcuts.
- [ ] Prove that entering or submitting host/port/user fields cannot trigger connection by accident.
- [ ] Use native file import for SQLite and SSH keys and security-scoped access correctly.

## Toolbars, Menus, and Commands

- [ ] Keep at most three logical toolbar groups and let the system manage overflow.
- [ ] Put navigation/sidebar controls leading, current context/title in its system location, and critical/primary actions trailing.
- [ ] Use SF Symbols and `Label`; tooltips/help and accessibility labels must describe the actual action.
- [ ] Use `ToolbarItemGroup`, `ControlGroup`, `Menu`, and command groups instead of manually drawn capsules or separators.
- [ ] Use native keyboard shortcuts without repurposing standard commands.
- [ ] Make all hidden context-menu actions discoverable in a toolbar, menu bar, swipe action, detail view, or command.
- [ ] Use native destructive roles and place destructive context actions last.

## Presentations and Status

- [ ] Use `ContentUnavailableView` for empty, failed, stale, and disconnected states where it fits.
- [ ] Use `alert` for short blocking messages, `confirmationDialog` for action choices, sheets for bounded tasks, navigation for long tasks, and inspectors for regular-width auxiliary editing.
- [ ] Keep custom error/dashboard content only when it conveys domain information unavailable in a standard presentation; use native buttons and roles inside it.
- [ ] Respect Reduce Transparency and Increase Contrast without removing the Vision workspace’s user-controlled transparency range.

## Sharing and Interoperability

- [ ] Prefer `ShareLink`, `Transferable`, `fileImporter`, `fileExporter`, pasteboard APIs, and drag/drop.
- [ ] Support selected-row export, SQL document import/export, and result sharing without a custom share sheet.
- [ ] Provide accessible alternatives to drag/drop.

## Control Audit Loop

`CUSTOM CONTROL → FIND NATIVE EQUIVALENT → PORT REAL WORKFLOW → TEST TOUCH/POINTER/KEYBOARD/VOICEOVER → DELETE CUSTOM PATH OR LOG EXCEPTION`

## Exit Criteria

- [ ] Standard UI inventory has no unjustified custom control or hand-painted system chrome.
- [ ] Connection forms cannot submit accidentally and use one explicit primary action.
- [ ] Toolbars adapt through system overflow and remain legible at all supported widths.
- [ ] Forms pass keyboard, touch, pointer, validation, Dynamic Type, and VoiceOver checks.
- [ ] Import/export/share flows use system presentations and preserve data fidelity.

## Evidence Log

| Date | Surface | Native API | Result | Exception/Commit |
|---|---|---|---|---|
| 2026-07-21 | Connection add/edit form | `Form`, `Section`, `LabeledContent`, typed keyboard semantics, `FocusState`, toolbar roles | Pass (compile + focused tests) | `ConnectionFormView.swift:274` makes submit focus-only; explicit Save/Test/Save & Connect actions begin at lines 352, 1121, and 1136. The focused submission and validation tests passed on macOS 27 and iPhone 17 simulator. |
| 2026-07-21 | Editing saved credentials | `SecureField` + explicit Keychain resolution | Pass (compile) | Password state is never prepopulated; `ConnectionFormView.swift:1343` resolves an existing secret only for an explicit Test or Save & Connect action. |
| 2026-07-21 | iOS Settings and connection-list actions | grouped `Form`, native toolbar/menu/context menu/swipe actions | Pass (compile) | `SettingsView.swift:129` supplies the iOS grouped form; connection and SSH-key actions use native menus and swipe roles. iPhoneOS 27 arm64 and generic visionOS 27 builds succeeded. |
| 2026-07-21 | Explicit connection confirmation | `FocusState`, explicit Test and Save & Connect actions, native error presentation | Pass (101-test matrix) | `connectionFormSubmissionOnlyAdvancesOrDismissesFocus` and `connectionFormValidationGatesDatabaseSQLiteAndSSHTunnelInputs` passed on Mac, iPhone, iPad, visionOS 26.5, and visionOS 27. Host editing cannot implicitly connect. |
| 2026-07-21 | Platform toolbar/control regression | native toolbar placements, menus, labels, roles, and system overflow behavior | Pass (automated) | All five platform/runtime suites passed. Physical VoiceOver, Voice Control, Switch Control, Full Keyboard Access, and pointer acceptance remain in P8. |
