# Intents — System Actions and Apple Platform Integration

**Status**: planned; implementation not started
**Release name**: `intents`
**Scheduling**: independent future release; explicitly not a dependency or exit gate for the active release candidate
**Platforms**: native arm64 iPhone, iPad, Apple-silicon Mac, and Vision Pro on the application baselines recorded in `memory-bank/projectbrief.md#Platform Baseline`
**Release principle**: App Intents is glassdb's system command layer, not an unattended database execution engine.

## Release Goal

Make glassdb's safest, highest-value workflows discoverable through Apple system experiences so a user can reach the correct connection, saved query, SQL editor, database, or table with less navigation on every supported platform.

The first release favors foreground navigation and explicit user control:

1. Siri, Shortcuts, and supported Spotlight experiences can open a named glassdb destination.
2. App Shortcuts provide a small, useful default catalog without setup.
3. Widgets and controls expose navigation or reconnect actions only where the platform supplies those surfaces.
4. App entities use stable existing identifiers without exposing secrets or raw SQL.
5. No intent silently performs arbitrary SQL, mutations, credential retrieval, production reconnects, or unrestricted exports.

Adding `AppIntents.framework` may remove Xcode's metadata-extraction diagnostic as a side effect. Silencing that diagnostic is not a product requirement and is not sufficient justification for this release.

## Non-Gating Contract

- This plan does not modify the goals, dependencies, exit gates, or release disposition of `memory-bank/releases/platforms-plus-plus/README.md` or `memory-bank/releases/codex-completions/README.md`.
- Current release acceptance continues without waiting for any milestone in this directory.
- Implementation begins only after separate user approval and may proceed on its own branch after the active release tree is safely reconciled.
- The release can ship its navigation and discovery core without the optional read-only query automation described below.

## Reuse Baseline

App Intents must adapt existing owners rather than create another model, router, persistence layer, or database session authority.

| Existing owner | Reuse contract | Source |
|---|---|---|
| `DatabaseConnectionConfig` | Stable connection identity and safe display metadata; never donate host, username, SSH fields, or credentials | `glassdb/Models.swift:13-34` |
| `ConnectionManager` | Resolve a connection entity by its existing UUID | `glassdb/ConnectionManager.swift:60-124` |
| `SavedQuery` / `SettingsManager` | Resolve saved-query identity and usage; keep raw SQL out of display, indexing, phrases, and logs | `glassdb/Models.swift:303-330`, `glassdb/SettingsManager.swift:121`, `glassdb/SettingsManager.swift:313-355` |
| `WorkspaceSelection` | Canonical destinations for connection, database, table, and SQL-editor navigation | `glassdb/DatabaseWorkspaceView.swift:17-63` |
| `DatabaseWorkspaceWindowRequest` | Existing serializable workspace launch request | `glassdb/DatabaseWorkspaceView.swift:65-83` |
| `DatabaseSessionManager` | Register workspaces, reconnect sessions, and execute queries; intents must not create a second session manager | `glassdb/DatabaseSessionManager.swift:51-68`, `glassdb/DatabaseSessionManager.swift:309-329`, `glassdb/DatabaseSessionManager.swift:457-485` |
| App scene/router | Preserve native multiwindow routing and the compact iPhone in-scene route | `glassdb/glassdbApp.swift:24-127`, `glassdb/glassdbApp.swift:130-175` |
| SQL safety core | Classify every future automation candidate with the existing deterministic policy | `glassdb/SQLHighlighter.swift:34-47`, `glassdb/SQLHighlighter.swift:413-445` |

Any new intent-specific type must remain a thin adapter over these owners. A new file or directory requires a fresh reuse analysis when implementation starts.

### Required reuse refactors

