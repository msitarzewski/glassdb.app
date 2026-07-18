# Codex Completions — Trustworthy Production Core

**Status**: Validation in progress
**Source**: `../../../../docs/glassdb-results.txt` (audit performed 2026-07-16)
**Release principle**: Trust and correctness precede feature breadth.
**Scope rule**: Every audit finding and recommended product-direction item is mapped below; no item is silently deferred.

**Product invariant**: The Vision Pro live database workspace (`query-editor` / `DatabaseWorkspaceView`) must reach 100% transparency and provide continuous opacity and background-blur controls. Connection lists, Settings, detached results, and other application windows retain Apple-recommended system materials by default. Hardening or HIG review may improve the workspace system, but may not remove or neutralize it.

**Platform invariant**: This release contains native, feature-parity application shells for Vision Pro (visionOS 26 or newer) and Apple-silicon Mac (macOS 27 or newer). Both use the shared database, security, query, grid, and settings implementation with platform-native presentation. Intel and Catalyst are excluded. Any future iPadOS/iOS application shell requires its own release plan and acceptance suite.

## Release Goal

Move glassdb from a credible visionOS prototype to a production-safe database client. Completion requires evidence that transport security, host verification, value fidelity, mutations, query execution, credentials, AI, and documentation behave as claimed.

## Verified Compatibility Scope

| Surface | Release scope |
|---|---|
| Applications | Vision Pro / visionOS 26.0+ and native Mac / macOS 27.0+; arm64 only |
| Build environment | Xcode 27.0 beta 27A5209h, visionOS 27.0 and macOS 27.0 SDKs, Swift 6.4 |
| Database engines | MySQL, PostgreSQL, managed-copy SQLite |
| Live server evidence | MySQL 8.4.10 arm64 and PostgreSQL 17.10 disposable containers |
| AI | Foundation Models is weak-linked and runtime-gated on visionOS/macOS 27+; generation is not accepted because direct unsigned-context validation returned model-manager error 1008 |

The passwordless `caching_sha2_password` regression was additionally reproduced with mysql-nio 1.9.1 and verified through GlassDBKit against local MySQL 9.7.1 after pinning the reviewed fork commit `3ad138f`. MySQL 5.7 is not claimed by this release and has no official arm64 container in the current test environment. No iPadOS, iOS, Intel, or Catalyst application target ships. The unsigned macOS archive proves compilation and archive construction only; it is not a signed distributable build.

## Known Capability Limits

- MySQL and PostgreSQL cancellation is abortive: cancelling closes the transport, terminates the active query, and marks the session disconnected. SQLite uses local interruption.
- Query results are buffered. Editor reads are server-bounded with a sentinel row and table browsing is paged, but incremental result streaming/backpressure is not implemented.
- PostgreSQL complete DDL reconstruction and table statistics remain unavailable.
- Sequential scripts stop on failure and the editor displays the latest result; history retains each execution, but a multiple-result-set presentation is not implemented.
- AI generation currently receives privacy-bounded metadata for the selected table and uses MySQL-oriented prompts. Error-explanation and query-summary model methods are not yet exposed in the product UI.
- Foundation Models availability gating is exercised, but direct generation from the unsigned validation context failed with model-manager error 1008. No successful Mac or Vision Pro generation claim is made from that result.
- JSON export builds a bounded in-memory object graph; CSV, TSV, and SQL use lower-peak incremental string construction.
- No physical Vision Pro, signed Mac distribution, Instruments peak-RSS, AddressSanitizer, or full VoiceOver/eye-and-hand acceptance result is claimed by the automated evidence.
- OSV Scanner 2.4 does not parse the Swift lockfile/source layout in this repository; dependency license and source/version inventories were completed separately.
- mysql-nio is temporarily pinned to `msitarzewski/mysql-nio` commit `3ad138f` until Vapor mysql-nio PR #126 is reviewed, tested by upstream CI, merged, and released. The draft PR is cleanly mergeable, but its first-time-contributor workflow is awaiting maintainer approval.

## Credential Boundary

- The shared Keychain access group and App Group integration, bounded metadata catalog, verified readback, and rollback behavior are implemented. Same-device glassdb/glas.sh interoperability still requires validation with correctly provisioned, signed applications; unsigned/direct tests do not prove the runtime entitlement boundary.
- Current records use `WhenUnlockedThisDeviceOnly`; there is no synchronized GlasSecretStore credential catalog or `kSecAttrSynchronizable` item flow yet. Mac-to-Vision-Pro and device-to-device credential synchronization is an open C3 release requirement.
- Secure Enclave keys and user-presence-protected secrets are intentionally device-bound and require per-device provisioning. App-only credentials are neither family-shared nor downgrade-shadowed.
- The final UX must distinguish app-family sharing, device synchronization, and authentication requirements, including the cross-device effect of deleting a synchronized credential.

## Migration and Rollback

