# glassdb

> Native visionOS database client with a glass-first spatial UI.

![Platform: visionOS 26+](https://img.shields.io/badge/platform-visionOS_26+-1a1a2e?style=flat-square)
![Swift 6.2](https://img.shields.io/badge/Swift-6.2-F05138?style=flat-square&logo=swift&logoColor=white)
![License: MIT](https://img.shields.io/badge/License-MIT-blue?style=flat-square)
![Price: $10](https://img.shields.io/badge/App_Store-$10-0D96F6?style=flat-square&logo=apple&logoColor=white)

<!-- TODO: Add hero screenshot of the workspace view on Vision Pro -->

## What is glassdb?

glassdb is a database management client designed from the ground up for Apple Vision Pro. Not an iPad app in a floating window -- a spatial-native tool built with glass materials, ornaments, and a workspace layout that takes advantage of the room around you.

MySQL today. PostgreSQL next.

Part of the [glas](https://github.com/msitarzewski) family alongside [glas.sh](https://github.com/msitarzewski/glas.sh), a native visionOS SSH terminal. Same architectural DNA, same glass-first aesthetic.

## Features

### Connection Management

- Save, organize, and color-tag database connections
- SSH tunneling with password or key authentication (Ed25519, RSA, Secure Enclave P256)
- Passwords and SSH keys stored in the system Keychain
- Cross-app SSH key sharing with glas.sh via Keychain access groups
- Connection state indicators and one-tap test

### Database Workspace

- DBeaver-style NavigationSplitView sidebar with connection, database, and table hierarchy
- Context-sensitive detail surface -- select a table and get a full multi-tab view
- Active database selector with per-connection state
- Context menus on databases and tables for quick actions

### Query Editor

- SQL syntax highlighting
- Multi-statement execution (separate queries with semicolons)
- Cmd+Return to execute
- Auto-repeat toggle for polling queries
- Results displayed in a scrollable, paginated grid

### Table Browser

- Five-tab detail view per table: **Data**, **Structure**, **DDL**, **Indexes**, **Foreign Keys**
- Paginated data grid with row count
- Column definitions with types, nullability, keys, and defaults
- Auto-generated DDL (SHOW CREATE TABLE)
- Index and foreign key inspection

### Record Editor

- TablePlus-style staging model -- edits are staged visually, not written immediately
- Type-specific input fields based on column definitions
- INSERT and UPDATE support
- Review pending changes before applying

### AI Assistant

- On-device processing via Apple Foundation Models
- Natural language to SQL query generation
- SQL error explanation
- Schema-aware context

### Data Export

- Export query results or table data to CSV
- Copy to clipboard or save to file

### Accessibility

- VoiceOver labels throughout the interface
- Look to Scroll support for spatial navigation

## Screenshots

<!-- TODO: Add screenshots -->
<!--
- Connection manager with saved connections
- Database workspace showing sidebar + table detail
- Query editor with syntax highlighting and results grid
- Record editor with staged changes
-->

## Getting Started

### Requirements

- Xcode 26 beta or later with visionOS 26 SDK
- Apple Vision Pro or visionOS Simulator
- Swift 6.2 toolchain (ships with Xcode 26)

### Build from Source

```bash
git clone https://github.com/msitarzewski/glassdb.app.git
cd glassdb.app
open glassdb.xcodeproj
```

Select the **glassdb** scheme, choose a visionOS Simulator or your Apple Vision Pro, and hit Cmd+B. Swift Package Manager resolves `mysql-nio` automatically. The Citadel and swift-nio-ssh packages are vendored in `Packages/`.

## Architecture

```
glassdb/                  App target (~20 Swift source files)
Packages/
  GlassDBKit/             DatabaseProtocol abstraction + MySQLAdapter + SSH tunnel
  GlasSecretStore/        Shared Keychain/SecureBytes package (shared with glas.sh)
  Citadel/                Vendored SSH library (shared with glas.sh)
  swift-nio-ssh/          Vendored NIO SSH transport (shared with glas.sh)
```

**UI layer**: SwiftUI with `@Observable` managers (Observation framework). No `ObservableObject`, no Combine. Windows use `.windowStyle(.plain)` with glass materials (`.ultraThinMaterial`).

**Workspace**: `DatabaseWorkspaceView` uses a `NavigationSplitView` with a schema browser sidebar and context-sensitive detail pane. Query editor, results grid, and table detail views compose inside the workspace.

**Database layer**: `DatabaseProtocol` in GlassDBKit defines the engine interface. `MySQLAdapter` implements it today using mysql-nio from the Vapor ecosystem. SSH tunneling runs through Citadel's DirectTCPIP channel forwarding.

**Security**: `GlasSecretStore` provides a `SecureBytes` API for Keychain operations, shared with glas.sh via access groups. SSH keys and database passwords never touch UserDefaults.

## Roadmap

The full roadmap tracks feature parity against DBeaver CE, TablePlus, and DataGrip. Key upcoming milestones:

**Next up (P1 -- Core Parity)**
- SQL autocomplete (tables, columns, keywords)
- Query history (persisted, searchable)
- Multiple query tabs
- Inline data editing (TablePlus staging model)
- Data filtering and sorting
- JSON and SQL INSERT export formats
- View support in navigator

**Later (P2-P4)**
- PostgreSQL engine via postgres-nio
- iPad and Mac targets
- Table creation and ALTER TABLE GUI
- Stored procedures and triggers
- ER diagram visualization
- Explain plan visualization
- Schema comparison and diff

See [memory-bank/releases/parity/release.md](memory-bank/releases/parity/release.md) for the full release plan.

## Sister Project

[glas.sh](https://github.com/msitarzewski/glas.sh) is a native visionOS SSH terminal built with the same architectural patterns. The two apps share vendored packages (Citadel, swift-nio-ssh), the GlasSecretStore Keychain package, and SSH key credentials via Keychain access groups. If you connect to a server in glas.sh, that key is available in glassdb's SSH tunnel configuration.

## Pricing

| Channel | Price |
|---------|-------|
| App Store | $10 one-time purchase |
| GitHub | Free -- clone and build it yourself |

## Contributing

Issues and PRs welcome. If you are building something for visionOS and want to collaborate, open an issue.

## License

[MIT](LICENSE) -- Copyright 2026 Michael Sitarzewski

Free to use, modify, and distribute. If you find it useful, consider buying it on the App Store when it ships.
