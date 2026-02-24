# glassdb.app — Native visionOS Database Client

**Version**: 0.1.0 (scaffolding)
**Status**: Pre-development — architecture and scaffolding phase
**Parent project**: [glas.sh](https://github.com/msitarzewski/glas.sh) (shared patterns, separate codebase)

---

## Vision

glassdb.app is a native visionOS database management client with a glass-first spatial UI. It is the database counterpart to glas.sh (native visionOS SSH terminal). Like glas.sh, it is:

- **Open source** on GitHub (compile-it-yourself)
- **$10 one-time purchase** on the App Store
- **MySQL first**, with PostgreSQL as a planned fast-follow
- Built with SwiftUI + visionOS ornaments + glass materials — not an iPad app in a floating window

---

## Architecture — Reuse from glas.sh

The following patterns and components from glas.sh should be studied and adapted (not copied verbatim — separate repo, separate app):

### Direct Reuse Patterns

| glas.sh Pattern | glassdb.app Equivalent | Source Reference |
|---|---|---|
| `App` scene structure with `Window` + `WindowGroup` | Same multi-window pattern: Connections, Query Editor, Results, Schema Browser | `glas_shApp.swift` |
| `WindowPresenceTrackingModifier` | Reuse verbatim — tracks window lifecycle | `glas_shApp.swift:99-112` |
| `SessionManager` / `SettingsManager` (`@Observable`) | `DatabaseSessionManager` / `SettingsManager` | `Managers.swift` |
| `ServerConfiguration` model (Codable, Identifiable) | `DatabaseConnection` model (host, port, user, auth, SSH tunnel config) | `Models.swift:46-108` |
| `ServerManager` (CRUD for saved servers, Keychain passwords) | `ConnectionManager` (CRUD for saved DB connections) | `Managers.swift` |
| `ConnectionManagerView` (NavigationSplitView, sidebar+detail) | `ConnectionManagerView` (same pattern, DB-specific fields) | `ConnectionManagerView.swift` |
| SSH tunnel via Citadel | SSH tunnel for remote DB connections (reuse Citadel vendored package) | `Packages/Citadel/` |
| `.background(.ultraThinMaterial, in: .rect(cornerRadius: 24))` | Same glass material treatment for all windows | `TerminalWindowView.swift:41` |
| `.windowStyle(.plain)` on all scenes | Same — required for glass-first visionOS look | `glas_shApp.swift` |
| Keychain helper for secrets | Reuse pattern for DB passwords | `Managers.swift` (SecretStore) |
| `ServerColorTag` enum | Reuse for connection color coding | `Models.swift:110-131` |
| AGENTS.md + memory-bank structure | Copy and adapt for glassdb.app repo | `AGENTS.md`, `memory-bank/` |

### New Components (glassdb.app specific)

| Component | Purpose |
|---|---|
| `QueryEditorView` | SQL editor with syntax highlighting, autocomplete, linting |
| `ResultsGridView` | Data grid for query results — detachable as separate window |
| `SchemaBrowserView` | Tree/list of databases → tables → columns → indexes |
| `TableDataView` | Browse/edit table data inline |
| `QueryHistoryView` | Searchable history of executed queries |
| `DatabaseSession` model | Active connection state, query execution, result caching |
| MySQL NIO client | `mysql-nio` from Vapor ecosystem for async MySQL |
| SQL Syntax Engine | Highlighting + linting + autocomplete (schema-aware) |

---

## Project Structure

```
glassdb.app/
├── AGENTS.md                          # AI agent instructions (adapt from glas.sh)
├── README.md                          # Public readme
├── memory-bank/                       # Persistent context (adapt from glas.sh)
│   ├── toc.md
│   ├── projectbrief.md
│   ├── productContext.md
│   ├── systemPatterns.md
│   ├── techContext.md
│   ├── activeContext.md
│   ├── progress.md
│   ├── projectRules.md
│   ├── decisions.md
│   ├── quick-start.md
│   └── tasks/
├── glassdb.xcodeproj/                 # Xcode project
├── glassdb/                           # Main app target
│   ├── glassdbApp.swift               # App entry, scene declarations
│   ├── Models.swift                   # DatabaseConnection, QueryResult, etc.
│   ├── Managers.swift                 # DatabaseSessionManager, ConnectionManager, SettingsManager
│   ├── ConnectionManagerView.swift    # Main hub — saved connections
│   ├── QueryEditorView.swift          # SQL editor window
│   ├── ResultsGridView.swift          # Query results window (detachable)
│   ├── SchemaBrowserView.swift        # Database/table/column tree
│   ├── TableDataView.swift            # Browse/edit table rows
│   ├── QueryHistoryView.swift         # Past queries
│   ├── SettingsView.swift             # App settings
│   ├── ServerFormViews.swift          # Add/Edit connection forms
│   ├── SQLSyntaxEngine/              # Syntax highlighting + autocomplete
│   │   ├── SQLLexer.swift
│   │   ├── SQLHighlighter.swift
│   │   └── SchemaCompleter.swift
│   ├── Assets.xcassets/
│   └── Info.plist
├── glassdbTests/
├── Packages/
│   ├── Citadel/                       # Vendored SSH (same as glas.sh for tunnel support)
│   ├── swift-nio-ssh/                 # Vendored patched dep (same as glas.sh)
│   └── GlassDBKit/                    # Shared package for DB protocol abstraction
│       ├── Package.swift
│       └── Sources/GlassDBKit/
│           ├── DatabaseProtocol.swift # Protocol for MySQL/Postgres/future engines
│           ├── MySQLAdapter.swift     # mysql-nio wrapper
│           └── QueryResult.swift      # Unified result model
└── docs/                              # Website (glassdb.app)
    ├── index.html
    └── styles.css
```

---

## Window Architecture

Mirrors the glas.sh multi-window model:

```swift
@main
struct glassdbApp: App {
    @State private var sessionManager = DatabaseSessionManager(loadImmediately: false)
    @State private var settingsManager = SettingsManager(loadImmediately: false)
    @State private var windowRecoveryManager = WindowRecoveryManager()

    var body: some Scene {
        // Connection manager — PRIMARY WINDOW (single instance)
        Window("Connections", id: "main") {
            MainBootstrapView()
                .environment(sessionManager)
                .environment(settingsManager)
                .trackWindowPresence(key: "main", recovery: windowRecoveryManager)
        }
        .windowStyle(.plain)
        .defaultSize(width: 1320, height: 760)

        // Query editor windows (can open multiple — one per connection)
        WindowGroup(id: "query-editor", for: UUID.self) { $sessionID in
            // ...
        }
        .windowStyle(.plain)
        .defaultSize(width: 1200, height: 800)

        // Results grid windows (detachable — pin results in space)
        WindowGroup(id: "results", for: UUID.self) { $resultSetID in
            // ...
        }
        .windowStyle(.plain)
        .defaultSize(width: 1000, height: 600)

        // Schema browser
        Window("Schema", id: "schema") {
            // ...
        }
        .windowStyle(.plain)
        .defaultSize(width: 400, height: 700)

        // Settings
        Window("Settings", id: "settings") {
            // ...
        }
        .windowStyle(.plain)
        .defaultSize(width: 700, height: 600)
    }
}
```

**Spatial UX concept**: User opens Connections window → connects to a MySQL server → Query Editor window opens → runs a query → Results detach into their own window pinned to the left → Schema browser floats as a narrow panel on the right. All glass material, all spatial.

---

## Data Models (Core)

```swift
// DatabaseConnection — equivalent to glas.sh ServerConfiguration
struct DatabaseConnection: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var engine: DatabaseEngine          // .mysql (later: .postgresql)
    var host: String
    var port: Int                       // default 3306 for MySQL
    var username: String
    var defaultDatabase: String?
    var useSSHTunnel: Bool
    var sshHost: String?
    var sshPort: Int?
    var sshUsername: String?
    var sshAuthMethod: AuthenticationMethod?
    var sshKeyID: UUID?
    var useTLS: Bool
    var isFavorite: Bool
    var colorTag: ServerColorTag
    let dateAdded: Date
    var lastConnected: Date?
    var tags: [String]
}

enum DatabaseEngine: String, Codable, CaseIterable {
    case mysql
    // case postgresql  // Phase 2
}

// QueryResult — unified result model
struct QueryResult: Identifiable {
    let id: UUID
    let query: String
    let columns: [ColumnInfo]
    let rows: [[DatabaseValue]]
    let affectedRows: Int?
    let executionTime: TimeInterval
    let timestamp: Date
    let error: String?
}

struct ColumnInfo: Identifiable {
    let id: UUID
    let name: String
    let type: String
    let isNullable: Bool
    let isPrimaryKey: Bool
}

enum DatabaseValue {
    case string(String)
    case int(Int64)
    case double(Double)
    case data(Data)
    case null
    case date(Date)
}
```

---

## Dependencies

```swift
// GlassDBKit/Package.swift
let package = Package(
    name: "GlassDBKit",
    platforms: [
        .visionOS(.v2),
        .macOS(.v15),
        .iOS(.v18)
    ],
    products: [
        .library(name: "GlassDBKit", targets: ["GlassDBKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/mysql-nio.git", from: "1.0.0"),
        .package(path: "../Citadel"),
        // Phase 2: .package(url: "https://github.com/vapor/postgres-nio.git", from: "1.21.0"),
    ],
    targets: [
        .target(
            name: "GlassDBKit",
            dependencies: [
                .product(name: "MySQLNIO", package: "mysql-nio"),
                .product(name: "Citadel", package: "Citadel"),
            ]
        ),
    ]
)
```

---

## SQL Syntax Engine (v1 scope)

### Highlighting
- MySQL keyword highlighting (SELECT, FROM, WHERE, JOIN, INSERT, UPDATE, DELETE, CREATE, ALTER, DROP, etc.)
- String literal highlighting (single-quoted)
- Numeric literal highlighting
- Comment highlighting (-- and /* */)
- Identifier highlighting (backtick-quoted)

### Autocomplete (schema-aware)
- Database names (from connected server)
- Table names (from selected database)
- Column names (from table context in query)
- MySQL keywords
- MySQL functions (COUNT, SUM, AVG, NOW, etc.)

### Linting (v1 — lightweight)
- Unclosed strings/parentheses
- Unknown table/column warnings (when schema loaded)
- Missing semicolons (optional warning)

---

## MVP Feature Scope (v0.1)

### Must Have
- [ ] Connection manager (add/edit/delete MySQL connections)
- [ ] SSH tunnel support (reuse Citadel from glas.sh)
- [ ] Keychain password storage
- [ ] Connect to MySQL server
- [ ] Query editor with syntax highlighting
- [ ] Execute query, display results in grid
- [ ] Schema browser (databases → tables → columns)
- [ ] Multi-window (editor + results as separate spatial windows)
- [ ] Glass material UI throughout
- [ ] visionOS ornament-based chrome

### Should Have
- [ ] Query history (persisted)
- [ ] Export results (CSV, JSON)
- [ ] Table data browsing (SELECT * with pagination)
- [ ] Inline cell editing
- [ ] Multiple query tabs per connection
- [ ] Autocomplete (keyword + schema-aware)

### Won't Have (v0.1)
- PostgreSQL support (v0.2)
- ER diagram visualization
- Stored procedure editor
- Database backup/restore
- User/privilege management
- Data import wizard

---

## Distribution

| Channel | Price | Notes |
|---|---|---|
| App Store | $10 one-time | Universal purchase (visionOS) |
| GitHub | Free | Open source, compile yourself |

---

## Development Workflow

1. Create GitHub repo: `msitarzewski/glassdb.app`
2. Initialize Xcode project targeting visionOS 2.0+
3. Copy + adapt AGENTS.md and memory-bank from glas.sh
4. Vendor Citadel + swift-nio-ssh packages (symlink or copy from glas.sh)
5. Create GlassDBKit package with mysql-nio dependency
6. Build connection manager (adapt from glas.sh ConnectionManagerView)
7. Build query editor with basic syntax highlighting
8. Build results grid
9. Build schema browser
10. Wire up SSH tunnel + MySQL connection flow
11. Polish glass materials + ornaments
12. TestFlight → App Store

---

## Notes for Claude Code

- **This is a separate Xcode project and repo** — do not modify glas.sh
- **Reuse architectural patterns** from glas.sh, not code verbatim (different imports, different models)
- **The Citadel and swift-nio-ssh vendored packages** can be copied from glas.sh since they're the same SSH layer
- **mysql-nio** is async/NIO-based, which aligns perfectly with the existing Citadel/NIO stack
- **SwiftUI + visionOS ornaments** are the UI layer — no UIKit unless absolutely necessary
- **`.windowStyle(.plain)`** on every scene — this is what enables the glass-first look
- **`.background(.ultraThinMaterial, in: .rect(cornerRadius: 24))`** is the standard glass treatment
- **`@Observable` (Observation framework)** for all managers, not `ObservableObject`
- **Target visionOS 2.0+** minimum (same as glas.sh)
- **Swift 6.2 toolchain** (same as glas.sh Package.swift)
