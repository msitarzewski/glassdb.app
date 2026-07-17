# C1: Transport Security & Host Trust

**Status**: in progress
**Depends on**: C0
**Source IDs**: S01-S04, T01-T02

## Goal

Make database and SSH transport claims cryptographically true, user-verifiable, and resistant to machine-in-the-middle attacks.

## Implementation Plan

### MySQL TLS

- [ ] Extend the connection capability at `Packages/GlassDBKit/Sources/GlassDBKit/DatabaseProtocol.swift:20` with explicit TLS policy rather than a boolean that adapters can ignore.
- [ ] Replace `tlsConfiguration: nil` at `Packages/GlassDBKit/Sources/GlassDBKit/MySQLAdapter.swift:35` with verified TLS configuration when enabled.
- [ ] Support system trust evaluation, hostname verification, required/disabled modes, and optional certificate/public-key pinning.
- [ ] Surface certificate identity and validation failures in the connection test and live connection UI.
- [ ] Refuse connection when TLS is required but cannot be negotiated; never silently downgrade.

### SSH host identity

- [ ] Replace `.acceptAnything()` at `Packages/GlassDBKit/Sources/GlassDBKit/SSHTunnelManager.swift:102` with a Citadel host-key validator backed by GlasSecretStore's existing `SSHHostTrustKeychainStore`.
- [ ] Implement trust on first use with an explicit SHA-256 fingerprint confirmation showing host, port, algorithm, and fingerprint.
- [ ] Accept previously trusted matching keys without prompting and reject changed keys with a blocking warning and an explicit trust-management flow.
- [ ] Remove the automatic `.all` algorithm fallback at `Packages/GlassDBKit/Sources/GlassDBKit/SSHTunnelManager.swift:107`; define a reviewed compatibility policy that cannot weaken host verification.
- [ ] Provide UI to inspect, replace, and remove trusted host fingerprints.

### Verification

- [ ] Test valid CA, self-signed, expired, hostname-mismatched, pinned, rotated, and downgrade TLS cases.
- [ ] Test SSH first connection, repeat connection, changed key, removed trust, unsupported algorithm, and tunnel fallback cases.
- [ ] Confirm logs contain actionable trust diagnostics without credentials or private key material.

## Exit Criteria

- [ ] Packet-level verification shows TLS is active whenever the UI says it is active.
- [ ] No production SSH path uses accept-anything host verification or unrestricted algorithm fallback.
- [ ] Changed SSH keys and invalid TLS identities fail closed.
- [ ] Trust records survive restart and are exercised by automated integration tests.

## Evidence Log

| Date | Scenario | Expected | Actual | Test/Commit |
|---|---|---|---|---|
| 2026-07-17 | TLS fail-closed/adversarial suite | invalid roots, missing TLS, and self-signed system trust fail | passed in 21/21 GlassDBKit suite and live containers | `GlassDBKitTests` |
| 2026-07-17 | SSH unknown/rotated key | explicit challenge/rejection; never accept-anything | passed; insecure-transport scan clean | `GlassDBKitTests` + gitleaks/rg scans |
| 2026-07-17 | Live network engines | verified transport and cancellation outcomes | MySQL 8.4.10 and PostgreSQL 17.10 passed | disposable arm64 containers |
