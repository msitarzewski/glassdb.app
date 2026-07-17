# Project Rules

## Code Standards
- Swift 6 strict concurrency; release verification currently uses Swift 6.4
- @Observable for all state managers (NOT ObservableObject)
- SwiftUI-first, UIKit only when absolutely required
- Only the live database workspace uses `.windowStyle(.plain)` so its background can reach full transparency
- Connections, Settings, detached results, alerts, and sheets use Apple-recommended system window materials
- Ornament-based chrome for contextual controls

## Naming
- App: glassdb (lowercase in code, glassdb.app in marketing)
- Managers: `DatabaseSessionManager`, `ConnectionManager`, `SettingsManager`
- Models: `DatabaseConnection`, `DatabaseSession`, `QueryResult`
- Views: `*View` suffix (e.g., `QueryEditorView`, `ResultsGridView`)

## Architecture
- Study glas.sh equivalent before building any component
- GlassDBKit package for DB protocol abstraction (enables future engines)
- Vendored Citadel for SSH tunnels
- mysql-nio for MySQL connections
