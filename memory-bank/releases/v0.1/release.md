# v0.1 — MVP Release

**Target**: First App Store submission + GitHub open source push
**Engine**: MySQL only (via mysql-nio)
**Platform**: visionOS 26.0+, Swift 6.2

## Milestones

| Milestone | Name | Status | Description |
|-----------|------|--------|-------------|
| M0 | Clean Build | done | Zero errors/warnings, all targets compile |
| M0.5 | Hardening | done | Disconnect flow, SQL injection, race conditions, audit fixes |
| M0.7 | GlasSecretStore + SSH Key Auth | done | Shared Keychain package, SSH key import/manage/connect |
| M1 | End-to-End Flow | done | Connect → Query → Results working live |
| M2 | Glass Polish | done | Liquid Glass migration, visionOS 26 compliance (PR #1) |
| M3 | Syntax & Usability | done | SQL highlighting, keyboard shortcuts, workspace architecture |
| M4 | Ship-Ready | in-progress | Polish, TestFlight, App Store submission |

## Must Have (v0.1 scope)
- [x] Connection manager (add/edit/delete MySQL connections)
- [x] SSH tunnel support (Citadel) — password auth
- [x] SSH key auth (Ed25519 + RSA + Secure Enclave P256) via GlasSecretStore
- [x] Keychain password storage
- [x] MySQL connection via mysql-nio
- [x] Query editor with syntax highlighting
- [x] Execute query + display results grid
- [x] Schema browser (databases → tables → columns)
- [x] Multi-window spatial layout (workspace + detachable results)
- [x] Glass material UI (Liquid Glass ornaments, .windowStyle(.plain))
- [x] visionOS ornament chrome (.toolbar(.bottomOrnament))
- [x] Table data browsing (SELECT * with content-width columns)
- [x] Table structure viewer (columns, types, keys)
- [x] DDL viewer (SHOW CREATE TABLE, syntax highlighted)
- [x] Index and foreign key viewers
- [x] Row editing (staging model, batch UPDATE)
- [x] CSV export

## Should Have (v0.1 stretch)
- [ ] SQL autocomplete (keyword + schema-aware)
- [ ] Query history (persisted across app restarts)
- [ ] Multiple query tabs per connection
- [x] Export results (CSV) *(JSON/SQL deferred to v1.1)*
- [x] Cross-app SSH key sharing with glas.sh (Keychain access group)
- [x] Context menus on schema tree items

## Won't Have (deferred to v1.1+)
- PostgreSQL support
- ER diagram visualization
- Stored procedure editor
- Database backup/restore
- User/privilege management
- Data import wizard
- Inline cell editing in data grid
- iPad / Mac / iOS targets
- iCloud Keychain integration

## Distribution
| Channel | Price |
|---------|-------|
| App Store | $10 one-time |
| GitHub | Free (compile yourself) |
