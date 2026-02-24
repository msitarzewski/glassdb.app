# M3: Syntax & Usability

**Status**: Not Started
**Depends on**: M2 (glass polish)
**Prerequisite for**: M4

## Goal
The query editor feels like a real SQL tool — syntax highlighting, query history, and solid error handling.

## Tasks

### SQL Syntax Highlighting
- [ ] Create `SQLSyntaxEngine/` directory with `SQLLexer.swift`, `SQLHighlighter.swift`
- [ ] MySQL keyword highlighting (SELECT, FROM, WHERE, JOIN, INSERT, UPDATE, DELETE, CREATE, ALTER, DROP, etc.)
- [ ] String literal highlighting (single-quoted)
- [ ] Numeric literal highlighting
- [ ] Comment highlighting (`--` and `/* */`)
- [ ] Identifier highlighting (backtick-quoted)
- [ ] Apply highlighting to QueryEditorView text editor

### Query History
- [ ] Persist executed queries (SQL text, timestamp, execution time, row count, error)
- [ ] QueryHistoryView — searchable list of past queries
- [ ] Tap history entry to load into editor
- [ ] Per-connection history filtering

### Error UX
- [ ] Query errors displayed inline below editor (not alert dialogs)
- [ ] Connection failure messages with actionable context (wrong password, host unreachable, etc.)
- [ ] Timeout handling with cancel option
- [ ] Network drop detection and reconnect prompt

### Keyboard Shortcuts
- [ ] Cmd+Enter → Execute query
- [ ] Cmd+N → New query tab (if multi-tab implemented)
- [ ] Cmd+W → Close current window
- [ ] Cmd+, → Settings

## Key Files (to create)
- `glassdb/SQLSyntaxEngine/SQLLexer.swift`
- `glassdb/SQLSyntaxEngine/SQLHighlighter.swift`
- `glassdb/QueryHistoryView.swift`
