# Active Context

## Current Phase
`platforms-plus-plus` external release acceptance. The shared native arm64 target now builds focused iPhone, desktop-class iPad, Apple silicon Mac, and Vision Pro applications. iOS/iPadOS and visionOS require 26.0+, macOS requires 27.0+, and Intel plus Mac Catalyst remain excluded. GlassDBKit provides MySQL, PostgreSQL, and managed-copy SQLite adapters, while GlasSecretStore remains the canonical Glass-family credential package.

## Current Focus
The four-platform implementation and automated simulator/package QA are complete. The final destination matrix passed 101 application tests on macOS 27, iPhone iOS 27, iPad iOS 27, Vision Pro visionOS 26.5, and Vision Pro visionOS 27; the 2026-08-06 immediate-remediation regression expanded the macOS suite to 103/103 and added a passing generic iOS build. The 2026-08-09 connection-library slice now provides one adaptive All/Favorites/Recent/Collections experience over existing saved database connections; its final matrix passed 105/105 on Mac and 103/103 each on iPhone, iPad, and Vision Pro. A 2026-08-10 post-release refinement aligned direct row interaction, information hierarchy, detail density, and action placement with glas.sh; its combined preview received human visual approval and passed 115/115 Mac tests plus Mac, iPhone, iPad, and Vision Pro builds. The app now includes its privacy manifest, keeps database and SSH passwords in separate authentication domains, returns iPhone recovery navigation through the single-window router, and has checked-in CI plus reproducible security scanning. A dependency penetration scan found and repaired three swift-nio 2.96.0 advisories by locking Apple swift-nio 2.100.0; the post-fix OSV scan, Xcode Analyze, GlassDBKit, Citadel, Mac, iPhone, and Vision suites pass. Remaining release work is external: correctly signed physical-device acceptance, live MySQL/PostgreSQL/TLS/SSH/Tailscale/path-loss testing, assistive-technology and Instruments review, an iOS 26 runtime fallback pass, and explicit human release approval. GlasSecretStore defines canonical UUID accounts; glassdb atomically publishes the glas.sh SSH compatibility record for explicitly shared credentials and rolls both records back on partial failure. User-presence and Secure Enclave secrets remain intentionally device-bound. The approved next cross-repository program is the *Magic / First Class* **My Connections** contract: neutral endpoint identity, glassdb database/tunnel overlays, GlasSecretStore credential availability, outcome-oriented onboarding, and cross-device acceptance. The new library is its presentation precursor, not synchronized endpoint implementation, and no public sync claim is authorized. No TestFlight submission is automatic.

## Recent Changes

### Command-W Editor Close and Workspace Tab Seeding (2026-08-11)
- Routed Command-W through one window-level registration (`MacDatabaseCommandWRouter`) that closes the selected top-level SQL or table tab with the existing save prompt; the connection Overview is the non-document fallback after the last closable tab closes
- New workspace windows seed only the Overview tab; the previous implicitly minted "Untitled SQL" document is gone, and windows opened to a table, database, or restored SQL document still get that tab beside Overview
- SQL documents are created on demand through a workspace-level New Query Tab action (⌘T in the Query menu) that works with zero editors open; ⌘N remains captured by the system "New Connections Window" File item pending the filed File-menu task
- Added Overview namespace-inspection progress reporting and sidebar single-click preview versus double-click activation refinements
- QA: Mac 118/118, iPhone 114/114, iPad 114/114, and Vision Pro visionOS 27 114/114 with zero failures or skips; the five Mac "Invalid view geometry" runtime warnings were proven pre-existing against a clean HEAD worktree baseline; human visual approval covered connect, table browsing, ⌘T creation, and the ⌘W save/don't-save prompt
- Filed Memory Bank tasks: connection Overview statistics performance (391 sequential `SHOW TABLE STATUS` round trips on the local server), Mac File-menu ownership of the SQL document lifecycle (system ⌘N capture plus the per-editor focused-value publication that kills ⌘O/⌘S once two editors are alive — pre-existing on main), and Mac SQL editor gutter alignment

