# glassdb

A native visionOS database client built for spatial computing. Glass-first UI, DBeaver-style workspace, on-device AI, and zero cloud dependencies.

**[glassdb.app](https://glassdb.app)** &nbsp;|&nbsp; **[Sponsor](https://github.com/sponsors/msitarzewski)**

![Platform: visionOS 26+](https://img.shields.io/badge/platform-visionOS_26+-1a1a2e?style=flat-square)
![Swift 6.2](https://img.shields.io/badge/Swift-6.2-F05138?style=flat-square&logo=swift&logoColor=white)
![License: MIT](https://img.shields.io/badge/License-MIT-blue?style=flat-square)
![Price: $10](https://img.shields.io/badge/App_Store-$10-0D96F6?style=flat-square&logo=apple&logoColor=white)

---

## Why glassdb

Every database client on visionOS is a port from iPad. glassdb is built from scratch for spatial computing -- glass materials, ornament toolbars, and a workspace layout designed for eye-and-hand interaction.

| Capability | glassdb | DBeaver | TablePlus | DataGrip |
|-----------|---------|---------|-----------|----------|
| Native visionOS | Yes | No | No | No |
| Native iPad (planned) | P3 | No | Yes | No |
| On-device AI | Foundation Models | No | No | No |
| Glass spatial UI | Yes | No | No | No |
| SSH tunnel + key auth | Yes | Yes | Yes | Yes |
| Table data browser | Yes | Yes | Yes | Yes |
| Syntax highlighting | Yes | Yes | Yes | Yes |
| Multi-query execution | Yes | Yes | Yes | Yes |
| Record editor (staging) | Yes | No | Yes | Yes |
| DDL viewer | Yes | Yes | Yes | Yes |
| CSV export | Yes | Yes | Yes | Yes |
| Open source | MIT | CE only | No | No |
| Price | $10 | Free/Paid | $99 | $229/yr |

---

## Features

### Connection Management
- Save, organize, and color-tag database connections
- SSH tunneling with password or key authentication (Ed25519, RSA, Secure Enclave P256)
- Passwords and SSH keys stored in the system Keychain
- Cross-app SSH key sharing with glas.sh via Keychain access groups
- Connection testing and state indicators

### Database Workspace
- DBeaver-style NavigationSplitView sidebar with database and table hierarchy
- Context-sensitive detail surface -- click a table, get a full multi-tab editor
- Click a database, get properties and table statistics
- Context menus on databases (Set Active, SQL Editor, Refresh) and tables (Browse Data, Copy Name, Copy SELECT, Truncate, Drop)
- Row count badges in sidebar (lazy-loaded)
- Filter/search field for navigating large schemas
- Sidebar toggle for focused work

### Query Editor
- SQL syntax highlighting (keywords, functions, strings, numbers, comments, identifiers)
- Dark editor background with high-contrast color theme
- Multi-statement execution (split on semicolons)
- Cmd+Return to execute
- Auto-repeat with configurable interval (5/10/30/60 seconds) via long-press
- Draggable resize handle between editor and results

### Table Browser
- Five-tab detail view per table: **Data**, **Structure**, **DDL**, **Indexes**, **Foreign Keys**
- Paginated data grid with configurable rows per page
- Row numbers that continue across pages
- Content-width columns with empty filler cells (spreadsheet-style)
- Sticky column headers via LazyVStack pinned views
- Column definitions with types, nullability, keys
- Syntax-highlighted DDL with copy button
- Index and foreign key inspection

### Record Editor
- TablePlus-style staging model -- edits are staged visually, not written immediately
- INSERT (add row) and UPDATE (edit row) support
- Type-specific input fields: text, JSON (with format/validate), booleans, dates, numbers
- NULL as placeholder text -- type to replace, button to set NULL
- Modified field indicators with change count
- Batch apply via primary key WHERE clause

### AI Assistant (On-Device, Private)
- **SQL Query Assistant**: Describe what you want in natural language, get a SQL query with risk assessment (safe/moderate/destructive)
- **Error Explainer**: Detects MySQL errors and explains what went wrong with a suggested fix
- **Query Summary**: Complex SQL explained in plain English
- Schema-aware -- passes database, table, and column context for accurate generation
- Powered by Foundation Models -- runs entirely on-device, no data leaves your Vision Pro

### Data Export
- Export query results or table data to CSV
- Triggered from bottom ornament toolbar

### Accessibility
- VoiceOver labels on grid headers, data cells, connection status indicators
- Look to Scroll on all scrollable views
- Keyboard shortcut support (Cmd+Return)

---

## Screenshots

<!-- TODO: Add screenshots -->
<!--
- Connection manager with saved connections
- Database workspace showing sidebar + table data view
- Query editor with syntax highlighting and results grid
- Record editor with staged changes
- AI assistant generating SQL
-->

---

## Getting Started

### Requirements

- Xcode 26 beta or later with visionOS 26 SDK
- Apple Vision Pro or visionOS Simulator
- Swift 6.2 toolchain (ships with Xcode 26)
- GlasSecretStore package at `../GlasSecretStore/` (shared with glas.sh)

### Build from Source

```bash
git clone https://github.com/msitarzewski/glassdb.app.git
cd glassdb.app
open glassdb.xcodeproj
```

Select the **glassdb** scheme, choose a visionOS Simulator or your Apple Vision Pro, and hit Cmd+R. Swift Package Manager resolves `mysql-nio` automatically. Citadel and swift-nio-ssh are vendored in `Packages/`.

**Note:** If you also have glas.sh open in Xcode, close it first -- Xcode cannot have the same local package (GlasSecretStore) open from two projects simultaneously.

---

## Architecture

```
glassdb/                         Main app (24 Swift source files)
├── glassdbApp.swift             Window scenes + bootstrap
├── DatabaseWorkspaceView.swift  Unified workspace, selection routing
├── SchemaBrowserView.swift      Database tree sidebar
├── QueryEditorView.swift        SQL editor with highlighted editing
├── TableDetailView.swift        5-tab table detail (Data/Structure/DDL/Indexes/FK)
├── DatabaseDetailView.swift     Database properties + stats
├── RecordEditorView.swift       Row editor (staging model)
├── ResultsGridView.swift        Detachable results window
├── ConnectionManagerView.swift  Connection hub
├── ConnectionFormView.swift     Add/edit connection form
├── AIAssistant.swift            Foundation Models integration
├── SQLHighlighter.swift         SQL tokenizer + NSAttributedString
├── HighlightedTextEditor.swift  UITextView wrapper for syntax highlighting
├── DataExporter.swift           CSV export document
├── ConnectionManager.swift      Connection CRUD
├── DatabaseSessionManager.swift Session lifecycle + query execution
├── SettingsManager.swift        Settings persistence
├── KeychainManager.swift        GlasSecretStore wrapper
├── Models.swift                 Connection config, enums
├── Constants.swift              UserDefaults keys
├── SettingsView.swift           App settings + SSH key management
└── Logger.swift                 os.Logger categories

Packages/
├── GlassDBKit/                  DatabaseProtocol + MySQLAdapter + models
├── Citadel/                     Vendored SSH library (shared with glas.sh)
└── swift-nio-ssh/               Vendored NIO SSH transport

../GlasSecretStore/              Shared Keychain package (shared with glas.sh)
```

### Key Patterns

- `@Observable` + `@MainActor` for all managers (Observation framework, not Combine)
- `WorkspaceSelection` enum drives context-sensitive detail surface
- `NavigationSplitView` with sidebar + detail for workspace layout
- `.windowStyle(.plain)` for system glass chrome on all windows
- `.toolbar(.bottomOrnament)` for Liquid Glass ornament bars
- `LazyVStack(pinnedViews: .sectionHeaders)` for data grids with sticky headers
- `NotificationCenter` for toolbar-to-TabView-child communication (TabView swallows child toolbars on visionOS)
- `#if canImport(FoundationModels)` gates for AI features
- `simpleQuery` routing for MySQL utility commands (USE, SET, SHOW, DDL)

### Database Layer

`DatabaseProtocol` in GlassDBKit defines the engine interface. `MySQLAdapter` implements it using mysql-nio from the Vapor ecosystem. SSH tunneling runs through Citadel's DirectTCPIP channel forwarding. The protocol is designed for multi-engine support -- PostgreSQL adapter slots in without touching existing code.

### Security

`GlasSecretStore` provides `SecureBytes` and `SSHKeyKeychainStore` APIs for Keychain operations. SSH keys and database passwords never touch UserDefaults. Shared Keychain access group enables cross-app credential sharing with glas.sh.

---

## Roadmap

The full roadmap tracks feature parity against DBeaver CE, TablePlus, and DataGrip. See [parity release plan](memory-bank/releases/parity/release.md) for details.

### Next Up -- P1: Core Parity
- SQL autocomplete (tables, columns, keywords)
- Query history (persisted, searchable)
- Multiple query tabs
- Inline data editing (TablePlus staging model in the grid)
- Data filtering and sorting
- JSON and SQL INSERT export formats
- View support in navigator

### Later -- P2: Power User
- Table creation and ALTER TABLE GUI
- Stored procedures and triggers
- Transaction controls (commit/rollback/auto-commit)
- Data import (CSV, JSON, SQL)
- Saved queries and bookmarks

### Later -- P3: Multi-Engine + Multiplatform
- PostgreSQL engine via postgres-nio
- iPad and Mac targets (View modifier extensions, no #if os in views)
- iCloud Keychain integration (Face ID to connect)
- SQLite support

### Later -- P4: Advanced
- ER diagram visualization (3D spatial on visionOS)
- Explain plan visualization
- Schema comparison with migration SQL
- Database dashboard
- AI-powered query optimization

---

## Sister Project

[glas.sh](https://github.com/msitarzewski/glas.sh) is a native visionOS SSH terminal built with the same architectural patterns. The two apps share:

- **Citadel** and **swift-nio-ssh** vendored packages
- **GlasSecretStore** Keychain package for credential storage
- SSH key credentials via shared Keychain access group
- Glass-first spatial UI patterns
- Foundation Models AI integration

If you import an SSH key in glas.sh, it is immediately available in glassdb's SSH tunnel configuration.

---

## Support the Project

If you find glassdb useful, consider supporting development:

- **[Sponsor on GitHub](https://github.com/sponsors/msitarzewski)** -- recurring or one-time
- **Buy on the App Store** when it ships -- $10 one-time purchase
- **Star the repo** -- helps visibility
- **File issues** -- bug reports and feature requests welcome
- **Contribute** -- PRs welcome, especially for PostgreSQL adapter work

---

## Pricing

| Channel | Price |
|---------|-------|
| App Store | $10 one-time purchase |
| GitHub | Free -- clone and build it yourself |

---

## Known Limitations

- MySQL only (PostgreSQL planned for P3)
- `.inspector()` is unavailable on visionOS -- record editor uses `.sheet()` instead
- `.smartQuotesDisabled()` is unavailable on visionOS -- uses `.keyboardType(.asciiCapable)`
- Secure Enclave keys are device-bound and cannot be transferred
- Foundation Models AI requires visionOS 26 on hardware (not available in Simulator)
- GlasSecretStore must be closed in other Xcode projects before building

## Built With

Built with [Agency Agents](https://github.com/msitarzewski/agency-agents).

## License

[MIT](LICENSE) -- Copyright 2026 Michael Sitarzewski
