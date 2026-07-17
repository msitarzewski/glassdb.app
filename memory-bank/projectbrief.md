# Project Brief

## glassdb.app

Native visionOS database management client with a glass-first spatial UI and MySQL, PostgreSQL, and managed-copy SQLite engines. Open source on GitHub, with a planned $10 App Store price. Sister project to glas.sh (native visionOS SSH terminal). Shared architectural DNA: multi-window, ornament-based chrome, glass materials, Citadel SSH tunnels, and `@Observable` managers. The live database workspace alone uses `.windowStyle(.plain)` for user-adjustable transparency; general windows retain system materials.

## Product-Defining Appearance Requirement

glassdb exists to provide a premium Vision Pro database experience whose live database workspace—the `query-editor` scene hosting `DatabaseWorkspaceView`, where users write SQL and manage rows—can be made 100% transparent. Continuous opacity and background-blur controls for that workspace are non-negotiable product functionality. Connection management, Settings, and other application windows should retain Apple-recommended system materials. Platform-material reviews may improve the workspace implementation and accessibility, but must not remove, neutralize, or constrain away its full transparency and adjustable blur.

## Platform Baseline

This release ships only the native Vision Pro application on visionOS 26 or newer and arm64. A native macOS application is deferred; when built, it will be Apple Silicon only. Intel and Mac Catalyst are out of scope. Simulator architectures are development/test artifacts, not supported shipping CPU architectures.
