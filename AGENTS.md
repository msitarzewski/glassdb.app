# AGENTS.md

**Version**: 2.1 (2025-10-25) | **Compatibility**: Claude, Cursor, Copilot, Cline, Aider, all AGENTS.md-compatible tools
**Status**: Canonical single-file guide for AI-assisted development
**Project**: glassdb.app — Native visionOS Database Client

---

## Project Context

glassdb.app is a native visionOS database management client with a glass-first spatial UI. It is the database counterpart to [glas.sh](https://github.com/msitarzewski/glas.sh) (native visionOS SSH terminal).

**Key facts**:
- visionOS 26.0+ target, Apple Silicon only, Swift 6 strict concurrency (verified with Swift 6.4)
- SwiftUI + visionOS ornaments + glass materials (`.windowStyle(.plain)`, `.ultraThinMaterial`)
- MySQL (mysql-nio), PostgreSQL (postgres-nio), and managed-copy SQLite engines
- SSH tunnel support via vendored Citadel package (shared with glas.sh)
- `@Observable` (Observation framework) for all managers
- Multi-window architecture: Connections, transparent Database Workspace, detached Results Grid, and Settings
- Architectural patterns derived from glas.sh — study `PROJECT_SCAFFOLD.md` for mapping

**Sister project reference**: When uncertain about visionOS patterns, consult glas.sh source. Key files:
- `glas_shApp.swift` — Window/Scene architecture
- `TerminalWindowView.swift` — Glass material + ornament patterns
- `ConnectionManagerView.swift` — Connection management UI
- `Models.swift` — Codable model patterns
- `Managers.swift` — @Observable manager patterns, Keychain, session lifecycle

---

## Table of Contents

1. [Compliance & Core Rules](#1-compliance--core-rules)
2. [Session Startup](#2-session-startup)
3. [Memory Bank](#3-memory-bank)
4. [State Machine](#4-state-machine)
5. [Quality & Documentation](#6-quality--documentation)

---

## 1. Compliance & Core Rules

### Startup Compliance (Output Every Session)

```
COMPLIANCE CONFIRMED: Reuse over creation

⚠️  GIGO PREVENTION - User Responsibilities:
📋 Clear task objectives | 🔗 Historical context | 🎯 Success criteria
⚙️  Architectural constraints | 🎖️ You lead - clear input = excellent output

[Continue with Memory Bank loading...]
```

### The Four Sacred Rules

| Rule | Requirement | Validation |
|------|-------------|------------|
| ❌ **No new files without reuse analysis** | Search codebase, reference files that cannot be extended, provide exhaustive justification | Before creating: "Analyzed X, Y, Z. Cannot extend because [technical reason]" |
| ❌ **No rewrites when refactoring possible** | Prefer incremental improvements, justify why refactoring won't work | "Refactoring X impossible because [specific limitation]" |
| ❌ **No generic advice** | Cite `file:line`, show concrete integration points, include migration strategies | Every suggestion includes `file:line` citation |
| ❌ **No ignoring existing architecture** | Load patterns before changes, extend existing services/components, consolidate duplicates | "Extends existing pattern at `file:line`" |

### Non-Negotiables

- **Approval Gates**: No file changes without explicit user approval
- **Citations**: Always `file:line` for code, `file.md#Section` for Memory Bank
- **Sandbox First**: All edits in branch/temp clone, never main
- **No Mock Data**: Never fake/simulated data in production; never stub functions
- **Sister Project Patterns**: When building a component that has a glas.sh equivalent, study the glas.sh implementation first

---

## 2. Session Startup

### Load Priority

**Every Session** (mandatory):
1. Output compliance statement
2. Load `memory-bank/activeContext.md` and `memory-bank/progress.md`
3. Check `PROJECT_SCAFFOLD.md` for architecture reference

**Standard Discovery** (features, tests):
- Core files: projectbrief.md, systemPatterns.md, techContext.md, activeContext.md, progress.md
- Check `PROJECT_SCAFFOLD.md` for glas.sh pattern mapping

---

## 3. Memory Bank

### Structure

```
memory-bank/
├── toc.md
├── projectbrief.md
├── productContext.md
├── systemPatterns.md
├── techContext.md
├── activeContext.md
├── progress.md
├── projectRules.md
├── decisions.md
├── quick-start.md
└── tasks/
```

---

## 4. State Machine

`PLAN [user approves] → BUILD → DIFF → QA [pass] → APPROVAL [user approves] → APPLY → DOCS`

### Critical Rules

1. 🚫 No new files without exhaustive reuse analysis
2. 🚫 No applying changes without user approval
3. 🚫 No documentation until code approved
4. 🚫 No fake/mock data in production
5. ✅ Always cite `file:line` for code, `file.md#Section` for MB
6. ✅ Always work in sandbox (never main)
7. ✅ Always validate reuse opportunities first
8. ✅ Always check glas.sh patterns before building equivalent components

---

**Mission**: Build a native visionOS database client respecting the glas.sh architectural heritage, following established spatial UI patterns, improving incrementally. Reuse over creation. Quality over speed. Approval over assumption.
