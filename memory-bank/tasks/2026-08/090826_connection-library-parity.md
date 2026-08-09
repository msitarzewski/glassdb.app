# Connection Library Parity

**Date:** 2026-08-09
**Status:** Implementation and automated QA approved
**Branch:** `agent/connection-library-parity`

## Objective

Give glassdb the same calm, first-class connection-library experience established
in glas.sh while retaining database-specific connection details, actions, and
security policies across iPhone, iPad, Mac, and Vision Pro.

## Reuse Analysis

- Extended `glassdb/ConnectionManager.swift` instead of creating another catalog
  or persistence service. The library is a transient projection over the existing
  `ConnectionManager.connections` source of truth.
- Extended the existing `DatabaseConnectionConfig.tags` field for Collections;
  no parallel organization model or migration was introduced.
- Refactored the existing `ConnectionManagerView` platform shells and preserved
  their connection, trust, workspace, edit, delete, and credential actions.
- Extended the existing `ConnectionFormView` and `glassdbTests.swift`; no new
  application or test source file was required.
- `memory-bank/tasks/immediate-audit-remediation.md` could not be extended because
  it records a separate completed security and release-remediation effort.

## Outcome

- All Connections, Favorites, Recent, Collections, and scoped search are derived
  deterministically from one saved database-connection catalog.
- Mac and regular-width iPad use a three-column `NavigationSplitView`; iPhone uses
  a scope → results → detail `NavigationStack`; Vision Pro uses mode tabs with
  two-column direct scopes and a three-column Collections scope.
- Existing tags are editable as comma-separated Collections on every platform and
  normalize case, whitespace, width, and diacritics without duplicate membership.
- Connection detail now groups connection, security-policy, activity, and
  organization metadata without exposing password or private-key material.
- Existing Connect/Open Workspace, favorite, edit, delete, SSH host-trust, and
  transactional credential persistence paths remain the action boundaries.

## Files Modified

- `glassdb/ConnectionManager.swift` — transient library modes, scopes,
  deterministic projection, normalized collections, search, and selection rules.
- `glassdb/ConnectionManagerView.swift` — adaptive library navigation, result
  rows, grouped detail, empty states, and platform-specific actions.
- `glassdb/ConnectionFormView.swift` — add/edit Collections through existing tags.
- `glassdbTests/glassdbTests.swift` — projection, ordering, search, selection, and
  tag-normalization regression coverage.

## Patterns Applied

- `memory-bank/systemPatterns.md#Glass-Family-Connection-and-Tunnel-Contract`
- `memory-bank/releases/platforms-plus-plus/README.md#Cross-Platform-UX-Contract`
- Existing `ConnectionManager` persistence and `KeychainManager`/
  GlasSecretStore credential boundaries.

## Integration Points

- `ConnectionManagerView` constructs the projection directly from
  `ConnectionManager.connections`; scopes never persist a second connection list.
- `ConnectionFormView.buildConnection()` normalizes Collections into the existing
  `DatabaseConnectionConfig.tags` field.
- Detail and row actions continue through `DatabaseSessionManager`,
  `KeychainManager`, and the existing iPhone/window workspace routers.

## QA Evidence

- macOS 27 arm64: 105/105 tests passed.
- iPhone 17 Pro, iOS 27 simulator: 103/103 tests passed.
- iPad Pro 13-inch, iOS 27 simulator: 103/103 tests passed.
- Apple Vision Pro, visionOS 27 simulator: 103/103 tests passed.
- Total: 414 platform test executions; zero failures, skips, expected failures, or
  runtime warnings in the result summaries.
- `git diff --check` passed.
- Coverage observation with no repository threshold: app 19.26%;
  `ConnectionManager.swift` 70.28%; `ConnectionManagerView.swift` 66.63%;
  `ConnectionFormView.swift` 4.72%.

## Security Review

- No credential values are displayed by the new detail UI.
- No new secret store, endpoint catalog, access group, or credential identity was
  introduced.
- Existing GlasSecretStore UUID identity, atomic glassdb/glas.sh compatibility
  publication, rollback, host-trust, and SSH/database isolation tests remain green.

## Scope Boundary

This is the database connection-library presentation and organization slice. It
does not implement the synchronized neutral `EndpointProfile`/`EndpointID` and
GlasSecretStore `CredentialID` catalog. C3 and the canonical glas.sh/iPhone →
glassdb/Vision Pro tunnel acceptance path remain open, and no cross-device sync
claim is authorized by this work.

## Artifacts

- Branch: `agent/connection-library-parity`
- Pull request: draft publication from this branch after the approved commit.
