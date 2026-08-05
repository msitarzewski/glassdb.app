# P6: Network, Credentials, and Lifecycle Parity

**Status**: in progress — automated credential/trust/lifecycle parity complete; signed cross-app, physical-device, and live-network gates remain
**Goal**: G6
**Depends on**: P1-P5

## Objective

Prove that every platform shell preserves production connection behavior,
credential boundaries, host trust, suspend/resume, reconnection, failure
recovery, and the **My Connections** cross-app tunnel journey rather than merely
presenting working UI.

## Connectivity

- [ ] Verify MySQL, PostgreSQL, and managed-copy SQLite on simulator where meaningful and physical devices where required.
- [ ] Verify IPv4, IPv6, hostnames, `localhost` semantics, Unix-socket capability claims, and direct Tailscale IP/hostname use.
- [x] Add and test local-network permission messaging and denial recovery.
- [ ] Verify required/disabled/pinned TLS behavior and certificate failures.
- [ ] Verify SSH password/key/Secure Enclave-wrapped authentication, tunnel setup, host-key TOFU, changed-key rejection, and rotation.
- [ ] Select a neutral Glass-family SSH endpoint as the tunnel for a database
  without copying its host, username, authentication, or credential material into
  a second glassdb-owned connection record.
- [ ] Verify timeout, cancellation, server close, Wi-Fi change, path loss, tunnel loss, and reconnect behavior.

## Credentials

- [x] Preserve UUID credential identity and GlasSecretStore policies.
- [ ] Verify correctly signed glassdb/glas.sh access-group interoperability on each applicable platform.
- [ ] Verify eligible synchronized credentials separately from device-bound user-presence and Secure Enclave records.
- [ ] Make storage policy language distinguish family sharing, device synchronization, and per-device authentication.
- [ ] Present Ready/Still Syncing/Sign In/Set Up This Key/Review Fingerprint
  states and make delayed credential arrival resumable.
- [x] Verify delete/update effects and downgrade/rollback boundaries.

## Lifecycle

- [x] Treat iOS suspension as a real transport lifecycle event; do not imply sockets remain live indefinitely.
- [x] On foreground, validate session state before query execution.
- [x] Reconnect automatically only when policy and safety allow; otherwise present a native disconnected state and explicit Reconnect action.
- [x] Preserve drafts, results metadata, navigation, and scene state without presenting stale sessions as connected.
- [x] Bound reconnect attempts and surface terminal errors.
- [x] Ensure multiple iPad windows do not double-own or prematurely close a shared session.

## Failure Loop

For every transport:

`CONNECT → QUERY → BACKGROUND → NETWORK CHANGE → FOREGROUND → STATE CHECK → RECONNECT/FAIL → USER RECOVERY → AUDIT LOG`

Repeat with credential denial, host-key change, TLS failure, and server timeout.

## Exit Criteria

- [ ] Claimed engines and connection modes pass on physical iPhone/iPad where device behavior matters.
- [x] No request executes through a session already known to be disconnected.
- [ ] Credential sharing/sync/device-bound claims match signed runtime behavior.
- [ ] The canonical glas.sh/iPhone -> glassdb/Vision Pro tunnel journey and reverse
  direction pass from correctly signed builds without re-entry of eligible data.
- [ ] SSH/TLS trust failures are actionable and never silently weakened.
- [ ] Background/foreground and multiwindow lifecycle tests show bounded, deterministic ownership.

## Evidence Log