- Existing endpoint-keyed credentials are copied to UUID-keyed records; their legacy Keychain records are retained for immediate rollback.
- SSH-key metadata is copied to the App Group and dual-written to the previous build's UserDefaults index during the rollback-support window.
- New or changed `shared with glas.sh` UUID credentials may be absent or stale after downgrade. `glassdb-only` and user-presence credentials are intentionally not downgrade-compatible because shadowing them into legacy shared storage would weaken their policy.
- SQLite imports work on a private managed copy, leaving the user's original database unchanged.
- Before downgrading, retain the current connection export and do not delete Keychain items. Reinstalling the previous binary does not alter server data, but mutations already committed to a database require database-native backups or rollback procedures.

## Tracking Process

Use the repository state machine for every milestone: `PLAN → BUILD → DIFF → QA → APPROVAL → APPLY → DOCS`.

For each milestone:

1. Change its status from `not started` to `in progress` only after an approved implementation plan exists.
2. Check a task only when its acceptance criterion has objective evidence.
3. Record tests, build commands, PR/commit, and residual risks in the milestone's Evidence Log.
4. Do not mark a milestone `done` while any release gate or linked source item remains open.
5. Update this dashboard and the milestone file in the same approved documentation pass.

Allowed statuses: `not started`, `in progress`, `blocked`, `done`.

## Milestone Dashboard

| ID | Milestone | Status | Depends on | Primary result |
|---|---|---|---|---|
| C0 | [Baseline & Truthful Status](C0-baseline-truth.md) | in progress | — | Claims match operational behavior; reproducible baseline |
| C1 | [Transport Security & Host Trust](C1-transport-trust.md) | in progress | C0 | Verified TLS and SSH host identity |
| C2 | [Query Core & Value Fidelity](C2-query-core.md) | in progress | C0 | Typed, precise, cancellable, parser-backed execution |
| C3 | [Credentials & Secret Integration](C3-credentials-secrets.md) | in progress | C0, C1 | Collision-free migrated credentials and explicit policies |
| C4 | [Safe Mutations](C4-safe-mutations.md) | in progress | C1-C3 | Previewed, bound, transactional, auditable changes |
| C5 | [Professional Query Environment](C5-query-environment.md) | in progress | C2, C4 | Documents, completion, history, diagnostics, limits |
| C6 | [Desktop-Class Data Grid](C6-data-grid.md) | in progress | C2, C4 | Server-aware grid and transactional batch editing |
| C7 | [Engines, Platforms & Native UI](C7-engines-platforms.md) | in progress | C1-C6 | Capability-based engines and native Vision Pro/Mac UI |
| C8 | [Safe & Useful AI](C8-safe-ai.md) | in progress | C2, C4, C5 | Private, deterministic, editor-first assistance |
| C9 | [Release Validation](C9-release-validation.md) | in progress | C0-C8 | Security, correctness, compatibility, and docs evidence |

## Source Traceability — Original Audit Baseline

IDs make the external audit stable and checkable even if implementation files move.

| Source IDs | Audit item | Owner milestone |
|---|---|---|
| V01 | Reproduce Xcode 27 beta / visionOS 27 / Swift 6.4 build | C0, C9 |
| V02 | Preserve visionOS 26 deployment and keep platform claims synchronized with the native visionOS/macOS targets | C0, C7, C9 |
| V03-V04 | Preserve 3 GlassDBKit and 62 GlasSecretStore passing tests; expand coverage | C0, C9 |
| V05 | Eliminate or explicitly disposition vendored SSH Swift 6 warnings | C0, C9 |
| V06 | Record the clean audit baseline and subsequent implementation provenance | C0 |
| M01 | Correct overstated completion claims | C0 |
| M02 | AI availability is not initialized; instances are recreated; context is table-only | C8 |
| M03 | AI-generated risk labels can feed immediate execution without deterministic policy | C4, C8 |
| M04 | Row edits use string SQL without binding, transactions, versioning, or affected-row checks | C2, C4, C6 |
| M05 | Auto-reconnect, close confirmation, limits, line numbers, opacity, and blur lack consumers; opacity and blur must be wired, not removed | C0, C5, C7 |
| M06 | Query history is memory-only | C5 |
| M07 | Semicolon splitting is not SQL-aware | C2, C5 |
| M08 | Cross-platform support exists only at package declaration level | C0, C7 |
| S01 | TLS switch is operationally inert | C1 |
| S02-S03 | SSH accepts any host and falls back to all algorithms | C1 |
| S04 | Integrate existing `SSHHostTrustKeychainStore` with TOFU and changed-key rejection | C1, C3 |
| S05-S06 | Preserve typed values; report affected rows and precise execution time | C2 |
| S07 | Destructive schema operations suppress failures | C4 |
| S08-S09 | Endpoint-keyed credentials collide; persistence failures are hidden | C3 |
| G01 | Keep and extend GlasSecretStore | C3 |
| G02-G03 | Use UUID credential identities and invoke endpoint-to-UUID migration | C3 |
| G04 | Add shared/app-only/user-presence credential policies | C3 |
| G05 | Add iOS to GlasSecretStore platforms | C3, C7 |
| G06 | Store shared SSH metadata in the App Group suite | C3 |
| G07 | Correct Secure Enclave P256 naming or make the private key non-exportable | C3 |
| T01-T05 | TLS/pinning, fingerprints, typed bindings, lifecycle controls, safe mutation audit | C1-C4 |
| Q01-Q06 | SQL documents/tabs, parser, completion, diagnostics, explain, history, streaming, keyboard flow | C2, C5 |
| D01-D05 | Filtering/sorting, column controls, typed editing, range workflows, transactional batches | C4, C6 |
| B01-B02 | PostgreSQL then SQLite; capability-based protocol evolution | C7 |
| A01-A05 | Initialize AI, broaden private context, editor-first generation, deterministic classification, side-effect gates | C8 |
| P01 | Shared model/engine with native shells; Catalyst is not the primary design | C7 |
| P02-P05 | Explicit visionOS, macOS, iPadOS, and focused iOS experiences | C7 |
| P06 | Use Apple-recommended materials for general app windows while preserving full transparency and continuous opacity/blur controls in the live database workspace | C0, C7 |
| P07 | Evaluate visionOS 27 RealityKit plus new SwiftUI adaptive toolbar/document APIs | C7 |