### Connection Library Parity (2026-08-09)
- Reused `ConnectionManager.connections` as the only saved database catalog and added a transient deterministic projection for All Connections, Favorites, Recent, Collections, and search
- Replaced the duplicated connection presentations with an adaptive iPhone navigation stack, regular-width Mac/iPad split view, and Vision Pro mode tabs/spatial split views
- Made existing connection tags editable as normalized Collections without adding storage or migration authority
- Preserved GlasSecretStore credential policy, SSH host trust, connect/workspace routing, and rollback paths; details show policy metadata but never secret material
- Passed 105/105 Mac tests and 103/103 each on iPhone, iPad, and Vision Pro; C3 synchronized endpoints and signed-device acceptance remain open

### Immediate Audit Remediation (2026-08-06)
- Added and bundle-validated `PrivacyInfo.xcprivacy` with the required app-private and App Group UserDefaults reasons
- Removed the database-password-to-SSH fallback, made SSH credentials explicit at the session boundary, and added a passing isolation regression
- Reused `IOSAppRouter` for iPhone “Show Connections” recovery while preserving regular-width window routing; focused policy coverage and a generic iOS build pass
- Added `xcode-27` GitHub Actions coverage for app/package tests plus OSV/Gitleaks scans, with narrow classified-fixture exceptions
- Reconciled current platform/dependency documentation and completed 103/103 app plus 25/25 GlassDBKit automated regressions; remaining gates are external

### Platforms Plus Plus (2026-07-21) — Native iPhone/iPad and Four-Platform Validation
- Extended the existing shared SwiftUI target to native iPhone and iPad (iOS/iPadOS 26.0+, families 1/2) without Catalyst or a second engine/state implementation; all app and test products remain arm64-only
- Added a compact iPhone router and native connection/list/table-summary flows while retaining `NavigationSplitView`, multiwindow workspaces, and the professional regular-width data plane for iPad, Mac, and Vision Pro
- Removed implicit connection submission from host/user field editing; explicit Test and Save & Connect actions now own connection attempts
- Preserved the product-defining Vision/Mac live database content opacity and blur controls while keeping ordinary app chrome on Apple system materials
- Centralized Glass-family UUID credential account names in GlasSecretStore and made shared SSH password publishing compatible with glas.sh through an atomic dual-write/rollback contract; private and user-presence policies remain isolated
- Added local-network permission metadata and actionable classification, foreground transport validation, explicit reconnect recovery, bounded ownership across multiple windows, and direct IPv4/IPv6/localhost/Tailscale host preservation
- Completed five 101-test destination runs (Mac, iPhone, iPad, visionOS 26.5, visionOS 27), generic unsigned iOS/visionOS device builds, 69 GlasSecretStore tests, 25 GlassDBKit tests, and 31 Citadel tests
- Repaired swift-nio security advisories by moving the shipping lock from 2.96.0 to 2.100.0; OSV now reports no issues and post-remediation Mac/iPhone/Vision regressions plus Xcode Analyze pass
- Authored application/GlassDBKit scan found no in-scope TODO/FIXME/stub/fatalError/preconditionFailure/empty-catch implementation; remaining markers are vendored upstream state-machine invariants, protocol terms, examples, or tests

### Codex Completions (2026-07-19) — Shared Workspace and Data-Management UX
- Completed the shared Mac/visionOS database workspace: native material chrome remains separate from the user-controlled live database canvas, multiple SQL/database/table tabs remain connected until individually closed, and table/database clicks now open data and operational database dashboards respectively
- Replaced read-only table metadata surfaces with capability-gated Structure, DDL, Index, and Foreign Key workflows that preview generated SQL, require confirmation for mutations, propagate server errors, and refresh verified metadata after success
- Modernized query failures into accessible Apple-style error cards with first-error notification consent, bounded native notification delivery, copyable diagnostics, and runtime-gated on-device Foundation Models fix suggestions that only draft SQL into the editor
- Added semantic JSON/JSONB record editing: optional automatic pretty formatting for humans, validation while editing, and lossless compact machine serialization on save without changing string whitespace, escapes, key order, or numeric lexemes
- Replaced the unbounded Columns command menu with a searchable staged manager for visibility, freezing, bulk actions, reset, and Cancel/Done; layouts remain persisted per connection/database/table
- Added native Mac row-number selection semantics: plain click selects one row, Shift extends a visible range, Command toggles discontiguous rows, Command-Shift adds a range, and double-click edits; Copy, Compare, and Export consume the same selected-row set
- Added dual-mode row filtering: bound server-side query updates remain the default, while Display Only filters the currently loaded page without changing SQL or contacting the database
- Restored the dedicated Mac application icon by removing the duplicate resource-name collision between the flattened asset catalog and retained layered source; the Vision Pro solid image stack remains unchanged
- Current evidence: 84/84 native macOS 27 arm64 app tests passed with zero failures, skips, expected failures, or runtime warnings; fresh arm64 macOS and visionOS simulator builds passed; the development-signed Mac bundle passed strict signature verification

