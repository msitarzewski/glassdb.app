# C8: Safe & Useful AI

**Status**: in progress
**Depends on**: C2, C4, C5
**Source IDs**: M02-M03, A01-A05

## Goal

Make on-device AI available when supported, private by design, useful across selected schema scope, and incapable of bypassing deterministic SQL safety controls.

## Implementation Plan

### Lifecycle and availability

- [ ] Call and observe the availability check defined at `glassdb/AIAssistant.swift:85`; distinguish unavailable hardware/OS, model not ready, policy restriction, and transient error.
- [ ] Own one assistant per workspace/session instead of constructing a fresh instance at `glassdb/TableDetailView.swift:294` on each presentation.
- [ ] Add cancellation, progress, retry, and lifecycle tests for model sessions.

### Context and privacy

- [ ] Keep the current selected-table metadata context bounded and disclosed; multi-table/schema selection remains a later UI expansion and must not be claimed here.
- [ ] Show exactly which schema metadata and optional samples will be sent to the on-device model; default to metadata-only and require consent for row values.
- [ ] Enforce context-size limits, sensitive-name redaction options, and no secret inclusion.
- [ ] Ship editor-first query generation. Error explanation and query summary may remain internal methods until product UI and tests exist; do not advertise unsurfaced outputs.

### Editor-first deterministic safety

- [ ] Replace direct “Run” behavior at `glassdb/AIAssistant.swift:334` with “Insert into Editor”; preserve user review and edits.
- [ ] Parse and classify generated SQL through C2/C4; ignore model-provided risk labels for authorization decisions.
- [ ] Require C4 confirmation or authentication according to actual side effects, environment, and credential policy.
- [ ] Add deterministic mitigations for indirect prompt injection in schema comments, names, row samples, errors, and imported text.
- [ ] Clearly label generated content and retain provenance through edit, execution preview, and audit record.

## Exit Criteria

- [ ] Availability initializes correctly and persists for the workspace lifecycle.
- [ ] Users control schema/value context with understandable privacy defaults.
- [ ] AI output cannot execute without entering the editor and passing deterministic policy.
- [ ] Prompt-injection fixtures cannot bypass side-effect confirmation or exfiltrate secrets.
- [ ] AI claims are backed by supported-device tests and graceful unavailable-state UX.

## Evidence Log

| Date | Model/Scenario | Expected | Actual | Test/Commit |
|---|---|---|---|---|
| 2026-07-17 | visionOS 26 launch | no strong FoundationModels symbol | 44/44 passed on 26.5; binary weak-links framework | final app suite/artifact |
| 2026-07-17 | Context/prompt injection | bounded metadata, no secret/instruction trust | deterministic tests passed | `aiSchemaContextIsMetadataOnlyBoundedAndInjectionDelimited` |
| 2026-07-17 | Generated response parsing | bounded strict JSON; editor-first safety | 64 KiB envelope/field caps; local SQL classification | code review + app suite |
