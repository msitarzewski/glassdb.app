# Tech Context

## Stack
- **Platform**: visionOS 26.0+ (raised from 2.0 on 2026-03-15)
- **Language**: Swift 6.2, strict concurrency
- **UI**: SwiftUI + visionOS Liquid Glass + ornaments
- **Database client**: mysql-nio (Vapor ecosystem, async NIO-based)
- **SSH tunneling**: Citadel (vendored, shared with glas.sh)
- **NIO**: swift-nio-ssh (vendored patched, shared with glas.sh)
- **State management**: @Observable (Observation framework), NOT ObservableObject
- **Persistence**: Keychain (passwords/SSH keys via GlasSecretStore), UserDefaults/JSON (connections, settings)
- **IDE**: Xcode 26 with visionOS 26 SDK + visionOS Simulator

## Key Patterns (visionOS 26)
- `.windowStyle(.plain)` on all Scene declarations — system handles glass chrome/corners
- NO `.ultraThinMaterial` backgrounds on content windows (causes double-corner artifact)
- `.toolbar { ToolbarItemGroup(placement: .bottomOrnament) }` for Liquid Glass ornaments
- `NavigationSplitView` for sidebar + context-sensitive detail (auto Liquid Glass sidebar)
- `Window` for singleton windows, `WindowGroup(for: UUID.self)` for multi-instance
- Keychain via GlasSecretStore (Security framework, `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`)
- `LazyVStack(pinnedViews: .sectionHeaders)` + `GeometryReader` for data grids

## Platform Constraints (visionOS)
- `.inspector()` — `@available(visionOS, unavailable)`. Use `.sheet()` instead.
- `.navigationSubtitle()` — unavailable. Combine into title string.
- `.smartQuotesDisabled()` — unavailable. Use `.keyboardType(.asciiCapable)`.
- `.buttonStyle(.glassProminent)` — unavailable. Use `.borderedProminent`.

## File Inventory (main target — 23 files)
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
| `DataExporter.swift` | CSV export document |
| `SettingsView.swift` | App settings + SSH key management |
| `SettingsManager.swift` | Settings persistence |
| `KeychainManager.swift` | Thin wrapper over GlasSecretStore |
| `Models.swift` | DatabaseConnectionConfig, enums |
| `Constants.swift` | UserDefaults keys |
| `Logger.swift` | os.Logger categories |

## GlassDBKit Package (4 files)
| File | Role |
|------|------|
| `DatabaseProtocol.swift` | DatabaseEngine + DatabaseConnection protocols, DatabaseError |
| `MySQLAdapter.swift` | mysql-nio wrapper, simpleQuery routing for utility commands |
| `QueryResult.swift` | QueryResult, ColumnInfo, DatabaseValue, IndexInfo, ForeignKeyInfo, TableStatus |

## Dependencies
- mysql-nio: https://github.com/vapor/mysql-nio (^1.0.0)
- Citadel: vendored local package
- swift-nio-ssh: vendored local package (patched for toolchain compat)
- GlasSecretStore: local path dependency (../GlasSecretStore), shared with glas.sh
- Future: postgres-nio for PostgreSQL support (v2.0)
