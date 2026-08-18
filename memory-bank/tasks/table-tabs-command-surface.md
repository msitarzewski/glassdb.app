# Table Tabs Join the Menu Command Surface

**Status:** To do — filed 2026-08-14 during M3 Phase 2 review
**Scope:** Query-menu commands (Format ⌘⇧F, Execute, History, Saved Queries) are enabled only on SQL-document tabs; table tabs never register into the workspace's per-document command-handler system, so the menu items stay disabled there.

## Background

The workspace consults `editorCommandHandlers[activeDocumentID]` (registration keyed by document UUID, populated by `QueryEditorView`). Table tabs have no document identity, predating the editor swap. The M3 Phase 2 slice added a visible Format button to the control bar (selection-aware) as the interim affordance.

## Direction

Give table-tab editors a registration path — either synthesize a stable per-table handler identity or generalize the active-tab consultation in `DatabaseWorkspaceView` — so ⌘⇧F/Execute/History work identically on both surfaces. Reuse the existing handler bundle type; no new menu items.