| Date | Device/Engine | Failure/Lifecycle Scenario | Result | Artifact |
|---|---|---|---|---|
| 2026-07-21 | macOS 27 / SQLite + pure transport plans | suspend, foreground validation, closed transport interception, explicit reconnect, retained logical session/history, IPv4/IPv6/localhost/direct Tailscale host preservation, SSH remote/TLS identity, local-network denial classification | PASS; full app suite 101 tests | `/private/tmp/glassdb-p6-tests-rerun.log` |
| 2026-07-21 | generic iOS Simulator | shared credential, lifecycle, and workspace sources compile for native iPhone/iPad target | PASS | `/private/tmp/glassdb-p6-ios-build` |
| 2026-07-21 | generic visionOS Simulator | lifecycle changes compile without weakening the Vision Pro workspace target | PASS | `/private/tmp/glassdb-p6-vision-build` |
| 2026-07-21 | generic macOS | affected app sources compile with code signing disabled | PASS | `/private/tmp/glassdb-p6-build` |
| 2026-07-21 | GlasSecretStore / macOS CLI | canonical Glass-family UUID account plus Keychain, SSH key, host-trust, migration, and Secure Enclave package regressions | PASS; 69 tests in 13 suites (independent root rerun outside sandbox) | `swift test` |
| 2026-07-21 | Post-remediation app regression | credential UUIDs, glassdb/glas.sh compatibility dual-write and rollback, access-group rejection, session suspension/reconnect, direct Tailscale host preservation, SSH remote/TLS identity | PASS; 101 tests on macOS, iPhone 17 Pro, and visionOS 27 against swift-nio 2.100.0 | `/private/tmp/glassdb-platforms-security-*-test.log` |

## Automated Evidence Scope

- `sharedSSHCredentialPublishesTheGlasCompatibilityRecordAtomically` proves that an explicitly shared glassdb SSH password publishes both its UUID record and glas.sh's endpoint compatibility record in `sh.glas.sshpasswords`; `sharedSSHCompatibilityWriteFailureRestoresEveryCredentialRecord` proves rollback after a partial cross-app write.
- `credentialPolicyDescriptorsUseIsolatedServicesAndExplicitPrompts` proves shared standard records use `sh.glas` services while glassdb-only and user-presence records remain in private services with no shared access group. All configurations use `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`; no iCloud-synchronizable claim is made.
- `suspensionRequiresForegroundValidationWithoutClosingSharedTransport` proves repeated scene suspension notices do not close a session that another iPad window may own. `foregroundAndQueryPathsRejectATransportLostDuringSuspension` proves a lost socket becomes disconnected before a request executes.
- `explicitReconnectRetainsTheLogicalSessionAndWorkspaceHistory` proves one explicit reconnect replaces only the transport behind the existing session object and preserves query history. Reconnect does not loop automatically; a failed attempt terminates in the observable error state.
- `directTransportPreservesIPv4IPv6LocalhostAndTailscaleHosts` and `sshTransportPreservesRemoteHostAndTLSIdentity` prove the app does not rewrite direct hosts and preserves the original database host as the SSH remote endpoint and TLS server identity.
- `NSLocalNetworkUsageDescription` is present in both app configurations, and `localNetworkPermissionFailuresHaveAnActionableClassification` proves policy-denial errors surface the Settings/reconnect recovery instruction.

## Remaining Device Gates

- Correctly signed glassdb/glas.sh Keychain reads, local-network denial/re-enable, Secure Enclave unwrap, suspend/network-change recovery, and multiwindow ownership still require physical iPhone/iPad evidence.
- Live MySQL/PostgreSQL, IPv6, direct Tailscale, TLS certificate failure/pinning, SSH password/key/host-key rotation, Wi-Fi/path/tunnel loss, cancellation, and server timeout remain runtime matrix items. Pure routing and fail-closed unit coverage do not replace those device/server tests.
- GlasSecretStore's complete 69-test, 13-suite package run passes outside the restricted sandbox, including the canonical account contract and Security-framework integration coverage. This package result does not replace the correctly signed glassdb/glas.sh cross-app read on each shipping device family.
- Source entitlement inspection confirms glassdb and glas.sh both declare `$(AppIdentifierPrefix)sh.glas.shared`; applicable targets also declare `group.sh.glas.shared`. Simulator ad-hoc signatures intentionally do not prove production-team access, so the signed-device read remains open rather than inferred.
- The Magic / First Class contract is approved direction, not evidence. Fresh
  install, upgrade, delayed secret, offline/account change, deletion/rotation,
  Secure Enclave enrollment, and canonical cross-app/device tunnel use remain
  open until recorded here.
