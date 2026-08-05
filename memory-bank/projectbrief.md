# Project Brief

## glassdb.app

Native Apple-platform database management client with a glass-first spatial UI and MySQL, PostgreSQL, and managed-copy SQLite engines. Open source on GitHub, with a planned $10 App Store price. Sister project to glas.sh (native SSH terminal). Shared architectural DNA: multi-window, ornament-based chrome, glass materials, Citadel SSH tunnels, and `@Observable` managers. The live database workspace alone uses `.windowStyle(.plain)` for user-adjustable transparency; general windows retain system materials.

Across the Glass family, connections must feel *Magic / First Class*: define an
SSH connection once, find it in glas.sh and glassdb across supported Apple
devices, and use it as a terminal destination or database tunnel with the least
intervention compatible with honest security. glassdb owns database behavior and
SSH-tunnel selection, not a second copy of shared endpoint or credential truth.

## Product-Defining Appearance Requirement

glassdb exists to provide a premium Vision Pro database experience whose live database workspace—the `query-editor` scene hosting `DatabaseWorkspaceView`, where users write SQL and manage rows—can be made 100% transparent. Continuous opacity and background-blur controls for that workspace are non-negotiable product functionality. Connection management, Settings, and other application windows should retain Apple-recommended system materials. Platform-material reviews may improve the workspace implementation and accessibility, but must not remove, neutralize, or constrain away its full transparency and adjustable blur.

## Platform Baseline

The shared native arm64 application target supports focused iPhone, desktop-class
iPad, Apple silicon Mac, and Vision Pro experiences. iOS/iPadOS and visionOS
require 26.0+, macOS requires 27.0+, and Intel plus Mac Catalyst remain out of
scope. Simulator architectures are development/test artifacts, not supported
shipping CPU architectures.