### Codex Completions (2026-07-18) — Native macOS Completion and Final Automated QA
- Added the native SwiftUI macOS application path with platform-native scenes, commands, window behavior, settings, editor/grid controls, Keychain integration, Mac app metadata/entitlements, and a dedicated Mac icon while preserving the Vision Pro database-workspace opacity/blur experience
- Set the Mac application and test deployment target to macOS 27.0 and restricted shipping application architectures to arm64; Intel and Catalyst remain unsupported
- Produced a native macOS Release archive whose application executable is arm64, declares macOS 27.0 minimum, and identifies `macosx`/`MacOSX` as its platform
- Completed a Mac-wide SwiftUI UX audit: Settings now uses native tabbed/grouped forms, bounded steppers and sliders, validation gates, keyboard default/cancel actions, adaptive editor/grid controls, and a connection sidebar that defaults to 340 points with a 300-point minimum
- Final frozen-tree application tests passed 60/60 on native macOS 27 arm64 and 59/59 on the visionOS 26.4 arm64 simulator, with zero result-bundle build, analyzer, or runtime warnings, skips, or expected failures; the earlier minimum-runtime checkpoint remains 44/44 on visionOS 26.5
- Fixed the native macOS Settings-scene constraint feedback loop with a finite 620×540 content boundary; ten fresh Debug launches and the exact Release archive opened Settings without a crash report or AppKit constraint-loop diagnostic
- Preserved the product-defining Vision Pro workspace controls: opacity still spans fully transparent through opaque and blur remains continuously adjustable, while general application windows retain system materials
- Final shared-package evidence: GlassDBKit 24/24 plus 2/2 live MySQL/PostgreSQL integration tests, Citadel 31 executed with 5 environment-gated skips and 0 failures, swift-nio-ssh 320/320, and GlasSecretStore 68/68
- Corrected mysql-nio's empty-password `caching_sha2_password` response, pinned the reviewed fork SHA in both SwiftPM resolution surfaces, reproduced the official 1.9.1 failure, passed the gated live GlassDBKit regression against MySQL 9.7.1, and received user confirmation that the fresh development-signed Mac app connects with the same localhost configuration; refreshed GlassDBKit coverage is 24/24
- Citadel payload, SFTP EOF, and invalid-state paths now fail through typed errors/pipeline closure instead of process traps; the SSH tunnel pending-buffer path is strictly bounded
- Automated completion does not satisfy external distribution provisioning, physical-device-only security/AI checks, or C3 eligible-secret cross-device Keychain synchronization; those gates remain open

