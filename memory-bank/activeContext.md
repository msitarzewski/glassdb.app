# Active Context

## Current Phase
`codex-completions` final release validation. The application now has native arm64 shells for Vision Pro (visionOS 26.0+) and Apple silicon Mac (macOS 27.0+); Intel and Mac Catalyst remain excluded. GlassDBKit provides MySQL, PostgreSQL, and managed-copy SQLite adapters, and GlasSecretStore remains the shared credential package.

## Current Focus
The native macOS implementation and automated platform/package QA are complete. MySQL passwordless `caching_sha2_password` authentication is corrected by an immutable temporary pin to `msitarzewski/mysql-nio` commit `3ad138f`; the upstream draft is Vapor mysql-nio PR #126 and its first-time-contributor workflow still requires maintainer approval. Remaining release work is explicitly separated into: (1) external provisioning/distribution signing and physical-device acceptance, including Vision Pro/Mac Keychain, user-presence, Secure Enclave, and supported Foundation Models checks; (2) C3 cross-device credential synchronization for eligible secrets; and (3) human review of residual risks and release approval. The coordinated GlasSecretStore hardening dependency is published in PR #2 (`b21c137`). Secure Enclave and user-presence-protected secrets remain intentionally device-bound and require per-device provisioning. TestFlight submission is not automatic.

## Recent Changes

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
2. Implement and test the open C3 cross-device Glass-family credential catalog and synchronization for eligible secrets without weakening device-bound Secure Enclave/user-presence policies.
3. Review residual capability limits, including incremental streaming, abortive/disconnecting network cancellation, and unsupported PostgreSQL metadata operations, then obtain explicit human approval before TestFlight or production use.
