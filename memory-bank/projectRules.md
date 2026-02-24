# Project Rules

## Code Standards
- Swift 6.2, strict concurrency
- @Observable for all state managers (NOT ObservableObject)
- SwiftUI-first, UIKit only when absolutely required
- All windows: `.windowStyle(.plain)`
- Glass material: `.background(.ultraThinMaterial, in: .rect(cornerRadius: 24))`
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