### Codex Completions (2026-07-17) — Production-Core Implementation Under Release Validation
- Real fail-closed MySQL TLS and SSH host-key TOFU/change rejection
- Typed values, parameter binding, transaction support, adapter-reported affected-row/timing metadata for covered paths, and parser-backed execution policy
- Stable UUID credentials; endpoint-to-UUID copy migration with legacy records retained for rollback; same-device glassdb/glas.sh sharing through the shared Keychain access group and App Group SSH metadata; app-only and user-presence policies remain private to glassdb
- Transactional optimistic INSERT/UPDATE/paste paths, audit records, safe schema actions, bound filters/sorts, grid layouts, range workflows, and import/export limits
- Persistent history/saved queries, tabs, SQL documents, line numbers, completion, formatting, diagnostics, explain, and bounded editor results
- MySQL, PostgreSQL, and managed-copy SQLite engine selection with explicit capability gating
- Editor-first on-device AI with deterministic SQL classification and privacy-bounded current-table context; generation UI is runtime-gated to visionOS 27+
- Protected Vision Pro database workspace retains a 0–100% opacity slider plus continuous blur; general windows use system materials
- Native visionOS optical-glass application icon; a matching terminal icon was separately installed and asset-compiled in the sibling glas.sh repository
- SSH host rotation now consumes only the newest authorized generation and uses verified replacement while retaining revoked history
- Connection-test failures use a compact Apple-style status row with a native details alert; invalid OpenSSH formats produce actionable errors
- Evidence at this checkpoint: 44/44 app tests on both visionOS 26.5 and 27.0, plus 21/21 GlassDBKit tests; see the 2026-07-18 entry for the expanded final suites

The rounds below are a historical development log; current capability truth is recorded above and in `memory-bank/releases/codex-completions/`.

### Round 5 (2026-03-15) — visionOS 26 SDK Migration (PR #1, merged)
- **Liquid Glass**: replaced manual `.ornament()` + `.glassBackgroundEffect()` with `.toolbar { ToolbarItemGroup(placement: .bottomOrnament) }` for system Liquid Glass treatment
- **Window lifecycle**: added `.defaultLaunchBehavior`/`.restorationBehavior` to all scenes, converted Settings to singleton `Window`, deleted `WindowRecoveryManager.swift`
- **Stale session guards**: added `ContentUnavailableView` fallback in QueryEditorView and SchemaBrowserView
- **Accessibility**: grid header traits, data cell labels with column names, connection status indicator labels, form enhancement labels, Look to Scroll on all scrollables
- **Removed double-corner artifact**: removed `.background(.ultraThinMaterial, cornerRadius: 24)` from all content windows — `.windowStyle(.plain)` handles window chrome
- **Removed deprecated settings**: `interactiveGlassEffects` removed from SettingsManager, Constants, SettingsView
- **Alternating row colors**: fixed to use `Color.primary.opacity` for adaptive theming
- **Deployment target**: raised to visionOS 26.0

### Round 6-8 (2026-03-15/16) — v1.0 Database Manager (commit f408fd9)

**Architecture overhaul:**
- Replaced separate query editor + schema browser + results windows with unified `DatabaseWorkspaceView`
- `WorkspaceSelection` enum (`.database`, `.table`, `.query`) drives context-sensitive detail surface
- Schema browser integrated as NavigationSplitView sidebar with filter field and context menus
- DBeaver-style interaction model: click database → properties view, click table → data/structure/DDL tabs

**New views (7 files created):**
- `DatabaseWorkspaceView.swift` — NavigationSplitView wrapper, selection routing, sidebar toggle
- `TableDetailView.swift` — 5-tab TabView (Data, Structure, DDL, Indexes, Foreign Keys) with sub-views
- `DatabaseDetailView.swift` — database properties, table stats, active database selector
- `RecordEditorView.swift` — sheet modal for row editing with staging model
- `SQLHighlighter.swift` — full SQL tokenizer + NSAttributedString syntax highlighting
- `HighlightedTextEditor.swift` — UIViewRepresentable wrapping UITextView for highlighted editing
- `DataExporter.swift` — CSV, TSV, JSON, and SQL INSERT export workflows

**Query engine fixes:**
- Utility commands (USE, SET, SHOW, DDL) routed through `simpleQuery` (COM_QUERY) instead of prepared statements (COM_STMT_PREPARE) — fixes MySQL protocol error
- Session tracks `currentDatabase` after USE statements
- Column metadata loaded separately for PK detection in record editor

**Protocol extensions (GlassDBKit):**
- 5 new `DatabaseConnection` methods: `showCreateTable`, `indexes`, `foreignKeys`, `tableStatus`, `rowCount`
- 3 new models: `IndexInfo`, `ForeignKeyInfo`, `TableStatus`
- `DatabaseError` enum for protocol-level errors

