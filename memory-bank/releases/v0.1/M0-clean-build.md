# M0: Clean Build

**Status**: Complete (2026-02-23)
**Prerequisite for**: M1

## Goal
Zero errors and zero warnings across all targets under Swift 6.2 strict concurrency.

## Tasks
- [x] Fix `SSHTunnel` Sendable conformance (`@unchecked Sendable`) — `SSHTunnelManager.swift:117`
- [x] Fix `SSHAuthenticationMethod.privateKey` — doesn't exist; use `.ed25519(username:privateKey:)` with Citadel's `Curve25519.Signing.PrivateKey(sshEd25519:)` — `SSHTunnelManager.swift:62-70`
- [x] Fix `Task` capturing non-Sendable `ChannelHandlerContext` — extract `localChannel` and `sshClient` before `Task` boundary — `SSHTunnelManager.swift:153-179`
- [x] Add `@preconcurrency import Citadel` to suppress upstream Sendable warnings — `SSHTunnelManager.swift:12`
- [x] Add missing `tunnel` and `tunnelManager` properties to `DatabaseSession` — `DatabaseSessionManager.swift:150-151`
- [x] Verify GlassDBKit package compiles clean (`swift build` — zero errors, zero warnings)
- [x] Verify main `glassdb` target compiles and runs in visionOS Simulator
- [x] App launches, renders connection UI, attempts real SSH connection to remote host

## Key Files
- `Packages/GlassDBKit/Sources/GlassDBKit/SSHTunnelManager.swift`
- `Packages/GlassDBKit/Sources/GlassDBKit/MySQLAdapter.swift`
- `glassdb/DatabaseSessionManager.swift`

## Decisions
- `@unchecked Sendable` for NIO/Citadel wrapper types (see `decisions.md`)
- `@preconcurrency import Citadel` — upstream `SSHClient` is safe but doesn't conform to `Sendable`
- Ed25519 key auth only for v0.1 SSH keys (RSA/P256/P384/P521 can be added later via Citadel's other static methods)
