# glassdb

Native visionOS database client with a glass-first spatial UI.

MySQL today. PostgreSQL next. Built for Apple Vision Pro — not an iPad app in a floating window.

## What is this?

glassdb is a database management client designed from the ground up for visionOS. Glass materials, ornaments, multi-window spatial layout. Connect to MySQL servers directly or through SSH tunnels, write queries, browse schemas, and pin results in your space.

Part of the [glas](https://github.com/msitarzewski) family alongside [glas.sh](https://github.com/msitarzewski/glas.sh) (native visionOS SSH terminal).

## Features

- **Connection Manager** — Save, organize, and color-tag your database connections
- **SSH Tunneling** — Connect to remote databases through SSH with password or key authentication (Ed25519, RSA, Secure Enclave P256)
- **Multi-Window Spatial Layout** — Query editor, results grid, and schema browser as separate windows you arrange in space
- **Keychain Storage** — Passwords and SSH keys stored securely in the system Keychain
- **Cross-App Key Sharing** — SSH keys shared with glas.sh via Keychain access groups
- **MySQL via mysql-nio** — Async, NIO-based MySQL client from the Vapor ecosystem

### Roadmap

- SQL syntax highlighting
- Schema browser with live introspection
- Query history
- Export to CSV/JSON
- PostgreSQL support (v0.2)
- Table data browsing and inline editing (v0.2)

## Get It

| Channel | Price |
|---------|-------|
| App Store | $10 one-time *(coming soon)* |
| GitHub | Free — clone and build it yourself |

## Build from Source

### Requirements

- Xcode 16+ with visionOS SDK
- visionOS 2.0+ deployment target
- Swift 6.2 toolchain
- Apple Vision Pro or visionOS Simulator

### Steps

```bash
git clone https://github.com/msitarzewski/glassdb.app.git
cd glassdb.app
open glassdb.xcodeproj
```

Select the **glassdb** scheme, choose a visionOS Simulator or your Apple Vision Pro, and build (Cmd+B). Swift Package Manager will resolve `mysql-nio` automatically. The Citadel and swift-nio-ssh packages are vendored in `Packages/`.

## Architecture

```
glassdb/                  App target (15 Swift source files)
Packages/
  GlassDBKit/             Database protocol abstraction + MySQL adapter + SSH tunnel
  Citadel/                Vendored SSH library (shared with glas.sh)
  swift-nio-ssh/          Vendored NIO SSH transport (shared with glas.sh)
```

**Windows**: Connections (main hub), Query Editor, Results Grid, Schema Browser, Settings — each a separate spatial window with `.windowStyle(.plain)` and glass materials.

**State**: `@Observable` managers (Observation framework) — `DatabaseSessionManager`, `ConnectionManager`, `SettingsManager`. No `ObservableObject`, no Combine.

**Database layer**: `DatabaseEngine` protocol in GlassDBKit with `MySQLAdapter` today, `PostgreSQLAdapter` planned. SSH tunneling via Citadel's DirectTCPIP channel forwarding.

## Status

Early alpha. The connection manager, SSH tunneling, and Keychain integration are working. Currently wiring the end-to-end flow from connect through query execution to results display.

See [memory-bank/progress.md](memory-bank/progress.md) for detailed status.

## Contributing

This is an early-stage project. Issues and PRs welcome. If you're building something for visionOS and want to collaborate, open an issue.

## License

[MIT](LICENSE) — Copyright 2026 Michael Sitarzewski

Free to use, modify, and distribute. If you find it useful, consider buying it on the App Store when it ships.
