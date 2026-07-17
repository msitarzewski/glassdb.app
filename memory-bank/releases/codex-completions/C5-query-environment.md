# C5: Professional Query Environment

**Status**: in progress
**Depends on**: C2, C4
**Source IDs**: M05-M07, Q01-Q06

## Goal

Turn the query surface into a persistent, parser-aware, keyboard-first professional environment built on the safe query core.

## Implementation Plan

### Documents, tabs, and execution

- [ ] Introduce SQL document/tab state with independent text, selection, database, results, running task, dirty state, and close confirmation.
- [ ] Support new/close/reopen, autosave or explicit save, and native document APIs where C7 confirms platform fit.
- [ ] Execute the parser-selected statement or script from C2 and show every result/error in order.
- [ ] Wire auto-reconnect and close-confirmation settings to explicit, tested lifecycle policies or remove the settings.

### Language tooling

- [ ] Implement schema-aware completion for databases, tables, aliases, columns, keywords, and functions with refreshable schema cache.
- [ ] Add parser-backed formatting, diagnostics, statement navigation, and explain/explain-analyze entry points.
- [ ] Add editor line numbers and wire the setting currently exposed from `glassdb/SettingsView.swift:24`.
- [ ] Define keyboard commands and menus for execute selection, execute script, cancel, format, explain, completion, tab navigation, history, and saved queries.

### History and organization

- [ ] Replace session-only append at `glassdb/DatabaseSessionManager.swift:191` with durable, searchable history storing SQL, timestamp, duration, row/affected count, error, database, and stable connection ID.
- [ ] Provide per-connection/database/status/time filtering, retention limits, single/all deletion, and privacy-aware redaction.
- [ ] Add named saved queries with folders/tags, quick load, and migration from existing `SavedQuery` persistence.

### Results lifecycle

- [ ] Wire configurable server-side result bounds to C2 and show sentinel-proven truncation honestly.
- [ ] Support capability-gated cancel and detachable bounded results. Incremental rendering and multiple-result presentation remain explicitly unimplemented rather than simulated.

## Exit Criteria

- [ ] Tabs/documents preserve independent state and warn on unsaved or running work.
- [ ] Complex SQL selection and scripts use the C2 parser.
- [ ] Completion, formatting, diagnostics, explain, history, and saved-query flows are tested against live schema changes.
- [ ] History survives restart and respects retention/privacy controls.
- [ ] Every visible query setting has a runtime consumer and test.

## Evidence Log

| Date | Workflow | Expected | Actual | Test/Commit |
|---|---|---|---|---|
| 2026-07-17 | Parser/completion/format/history/documents | persistent and bounded editor workflows | focused tests passed on visionOS 26.5 and 27.0 | 41-test app suite |
| 2026-07-17 | SQL import/export cap | exact UTF-8 and 10 MiB pre/post-read limit | passed | document tests |
| 2026-07-17 | Result limit | original SQL/history plus sentinel-proven truncation | passed | bounded SQLite app test |
