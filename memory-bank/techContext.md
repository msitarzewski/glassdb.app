# Tech Context

## Stack
- **Platform**: visionOS 26.0+ on arm64; no macOS, iPadOS, iOS, Intel, or Catalyst application target ships in this release
- **Language**: Swift 6 strict concurrency; verified with Swift 6.4 in Xcode 27 beta
- **UI**: SwiftUI + visionOS Liquid Glass + ornaments
- **Database clients**: mysql-nio, postgres-nio, and system SQLite
- **SSH tunneling**: Citadel (vendored, shared with glas.sh)
- **NIO**: swift-nio-ssh (vendored patched, shared with glas.sh)
- **State management**: @Observable (Observation framework), NOT ObservableObject
- **Persistence**: Keychain (passwords/SSH keys via GlasSecretStore), UserDefaults/JSON (connections, settings)
- **IDE**: Xcode 27 beta 27A5209h with visionOS 27 SDK; deployment and minimum-runtime QA remain visionOS 26+

## Key Patterns (visionOS 26)
- `.windowStyle(.plain)` only on the live database workspace so opacity can reach 0%; general windows keep system materials
- Continuous 0...1 workspace opacity and blur are independent persisted settings
- `.toolbar { ToolbarItemGroup(placement: .bottomOrnament) }` for Liquid Glass ornaments
- `NavigationSplitView` for sidebar + context-sensitive detail (auto Liquid Glass sidebar)
- `Window` for singleton windows, `WindowGroup(for: UUID.self)` for multi-instance
- Keychain via GlasSecretStore. Current records use `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`: same-device app-family sharing works, but cross-device synchronization is a C3 requirement not yet implemented.
- `LazyVStack(pinnedViews: .sectionHeaders)` + `GeometryReader` for data grids

## Platform Constraints (visionOS)
- `.inspector()` — `@available(visionOS, unavailable)`. Use `.sheet()` instead.
- `.navigationSubtitle()` — unavailable. Combine into title string.
- `.smartQuotesDisabled()` — unavailable. Use `.keyboardType(.asciiCapable)`.
- `.buttonStyle(.glassProminent)` — unavailable. Use `.borderedProminent`.

## File Inventory (main target — 22 top-level Swift files)
| File | Role |
|------|------|
| `glassdbApp.swift` | App entry, window scenes |
| `ConnectionManagerView.swift` | Connection hub sidebar+detail |
| `ConnectionFormView.swift` | Add/edit connection form |
| `ConnectionManager.swift` | Connection CRUD |
| `DatabaseSessionManager.swift` | Session lifecycle, query execution |
| `DatabaseWorkspaceView.swift` | Unified workspace, selection routing |
| `SchemaBrowserView.swift` | Database tree sidebar with filter/context menus |
| `QueryEditorView.swift` | SQL editor with highlighted editing + inline results |
| `TableDetailView.swift` | 5-tab table detail (Data/Structure/DDL/Indexes/FK) |
| `DatabaseDetailView.swift` | Database properties + stats |
| `ResultsGridView.swift` | Detachable results window |
| `RecordEditorView.swift` | Row editor sheet (staging model) |
| `SQLHighlighter.swift` | SQL tokenizer + NSAttributedString highlighting |
| `HighlightedTextEditor.swift` | UIViewRepresentable UITextView wrapper |
| `DataExporter.swift` | CSV, TSV, JSON, and SQL INSERT export workflows |
| `SettingsView.swift` | App settings + SSH key management |
| `SettingsManager.swift` | Settings persistence |
| `KeychainManager.swift` | Thin wrapper over GlasSecretStore |
| `Models.swift` | DatabaseConnectionConfig, enums |
| `Constants.swift` | UserDefaults keys |
| `AIAssistant.swift` | Foundation Models AI integration (SQL gen, error explain, summary) |
| `Logger.swift` | os.Logger categories |

## GlassDBKit Package (6 files)
| File | Role |
|------|------|
| `DatabaseProtocol.swift` | DatabaseEngine + DatabaseConnection protocols, DatabaseError |
| `MySQLAdapter.swift` | mysql-nio wrapper, simpleQuery routing for utility commands |
| `PostgreSQLAdapter.swift` | postgres-nio wrapper with explicit capability gating |
| `SQLiteAdapter.swift` | local SQLite wrapper used with managed private file copies |
| `QueryResult.swift` | QueryResult, ColumnInfo, DatabaseValue, IndexInfo, ForeignKeyInfo, TableStatus |
| `SSHTunnelManager.swift` | verified-host Citadel tunnel orchestration and SSH key routing |

## Dependencies
- mysql-nio: https://github.com/vapor/mysql-nio (resolved 1.9.1)
- postgres-nio: https://github.com/vapor/postgres-nio (resolved 1.33.0)
- Citadel: vendored local package
- swift-nio-ssh: vendored local package (patched for toolchain compat)
- GlassConnectionKit: reviewed exact remote revision for the neutral endpoint contract
- GlasSecretStore: reviewed exact remote revision shared with glas.sh
- Foundation Models: weak-linked system framework; generation is runtime-gated to visionOS 27+
