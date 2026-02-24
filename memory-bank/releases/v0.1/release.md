# v0.1 — MVP Release

**Target**: First App Store submission + GitHub open source push
**Engine**: MySQL only (via mysql-nio)
**Platform**: visionOS 2.0+, Swift 6.2

## Milestones

| Milestone | Name | Status | Description |
|-----------|------|--------|-------------|
| M0 | Clean Build | done | Zero errors/warnings, all targets compile |
| M0.5 | Hardening | done | Disconnect flow, SQL injection, race conditions, audit fixes |
| M0.7 | GlasSecretStore + SSH Key Auth | in-progress | Shared Keychain package, SSH key import/manage/connect |
| M1 | End-to-End Flow | not-started | Connect → Query → Results working live |
| M2 | Glass Polish | not-started | Glass materials, ornaments, spatial layout |
| M3 | Syntax & Usability | not-started | SQL highlighting, history, error UX |
| M4 | Ship-Ready | not-started | TestFlight → App Store submission |

## Must Have (v0.1 scope)
- [x] Connection manager (add/edit/delete MySQL connections)
- [x] SSH tunnel support (Citadel) — password auth
- [ ] SSH key auth (Ed25519 + RSA + Secure Enclave P256) via GlasSecretStore shared package
- [x] Keychain password storage
- [x] MySQL connection via mysql-nio
- [ ] Query editor with syntax highlighting
- [ ] Execute query + display results grid
- [ ] Schema browser (databases → tables → columns)
- [x] Multi-window spatial layout
- [ ] Glass material UI
- [ ] visionOS ornament chrome

## Should Have (v0.1 stretch)
- [ ] Query history (persisted)
- [ ] Export results (CSV, JSON)
- [ ] Table data browsing (SELECT * with pagination)
- [ ] Multiple query tabs per connection
- [ ] Autocomplete (keyword + schema-aware)
- [ ] Cross-app SSH key sharing with glas.sh (Keychain access group)

## Won't Have (deferred to v0.2+)
- PostgreSQL support
- ER diagram visualization
- Stored procedure editor
- Database backup/restore
- User/privilege management
- Data import wizard
- Inline cell editing

## Distribution
| Channel | Price |
|---------|-------|
| App Store | $10 one-time |
| GitHub | Free (compile yourself) |