The current UI privately owns the transition from a saved connection UUID to an active session and then to the platform-appropriate workspace. `ConnectionManagerView` retrieves credentials, connects, opens the iPhone router or a native window, and searches for an existing connected session at `glassdb/ConnectionManagerView.swift:640-728`. I0 must specify, and I2 must refactor, the smallest reusable connection/session/workspace-opening seam out of those private view methods. The view and intents must call the same seam; copying this flow into an intent is prohibited.

`DatabaseWorkspaceWindowRequest` currently carries only a session UUID and `WorkspaceSelection`. Opening a saved query therefore requires a backward-compatible typed launch payload or equivalent existing-state handoff containing the saved-query UUID, never its raw SQL. The workspace resolves that UUID through `SettingsManager` after activation. Database and table intents continue to reuse `WorkspaceSelection` directly.

Host-key trust, missing credentials, local-network permission, and user-presence prompts remain app-owned UI. An intent may bring the user to that recovery flow but may not reproduce or bypass it.

## Apple Guidance Baseline

- [App Intents](https://developer.apple.com/documentation/appintents) — actions and app content exposed to Siri, Spotlight, Shortcuts, widgets, controls, Focus, and Apple Intelligence.
- [App Shortcuts](https://developer.apple.com/documentation/appintents/app-shortcuts) — preconfigured high-value actions available without requiring the user to build a shortcut first.
- [App entities](https://developer.apple.com/documentation/appintents/app-entities) — stable app concepts, entity queries, and optional Spotlight indexing.
- [AppIntent](https://developer.apple.com/documentation/AppIntents/AppIntent) — execution targets and authentication policy.
- [Intent infrastructure](https://developer.apple.com/documentation/appintents/intent-infrastructure) — dependency injection and invocation context without duplicating app services.
- [Widgets, Live Activities, and controls](https://developer.apple.com/documentation/appintents/widgets-live-activities-and-controls) — interactive system surfaces powered by intents.
- [Apple Intelligence and Siri](https://developer.apple.com/documentation/appintents/apple-intelligence-and-siri-ai) — entity donation, on-screen association, and schema-based actions; availability-qualified capabilities must not become unverified product promises.
- [Explore new advances in App Intents](https://developer.apple.com/videos/play/wwdc2025/260/) — Mac Shortcuts, Spotlight actions, automation, and current framework direction.

Revalidate current Apple documentation, OS availability, and review requirements when implementation begins. Do not freeze beta-era API assumptions into the architecture.

## Entity and Privacy Contract

| Entity | Identifier | Permitted representation | Indexing policy |
|---|---|---|---|
| Connection | Existing connection UUID | User-assigned name, engine, favorite state | Off by default; optional names-only indexing after explicit consent |
| Saved query | Existing saved-query UUID | User-assigned title | Raw SQL is never indexed, donated, spoken, logged, or used in shortcut phrases |
| Database | Connection UUID plus database name | Name only after explicit connection selection | Live resolution by default; no blanket indexing |
| Table | Connection UUID plus database/table names | Qualified name after explicit connection selection | Live resolution by default; no blanket indexing |
| Active workspace | Ephemeral workspace/session identity | Current in-app destination only | Never indexed or synchronized |

`SyncableEntity` is out of scope until the approved My Connections program establishes and validates stable cross-device endpoint identity. Visible metadata never implies that credentials are locally available.

Connection names, saved-query titles, database names, and table names can themselves be sensitive. Any future indexing setting must explain which strings leave glassdb's private UI for system discovery, support revocation, and remove donated/indexed entries after deletion or opt-out.

## Core Intent Catalog

| Intent | Phase | Default execution | Required behavior |
|---|---|---|---|
| Open Connection | I2 | Foreground | Resolve an existing UUID, authenticate when required, and route through the existing connection/workspace flow |
| New SQL Editor | I2 | Foreground | Open the `.query` destination for an explicitly selected connection; never prefill generated SQL |
| Open Saved Query | I2 | Foreground | Draft the existing saved query in an editor; opening is not execution |
| Open Database | I2 | Foreground | Open `WorkspaceSelection.database` after resolving the selected connection |
| Open Table | I2 | Foreground | Open `WorkspaceSelection.table` after resolving connection, database, and table |
| Reconnect Workspace | I2 | Foreground and authenticated as required | Reuse `DatabaseSessionManager.reconnect`; surface missing credentials and trust decisions in glassdb |
| Open Favorite Connection | I3 | Foreground control/widget action | Select from current favorites and open glassdb; no silent background session |
| Run Approved Read-Only Query | I5, optional follow-on | Foreground by default | Accept only an existing approved saved-query ID and pass every safety, bound, timeout, authentication, and output gate below |

The initial App Shortcut catalog should contain only two to five common actions. Candidate defaults are Open Connection, Open Saved Query, New SQL Editor, Reconnect Workspace, and Open Favorite Connection.

## Cross-Platform Contract

| Platform | Primary value | Required acceptance |
|---|---|---|
| Mac | Spotlight actions, Siri, Shortcuts, personal automations, menu-bar or Control Center controls | Correct native window activation, existing-workspace reuse, keyboard flow, locked/unlocked Keychain behavior |
| iPhone | Siri, Shortcuts, Spotlight, Action button, Lock Screen, and Control Center where supported | Route through `IOSAppRouter`; never present a second desktop-style workspace or assume multiwindow |
| iPad | Siri, Shortcuts, Spotlight, controls, hardware input, and native multiwindow | Open the requested scene in compact and regular width; preserve arbitrary resizing and window ownership |
| Vision Pro | Voice-first Siri/Shortcuts entry into a spatial database workspace | Open the correct spatial window and selection without assuming iPhone-only controls or weakening the transparent workspace contract |

One semantic intent/entity model should serve all supported targets. Platform checks may choose routing or presentation, but must not fork database, credential, safety, or persistence behavior.

## Execution and Security Boundary

### Allowed in the core release

- Resolve stable IDs to current local models.
- Bring glassdb to the foreground and open an existing destination.
- Request authentication, credentials, network permission, or host-trust review through existing glassdb UI.
- Report bounded status such as “connection requires attention” without including host, username, SQL, schema, or server error details in system-visible dialog.
- Adapt behavior to the invocation context without changing security policy.

### Prohibited in the core release

- Arbitrary SQL text as an intent parameter.
- Automatic execution when opening a saved query.
- DDL, DML, session-control, destructive, unknown, or multi-statement automation.
- Password, passphrase, SSH key, connection string, host, or username donation/indexing.
- Silent background connection to a production database.
- Unbounded rows, files, result snippets, history, or exports.
- A new credential catalog, endpoint identity, cross-device sync claim, or parallel database session owner.
- Public promises based on Siri or Apple Intelligence capabilities Apple still marks unavailable or future-facing.

### Optional I5 read-only gate

The optional read-only intent cannot begin without separate product/security approval. It must:

1. Accept only a saved-query UUID selected and approved inside glassdb; never accept free-form SQL from Siri, Shortcuts, or another app.
2. Permit exactly one statement classified `.readOnly`; reject `.mutation`, `.destructive`, `.sessionControl`, `.unknown`, and disguised-write cases.
3. Use the existing bounded read plan, a strict row/byte limit, timeout, cancellation, and no auto-repeat.
4. Require an explicit connection and foreground authentication by default; no credential material enters parameters or results.
5. Return only a bounded, privacy-reviewed summary or user-authorized file. Database rows never enter Siri dialog or Spotlight indexing by default.
6. Produce a local audit event recording intent identity, connection UUID, saved-query UUID, classification, bounds, outcome, and timing without SQL text or result data.

## Release Goals

| Goal | Objective | Completion signal |
|---|---|---|
| I0 | Freeze framework/API, reuse, warning, and threat-model truth | Current Apple APIs and glassdb owners documented; no dependency added merely for the warning |
| I1 | Define entity vocabulary and privacy policy | Stable IDs, queries, deletion behavior, indexing consent, and redaction tests pass |
| I2 | Ship foreground navigation App Intents and App Shortcuts | Core catalog routes correctly on all four platforms without executing SQL |
| I3 | Add appropriate widgets, controls, and automation surfaces | Each platform exposes only supported, useful, privacy-safe surfaces |
| I4 | Add optional Spotlight discovery | Consent, deletion, opt-out, stale-index cleanup, and sensitive-string review pass |
| I5 | Evaluate approved read-only saved-query automation | Optional follow-on; ships only with separate approval and all execution/security gates |
| I6 | Integrate and validate the independent release | Build/test/device/privacy/accessibility matrix passes; human approval recorded |

Allowed statuses are `not started`, `in progress`, `blocked`, and `done`.

## Milestone Dashboard

| ID | Status | Depends on | Primary result |
|---|---|---|---|
| I0 | not started | — | Baseline and threat model |
| I1 | not started | I0 | Private, stable entity layer |
| I2 | not started | I1 | Foreground intents and App Shortcuts |
| I3 | not started | I2 | Platform-appropriate system surfaces |
| I4 | not started | I1-I3 | Consent-based Spotlight discovery |
| I5 | not started | I1-I2 plus separate approval | Optional bounded read-only automation |
| I6 | not started | I0-I4; I5 only if included | Independent release acceptance |

Split a milestone into its own document only when implementation begins and its work/evidence no longer fits this tracker. This avoids speculative files while preserving the same milestone evidence pattern used by the other release plans.

## Validation Matrix

- [ ] Fresh install, upgrade, opt-in, opt-out, entity deletion, and stale-index cleanup.
- [ ] Duplicate connection/query/table names resolve visibly and deterministically without falling back to host or username disclosure.
- [ ] Missing connection, deleted entity, unavailable credential, locked Keychain, SSH trust change, local-network denial, offline state, and lost session all produce recoverable outcomes.
- [ ] iPhone compact routing, iPad multiwindow, Mac window activation, and Vision Pro spatial-window launch open the requested destination exactly once.
- [ ] App Shortcut phrases remain concise, localizable, and free of SQL, hosts, usernames, or schema samples.
- [ ] System-visible dialog, snippets, logs, analytics, Spotlight data, and donated entities pass a sensitive-data audit.
- [ ] VoiceOver, Voice Control, Full Keyboard Access, Dynamic Type, Reduce Motion, and system control labels pass on applicable physical devices.
- [ ] Minimum and current supported OS builds/tests pass on iPhone, iPad, Mac, and Vision Pro.
- [ ] Existing application, GlassDBKit, Citadel, and GlasSecretStore regressions remain green.
- [ ] The build contains a real App Intents dependency only because shipped intents require it; metadata extraction succeeds without an unexplained warning.

## Exit Criteria

- [ ] I0-I4 and I6 are done with objective evidence; I5 is required only if explicitly included in this release.
- [ ] Two to five high-value App Shortcuts work without user setup and never execute SQL merely by opening content.
- [ ] One shared entity/intent vocabulary serves all supported app platforms without duplicate managers or models.
- [ ] No secret, raw SQL, result row, sensitive server detail, or unapproved schema identifier is donated, indexed, spoken, logged, or returned.
- [ ] Every foreground/background and authentication decision has tests for locked, disconnected, denied, and stale state.
- [ ] Current release documentation remains truthful and unchanged by this plan's incomplete status.
- [ ] Human approval is recorded before this independent release is submitted or publicly claimed.

## Evidence Log

| Date | Milestone | Evidence | Result |
|---|---|---|---|
| 2026-08-08 | Planning baseline | Apple documentation review plus source-level routing, entity, session, saved-query, and SQL-safety reuse audit | Plan created; implementation not started; active release remains unblocked |
