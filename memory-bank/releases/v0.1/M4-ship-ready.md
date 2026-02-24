# M4: Ship-Ready

**Status**: Not Started
**Depends on**: M3 (syntax & usability)

## Goal
The app is ready for TestFlight beta and App Store submission.

## Tasks

### GitHub & Source Control
- [ ] Create GitHub repo `msitarzewski/glassdb.app`
- [ ] Push initial commit with full source
- [ ] Add LICENSE (MIT or similar, matching glas.sh)
- [ ] Add README.md for GitHub (screenshots, build instructions)
- [ ] Set up .gitignore (Xcode, SPM build artifacts)

### Export
- [ ] Export results as CSV
- [ ] Export results as JSON
- [ ] Copy cell/row/column to clipboard

### Autocomplete (stretch)
- [ ] MySQL keyword autocomplete in query editor
- [ ] Schema-aware autocomplete (database, table, column names from live connection)
- [ ] `SchemaCompleter.swift` in SQLSyntaxEngine

### App Store Prep
- [ ] App icon (visionOS layered icon)
- [ ] About screen with version, credits, links
- [ ] Privacy policy (no data collection — local-only app)
- [ ] App Store screenshots (visionOS simulator or device captures)
- [ ] App Store description and metadata
- [ ] TestFlight build and internal testing
- [ ] App Store submission

### Final QA
- [ ] Test with real MySQL 5.7, 8.0, 8.4 servers
- [ ] Test SSH tunnel with password auth
- [ ] Test SSH tunnel with key auth
- [ ] Test large result sets (1K, 10K, 100K rows)
- [ ] Test connection drop and recovery
- [ ] Test multi-window workflow (editor + results + schema simultaneously)
- [ ] Memory profiling — no leaks on connect/disconnect cycles