**Data grid improvements:**
- `LazyVStack(pinnedViews: .sectionHeaders)` for sticky column headers
- `GeometryReader`-based column width calculation sized to content
- Empty filler columns/rows extending to container edges (DBeaver/spreadsheet style)
- Frozen row numbers pinned during horizontal scroll
- Row selection highlighting with tap-to-edit

**Sidebar enhancements:**
- Context menus on databases (Set Active, SQL Editor, Refresh) and tables (Browse Data, Copy Name, Copy SELECT, Truncate, Drop)
- Row count badges (lazy-loaded)
- Filter/search field
- Title changed from "Schema" to "Databases"

**Record editor (staging model):**
- Sheet modal with NavigationStack + Form
- Type-specific editors: text, JSON (format/validate), booleans, dates, numbers
- NULL shown as placeholder — type to replace, "Set to NULL" button to revert
- Modified fields flagged with orange indicator
- Batch apply generates UPDATE ... WHERE pk = ... LIMIT 1
- `.keyboardType(.asciiCapable)` to prevent smart quotes in data fields

**Platform findings:**
- `.inspector()` explicitly `@available(visionOS, unavailable)` — used `.sheet()` instead
- `.navigationSubtitle()` unavailable on visionOS — combined into title string
- `.smartQuotesDisabled()` unavailable on visionOS — used `.keyboardType(.asciiCapable)`

### Round 9 (2026-03-16) — M4 Polish Round 1 (commit 9e9b66b)

**Split editor+results layout:**
- SQL editor (top) + results grid (bottom) in Data tab — DBeaver/SQL Pro Studio pattern
- Dark background on editor area for visual separation
- Draggable resize handle between editor and results panes

**Query execution improvements:**
- Inline Execute button with Cmd+Return keyboard shortcut
- Auto-repeat: context menu on Execute with interval picker (5s/10s/30s/60s)

**Pagination:**
- Page navigation bar with previous/next controls
- Rows-per-page input field
- Total row count display
- LIMIT/OFFSET injection into queries
- Row numbers continue across pages (not reset per page)

**Record editor — Add Row mode:**
- Add Row mode with INSERT SQL generation (alongside existing UPDATE mode)

**Settings:**
- `dataGridFontSize` setting (default 13.0) for data grid font customization

**Toolbar architecture:**
- Moved toolbar to bottom ornament — TabView was swallowing child toolbar items on visionOS
- NotificationCenter-based communication from parent toolbar to child tab views

**AI Assistant:**
- Foundation Models integration (`#if canImport(FoundationModels)`)
- Schema-aware SQL generation (same pattern as glas.sh AIAssistant)
- Error explanation and query summary features
- AI sparkle button entry point in workspace ornament

### Round 10 (2026-03-16) — M4 Polish Round 3 (commit 8f56c06)

- Removed duplicate row stats display
- Execute button moved to header (play icon only, compact)
- Multi-query support: split SQL on semicolons, execute sequentially
- Pager syncs with query LIMIT clause (`isAutoQuery` flag prevents double-limiting)
- Brighter syntax highlighting colors optimized for dark editor background
- Settings gear icon added to workspace ornament
- AI sparkle button entry point refined

## Next Steps (Release Decision)
1. Complete the external provisioning/signing and physical-device acceptance matrix; record those results separately from the already-complete implementation and automated QA.
2. Continue the approved C3/glas.sh Phase 08 **My Connections** contract beyond
   the completed database-library presentation: migrate embedded SSH tunnel
   fields toward neutral endpoint references, add the
   GlasSecretStore credential catalog and eligible-secret mobility, and preserve
   device-bound Secure Enclave/user-presence policy.
3. Prove the canonical glas.sh/iPhone -> glassdb/Vision Pro tunnel journey,
   reverse direction, delayed-secret recovery, account change, deletion/rotation,
   and local Secure Enclave enrollment from correctly signed builds.
4. Review residual capability limits, including incremental streaming, abortive/disconnecting network cancellation, and unsupported PostgreSQL metadata operations, then obtain explicit human approval before TestFlight or production use.
