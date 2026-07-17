# C4: Safe Mutations

**Status**: in progress
**Depends on**: C1, C2, C3
**Source IDs**: M03-M04, S07, T05, D05

## Goal

Ensure INSERT, UPDATE, DELETE, DDL, import, and AI-originated SQL cannot silently affect unexpected data.

## Implementation Plan

### Deterministic safety policy

- [ ] Parse and classify statements by actual operation and side effects; never trust an AI-generated risk string.
- [ ] Centralize execution policy so schema context menus, editors, imports, query tabs, and AI share the same rules.
- [ ] Require SQL preview and explicit confirmation for destructive operations; require user authentication where credential or environment policy demands it.
- [ ] Include target connection, environment color, database, object, estimated scope, transaction mode, and generated predicates in previews.

### Transactional mutation engine

- [ ] Replace manually escaped, quoted SQL around `glassdb/TableDetailView.swift:562` with C2 parameter bindings and typed values.
- [ ] Execute staged batches inside explicit transactions with rollback on any failed statement.
- [ ] Add optimistic concurrency predicates using primary key plus original/version values; detect zero or multiple affected rows.
- [ ] Verify server-reported affected rows before clearing staged state or reporting success.
- [ ] Preserve NULL, DEFAULT, generated columns, binary, decimal, JSON, and temporal semantics.
- [ ] Generate a durable local audit record containing connection ID, database/object, normalized operation, timestamp, outcome, and affected rows—never secret or full sensitive values by default.

### Error propagation and recovery

- [ ] Replace `try?` destructive execution at `glassdb/SchemaBrowserView.swift:83` with awaited results, progress, actionable errors, and refresh-on-success.
- [ ] Prevent window close/disconnect with uncommitted work unless the user commits, rolls back, or explicitly discards.
- [ ] Make cancellation outcomes unambiguous: committed, rolled back, server state unknown, or not started.

## Exit Criteria

- [ ] Every mutation path reaches the centralized deterministic policy.
- [ ] No staged mutation uses interpolated value SQL.
- [ ] Failed or ambiguous destructive operations remain visible and recoverable.
- [ ] Concurrency conflicts and affected-row mismatches do not clear edits.
- [ ] Batch edits can be previewed, committed atomically, or rolled back.

## Evidence Log

| Date | Mutation Scenario | Expected | Actual | Test/Commit |
|---|---|---|---|---|
| 2026-07-17 | Optimistic INSERT/UPDATE/paste | bound values, transactional rollback, affected-row verification | focused mutation/grid tests passed on both runtimes | 41-test app suite |
| 2026-07-17 | Destructive SQL classification | CTE/comments/literals cannot hide side effects | adversarial classifications passed | `sqlSafetyCannotHideWritesBehindCTEsCommentsOrLiterals` |
| 2026-07-17 | Schema truncate/drop errors | no `try?` suppression; explicit confirmation/error | implementation reviewed and app compiled/tested | `SchemaBrowserView.swift` |
