# Active Context

## Current Phase
Early development (alpha). Xcode project initialized, all core architecture implemented. 16 Swift source files in main target, 4 in GlassDBKit package, 11 in GlasSecretStore shared package. Compiling with Swift 6.2 strict concurrency. Build is clean on visionOS Simulator.

## Current Focus
Connection flow QA + hardening. First real Simulator testing revealed Keychain and UX issues. Next: wire end-to-end flow, then glass materials + ornaments.

## Recent Changes (2026-02-24)

### Round 4 — Connection flow QA + Simulator testing
Ran the app in visionOS Simulator for first real end-to-end connection test (SSH tunnel to 192.168.4.21). MySQL auth error revealed several issues:

- **Keychain password persistence fixed** — `ConnectionManagerView.swift` had silent `try?` on `KeychainManager.savePassword()` / `saveSSHPassword()` in both `.add` and `.edit` sheet closures; errors were swallowed, passwords never saved. Replaced with `do/catch` + `Logger.keychain` logging via new `saveCredentials(password:sshPassword:for:)` helper
- **Keychain retrieval logging added** — `initiateConnection()` now uses `do/catch` + `Logger.keychain.warning` instead of `try?` for password retrieval, so failures are visible in Console
- **Host:port verification logging** — `DatabaseSessionManager.swift` now logs exact `dbHost:dbPort` vs `config.host:config.port` before `engine.connect()`, confirming form values pass through correctly. The "localhost" in MySQL's `Access denied for user 'root'@'localhost'` error is server-side hostname mapping, not a client bug.
- **Credential prompt converted from `.alert()` to `.sheet()`** — The `SecureField` inside `.alert()` triggered system AutoFill's `UIKeyboardHiddenViewController_Save`, causing double-presentation collisions. New sheet has `NavigationStack` + `Form` with Cancel/Connect toolbar, connection subtitle footer, `.presentationDetents([.medium])`
- **Password visibility toggle on all password fields** — `SecureField` blocks paste (system security restriction). Added eye/eye.slash toggle buttons to swap between `SecureField` and `TextField` on: ConnectionFormView DB password, ConnectionFormView SSH password, credential prompt sheet DB password, credential prompt sheet SSH password. Defaults to hidden, resets on dismiss.
- **Simulator log noise analysis** — Catalogued all visionOS Simulator console output. RTIInputSystemClient, AudioToolbox, TCP_INFO, haptic, edit menu, and coordinate conversion messages are all Simulator-only framework noise. No actionable items remain.
- **Build: SUCCEEDED** — zero errors on visionOS Simulator

### Prior rounds (2026-02-23)
- Round 1: Disconnect flow fixes (ELG leaks, zombie sessions, channel close)
- Round 2: Audit sweep (SQL injection, race condition, schema errors, history cap, force unwrap)
- Round 3: GlasSecretStore shared package (11 files, integrated into glassdb, SSH key auth)

## Next Steps
1. Wire end-to-end flow: connect → query → results → schema browser
2. **Integrate GlasSecretStore into glas.sh** (Phase 3 — separate PR, lighter touch)
3. Apply glass materials + ornament chrome
4. Build SQL syntax highlighting engine
5. Create GitHub repo and push initial commit
