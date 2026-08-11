# Connection Overview Statistics Performance

**Status:** To do — diagnosed 2026-08-11, not started; approved for filing only
**Discovered on:** `agent/command-w-editor-close` (behavior exists in committed code from `c558eff`)
**Scope:** Replace the per-database statistics walk in the connection Overview cold path with one aggregate metadata query per engine.

## Problem

On a MySQL server with 391 databases (local multi-tenant instance: `beam_*`, `cv_*`, `common_vision_*` schemas), the connection Overview "Inspecting databases…" pass takes tens of seconds on every fresh connection.

## Diagnosis (2026-08-11)

- `ConnectionOverviewView.loadOverview` at `glassdb/DatabaseDetailView.swift:434` iterates all databases **sequentially**, awaiting one `sessionManager.tableStatistics(...)` call per database.
- Each call runs one full server round trip: `DatabaseSessionManager.tableStatistics` (`glassdb/DatabaseSessionManager.swift:606`) → `connection.tableStatus(in:)` → `SHOW TABLE STATUS FROM \`db\`` at `Packages/GlassDBKit/Sources/GlassDBKit/MySQLAdapter.swift:745`.
- `SHOW TABLE STATUS` materializes per-table InnoDB statistics, so each round trip is itself non-trivial. 391 serial queries × ~100ms ≈ 40+ seconds cold.
- The existing optimization — the `DatabaseStatisticsSnapshot` cache with freshness windows and in-flight deduplication (`glassdb/DatabaseSessionManager.swift:593-601`) — makes **revisits** instant but is in-memory per session, so every new connection starts cold.
- Secondary cost: the loop re-sorts and reassigns the `@State` summaries array on every iteration (`glassdb/DatabaseDetailView.swift:483-486`), forcing up to 391 SwiftUI dashboard re-renders per load.

## Proposed Fix (not yet planned or approved for build)

1. Add an aggregate all-schemas statistics path to GlassDBKit: one query against `information_schema.TABLES` (per-table rows preserved, or `GROUP BY table_schema` for summaries) returns table counts, row estimates, and data/index sizes for every schema in a single round trip.
2. Populate the existing per-database `DatabaseStatisticsSnapshot` cache from that single result set so `TableDetailView`/database detail consumers keep working unchanged.
3. Give the PostgreSQL adapter the same treatment; it already reads `information_schema.tables` per schema at `Packages/GlassDBKit/Sources/GlassDBKit/PostgreSQLAdapter.swift:230`.
4. Batch the summaries `@State` update (assign once per chunk or once at completion) instead of per-iteration sort/assign.
5. Capability-gate the aggregate path; retain the per-database walk as the fallback for engines without a cross-schema statistics surface (managed-copy SQLite is unaffected).

## Reuse Analysis

Extends the existing `tableStatistics` cache and `tableStatus` adapter surface; no new views, managers, or storage. Touches GlassDBKit protocol (`DatabaseConnection`), MySQL/PostgreSQL adapters, `DatabaseSessionManager`, and `ConnectionOverviewView` loading only.

## Acceptance Sketch

- Cold Overview against the 391-database local server completes its statistics pass in single-digit seconds (one round trip plus rendering), with identical card/chart values to the current implementation.
- Revisit cache behavior, invalidation on confirmed mutations, and per-database `TableDetailView` statistics remain regression-clean.
- Existing Mac/iPhone/iPad/Vision Pro suites stay green; add focused coverage for aggregate-to-snapshot fan-out.
