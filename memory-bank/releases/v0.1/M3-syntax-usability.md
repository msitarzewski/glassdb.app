# M3: Syntax & Usability

**Status**: Done (2026-03-15)
**Depends on**: M2 (glass polish)
**Prerequisite for**: M4

## Goal
The query editor feels like a real SQL tool — syntax highlighting, keyboard shortcuts, and solid error handling.

## Tasks

### SQL Syntax Highlighting
- [x] SQLHighlighter.swift — full tokenizer for MySQL keywords, functions, strings, numbers, comments, identifiers
- [x] HighlightedTextEditor.swift — UIViewRepresentable wrapping UITextView with syntax highlighting
- [x] NSAttributedString output with per-token colors (keywords blue/bold, functions purple, strings green, numbers orange, comments gray)
- [x] Basic linter (unterminated strings/identifiers shown as red underline)
- [x] Applied to QueryEditorView text editor
- [x] DDL tab shows syntax-highlighted CREATE TABLE

### Keyboard Shortcuts
- [x] Cmd+Return → Execute query

### Error UX
- [x] Query errors displayed inline below editor (not alert dialogs)
- [x] Connection failure messages in ConnectionManagerView

### Not Completed (deferred)
- [ ] Query history persistence (v0.1 stretch)
- [ ] SQL autocomplete (v0.1 stretch)
- [ ] Multiple query tabs (v1.1)

## Key Files
- `glassdb/SQLHighlighter.swift`
- `glassdb/HighlightedTextEditor.swift`
- `glassdb/QueryEditorView.swift`