## Release Exit Gates

- [x] No connection can claim required TLS while connecting with `tlsConfiguration: nil`.
- [x] SSH connections verify a pinned or explicitly confirmed host identity and reject changed keys.
- [x] Covered MySQL values round-trip without string coercion; affected rows and timings are exercised.
- [x] SQL scripts are parser-backed; bounded/paged reads, timeout, transactions, and local/abortive cancellation outcomes are tested. Automatic reconnect and incremental streaming remain explicit non-capabilities.
- [ ] Every mutation has deterministic classification, preview/confirmation, error propagation, and affected-row verification.
- [x] Credentials use stable connection IDs, migrations are exercised, same-device policies are visible, and persistence failures reach the user.
- [ ] GlasSecretStore owns a stable family credential catalog and synchronizes eligible secrets across supported devices; Secure Enclave/user-presence exceptions are explicit and tested.
- [x] AI generation writes to the editor, never directly executes, and uses deterministic safety gates with explicit privacy controls.
- [x] All settings shown to users have operational consumers or are removed.
- [ ] Appearance controls are operational in the Vision Pro `query-editor` workspace: opacity includes 0% (fully transparent), blur is continuously adjustable, and both persist without compromising usable controls or text legibility; general app windows retain system materials.
- [x] Platform claims match the actual native visionOS and macOS targets and capability-gated engines.
- [x] Shipping deployment settings enforce visionOS 26+, macOS 27+, and Apple Silicon (`arm64`) only, with Intel and Catalyst excluded.
- [ ] CI and release QA pass with zero unexplained warnings; documentation is updated only from verified evidence.

## Evidence Log

| Date | Milestone | Evidence | PR/Commit | Result |
|---|---|---|---|---|
| 2026-07-18 | C0-C9 automated candidate | frozen UX-audit tree: 60/60 app tests on native macOS 27 arm64 and 59/59 on the visionOS 26.4 arm64 simulator; both result bundles report zero build, analyzer, and runtime warnings, skips, or expected failures; 24/24 GlassDBKit; 68/68 GlasSecretStore; Citadel 31 tests with 5 environment-gated skips and 0 failures; 320/320 NIOSSH | `codex-completions` working trees | automated pass; signed/device and cross-device-sync gates remain open |
| 2026-07-18 | Native Mac UX audit | native tabbed/grouped Settings, bounded form controls, validation gates, keyboard actions, adaptive result/editor controls, and a 300/340/440-point connection-sidebar width policy | local source review, ten-cycle finite Settings layout regression, and cross-platform app suites | pass; Vision Pro workspace transparency/blur behavior remains intact |
| 2026-07-18 | Native Mac Settings regression | ten fresh Debug launches and exact Release archive with native Settings auto-opened | local process, unified log, and DiagnosticReports checks | pass; no crash report or AppKit constraint-update-loop diagnostic |
| 2026-07-18 | Live engines | MySQL 8 and PostgreSQL 17 live integration suite | disposable containers | 2/2 passed |
| 2026-07-18 | Passwordless MySQL authentication | official mysql-nio 1.9.1 failure reproduction; focused nil/empty/nonempty auth-response tests; gated GlassDBKit live test against MySQL 9.7.1; exact fork pin in SwiftPM/Xcode; fresh development-signed Mac build | mysql-nio commit `3ad138f`; upstream draft PR #126 | automated live test passed and user confirmed the new Mac app connects; upstream CI awaits maintainer approval |
| 2026-07-18 | Release artifacts | unsigned native macOS Release archive and generic visionOS Release build | local Xcode artifacts | both builds passed; Mac signing/provisioning remains open |
| 2026-07-18 | Foundation Models probe | direct generation from unsigned validation context | native Mac / macOS 27 | availability path reached; generation failed with model-manager error 1008, so generation remains unaccepted |
| 2026-07-17 | Automated security/scale | adversarial TLS/SSH/SQL/SQLite tests, gitleaks, 1K/10K/100K workflows | test/scanner output | pass with documented tooling/device gaps |
| 2026-07-17 | Shared secret dependency | 68/68 tests; newest-generation-only SSH authorization and verified rotation replacement | GlasSecretStore PR #2, merge `b21c137` | pass |
