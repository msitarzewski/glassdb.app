# C2: Query Core & Value Fidelity

**Status**: in progress
**Depends on**: C0
**Source IDs**: M04, M07, S05-S06, T03-T04, Q02, Q05

## Goal

Provide a typed, precise, bounded, cancellable query core that can safely support all later editors and engines.

## Implementation Plan

### Typed protocol and MySQL decoding

- [ ] Extend `DatabaseValue` and result metadata to represent signed/unsigned integers, decimals, floating point, booleans/bit fields, strings with encoding, binary/blob, JSON, date/time/timestamp/year, and NULL without lossy coercion.
- [ ] Replace string-or-null decoding at `Packages/GlassDBKit/Sources/GlassDBKit/MySQLAdapter.swift:89` with type-aware mysql-nio decoding that preserves raw fidelity and server metadata.
- [ ] Populate `affectedRows`, warnings, last insert ID where available, and sub-second monotonic execution duration instead of the incomplete result at `Packages/GlassDBKit/Sources/GlassDBKit/MySQLAdapter.swift:73`.
- [ ] Add parameter-binding APIs for values and identifiers that are consumed by mutation and import workflows.
- [ ] Define deterministic display, edit, export, and comparison semantics for every supported value type.

### Statement and session execution

- [ ] Replace naive `sql.split(separator: ";")` at `glassdb/TableDetailView.swift:514` with a MySQL-aware parser/lexer supporting strings, quoted identifiers, comments, delimiters, triggers, and stored procedures.
- [ ] Add parser-backed current-statement selection and ordered multi-result reporting; never silently discard intermediate failures or result sets.
- [ ] Evolve `DatabaseConnection` into capability-based interfaces for transactions, cancellation, timeout, metadata, explain, server version, and engine-specific behavior; do not advertise streaming until drivers implement it.
- [ ] Add timeouts and cancellation. SQLite interrupts locally; MySQL/PostgreSQL abort by closing transport and must leave the app session explicitly disconnected. Automatic reconnect is excluded until idempotency policy exists.
- [ ] Keep results server-bounded or paged with configurable limits; record incremental streaming/backpressure as a residual capability gap.

### Verification

- [ ] Add round-trip fixtures for every MySQL value family, boundary values, invalid encodings, timezone transitions, large blobs, and high-precision decimals.
- [ ] Add parser fixtures containing semicolons in literals/comments and procedure/trigger bodies.
- [ ] Test cancellation, timeout, disconnect during query, reconnect policy, large streams, and multiple result sets.

## Exit Criteria

- [ ] Supported values round-trip without type or precision loss.
- [ ] Affected rows and duration match server/client evidence.
- [ ] Complex scripts execute according to parser boundaries, not character splitting.
- [ ] Large queries remain server-bounded/paged, and stalled-query cancellation has an unambiguous local-interrupt or disconnected outcome.

## Evidence Log

| Date | Fixture/Scenario | Expected | Actual | Test/Commit |
|---|---|---|---|---|
| 2026-07-17 | Typed/bound/adversarial package suite | preserve values and reject smuggling/mismatched binds | 21/21 passed | `GlassDBKitTests` |
| 2026-07-17 | Parser and bounded editor reads | preserve complex SQL; LIMIT n+1 only for safe SELECT/CTE | 44/44 passed on visionOS 26.5 and 27.0 | final app suites |
| 2026-07-17 | Timeout/cancellation | terminate query with explicit connection outcome | MySQL/PostgreSQL abort and disconnect; SQLite interrupts locally | live integration tests |
