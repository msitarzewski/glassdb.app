//
//  TableDetailView.swift
//  glassdb
//
//  Context-sensitive detail surface for a selected table.
//  TabView with Data, Structure, DDL, Indexes, Foreign Keys tabs.
//

import SwiftUI
import GlassDBKit

struct TableDetailView: View {
    let sessionID: UUID
    let database: String
    let table: String

    @Environment(DatabaseSessionManager.self) private var sessionManager
    @Environment(SettingsManager.self) private var settingsManager
    @Environment(\.openWindow) private var openWindow

    @State private var selectedTab: TableTab = .data

    private var session: DatabaseSession? {
        sessionManager.session(for: sessionID)
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Data", systemImage: "tablecells", value: .data) {
                DataTabView(sessionID: sessionID, database: database, table: table)
            }
            Tab("Structure", systemImage: "list.bullet.rectangle", value: .structure) {
                StructureTabView(sessionID: sessionID, database: database, table: table)
            }
            Tab("DDL", systemImage: "curlybraces", value: .ddl) {
                DDLTabView(sessionID: sessionID, database: database, table: table)
            }
            Tab("Indexes", systemImage: "arrow.triangle.branch", value: .indexes) {
                IndexesTabView(sessionID: sessionID, database: database, table: table)
            }
            Tab("Foreign Keys", systemImage: "arrow.triangle.turn.up.right.diamond", value: .foreignKeys) {
                ForeignKeysTabView(sessionID: sessionID, database: database, table: table)
            }
        }
        .navigationTitle("\(database) · \(table)")
        .toolbar {
            ToolbarItemGroup(placement: .bottomOrnament) {
                if selectedTab == .data {
                    Button {
                        NotificationCenter.default.post(name: .glassdbAddRow, object: nil)
                    } label: {
                        Label("Add Row", systemImage: "plus")
                    }
                    Button {
                        NotificationCenter.default.post(name: .glassdbRefreshData, object: nil)
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                }
            }
        }
    }
}

extension Notification.Name {
    static let glassdbExecuteQuery = Notification.Name("glassdbExecuteQuery")
    static let glassdbAddRow = Notification.Name("glassdbAddRow")
    static let glassdbRefreshData = Notification.Name("glassdbRefreshData")
}

// MARK: - Tab Enum

enum TableTab: Hashable {
    case data, structure, ddl, indexes, foreignKeys
}

// MARK: - Data Tab

struct DataTabView: View {
    let sessionID: UUID
    let database: String
    let table: String

    @Environment(DatabaseSessionManager.self) private var sessionManager
    @Environment(SettingsManager.self) private var settingsManager
    @Environment(\.openWindow) private var openWindow

    @State private var queryText = ""
    @State private var result: QueryResult?
    @State private var columnMeta: [ColumnInfo] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedRowIndex: Int?
    @State private var showEditor = false
    @State private var addingNewRow = false
    @State private var editorHeight: CGFloat = 120
    @State private var isAutoQuery = true
    @State private var showAIAssistant = false

    // Pager
    @State private var currentPage: Int = 1
    @State private var pageSize: Int = 100
    @State private var totalRowCount: Int?

    // Auto-repeat
    @State private var autoRepeatInterval: TimeInterval = 10
    @State private var autoRepeatTask: Task<Void, Never>?
    @State private var isAutoRepeating = false

    private let rowNumWidth: CGFloat = 50
    private let rowHeight: CGFloat = 30
    private let minEditorHeight: CGFloat = 60
    private let maxEditorHeight: CGFloat = 400

    private var session: DatabaseSession? {
        sessionManager.session(for: sessionID)
    }

    private var totalPages: Int {
        guard let total = totalRowCount, pageSize > 0 else { return 1 }
        return max(1, Int(ceil(Double(total) / Double(pageSize))))
    }

    var body: some View {
        VStack(spacing: 0) {
            // SQL editor header: play button + AI + repeat indicator
            HStack(spacing: 8) {
                Button {
                    Task { await executeCurrentQuery() }
                } label: {
                    Image(systemName: "play.fill")
                }
                .keyboardShortcut(.return, modifiers: .command)
                .contextMenu {
                    Button("Run every \(Int(autoRepeatInterval))s") {
                        startAutoRepeat()
                    }
                    Menu("Interval") {
                        ForEach([5, 10, 30, 60], id: \.self) { seconds in
                            Button("\(seconds)s") { autoRepeatInterval = TimeInterval(seconds) }
                        }
                    }
                    if isAutoRepeating {
                        Divider()
                        Button("Stop Repeating", role: .destructive) {
                            stopAutoRepeat()
                        }
                    }
                }

                if isAutoRepeating {
                    Label("Repeating \(Int(autoRepeatInterval))s", systemImage: "repeat")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }

                Spacer()

                #if canImport(FoundationModels)
                Button {
                    showAIAssistant = true
                } label: {
                    Image(systemName: "sparkles")
                }
                #endif
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            // SQL editor area with dark background
            HighlightedTextEditor(
                text: $queryText,
                fontSize: CGFloat(settingsManager.editorFontSize)
            )
            .frame(height: editorHeight)
            .background(Color.black.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 12)
            .onChange(of: queryText) {
                // User edited the query — disable auto-query sync
                isAutoQuery = false
            }

            // Drag handle to resize
            HStack {
                Spacer()
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.secondary.opacity(0.4))
                    .frame(width: 40, height: 4)
                Spacer()
            }
            .frame(height: 12)
            .contentShape(Rectangle())
            .highPriorityGesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        editorHeight = min(maxEditorHeight, max(minEditorHeight,
                            editorHeight + value.translation.height))
                    }
            )

            // Results area (bottom)
            if isLoading {
                ProgressView("Executing...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = errorMessage {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title)
                        .foregroundStyle(.red)
                    Text(error)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else if let result {
                dataGrid(result)
            } else {
                ContentUnavailableView(
                    "No Results",
                    systemImage: "tablecells",
                    description: Text("Edit the query above and press Execute.")
                )
            }

            // Pager bar at bottom
            if let result {
                Divider()
                HStack(spacing: 12) {
                    Text("\(result.rowCount) rows")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("in \(String(format: "%.3f", result.executionTime))s")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Divider().frame(height: 16)

                    Button {
                        currentPage = max(1, currentPage - 1)
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .disabled(currentPage <= 1)

                    Text("Page \(currentPage) of \(totalPages)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button {
                        currentPage = min(totalPages, currentPage + 1)
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                    .disabled(currentPage >= totalPages)

                    if let total = totalRowCount {
                        Text("(\(total.formatted()) total)")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }

                    Spacer()

                    Text("Per page:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("", value: $pageSize, format: .number)
                        .frame(width: 60)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption)
                        .onSubmit {
                            currentPage = 1
                            Task { await executeCurrentQuery() }
                        }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
            }
        }
        .sheet(isPresented: $showEditor) {
            if let result, let rowIdx = selectedRowIndex, rowIdx < result.rows.count {
                RecordEditorView(
                    columns: columnMeta.isEmpty ? result.columns : columnMeta,
                    mode: .edit(rowIndex: rowIdx, originalRow: result.rows[rowIdx]),
                    onSave: { edits, mode in
                        Task { await applyEdits(edits, rowIndex: rowIdx) }
                    },
                    onDiscard: { showEditor = false }
                )
            }
        }
        .sheet(isPresented: $addingNewRow) {
            RecordEditorView(
                columns: columnMeta,
                mode: .add,
                onSave: { edits, _ in
                    Task { await insertRow(edits) }
                },
                onDiscard: { addingNewRow = false }
            )
        }
        #if canImport(FoundationModels)
        .sheet(isPresented: $showAIAssistant) {
            AIAssistantView(
                aiAssistant: AIAssistant(),
                schemaContext: SchemaContext(
                    databaseName: database,
                    tables: columnMeta.isEmpty ? [] : [
                        SchemaContext.TableInfo(
                            name: table,
                            columns: columnMeta.map { SchemaContext.ColumnInfo(name: $0.name, type: $0.type) }
                        )
                    ]
                ),
                onRunQuery: { sql in
                    queryText = sql
                    showAIAssistant = false
                    Task { await executeCurrentQuery() }
                }
            )
        }
        #endif
        .onReceive(NotificationCenter.default.publisher(for: .glassdbExecuteQuery)) { _ in
            Task { await executeCurrentQuery() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .glassdbAddRow)) { _ in
            addingNewRow = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .glassdbRefreshData)) { _ in
            queryText = ""
            Task { await loadData() }
        }
        .onChange(of: currentPage) {
            if isAutoQuery {
                queryText = generateAutoQuery()
            }
            Task { await executeCurrentQuery() }
        }
        .onChange(of: pageSize) {
            if isAutoQuery {
                currentPage = 1
                queryText = generateAutoQuery()
                Task { await executeCurrentQuery() }
            }
        }
        .task(id: "\(database).\(table)") {
            await loadData()
        }
    }

    // MARK: - Data Grid

    private func dataGrid(_ result: QueryResult) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            GeometryReader { geometry in
                let fontSize = settingsManager.dataGridFontSize
                let widths = columnWidths(columns: result.columns, rows: result.rows)
                let totalDataWidth = rowNumWidth + widths.reduce(0, +)
                let fillerWidth = max(0, geometry.size.width - totalDataWidth)
                let dataHeight = CGFloat(result.rows.count) * rowHeight
                let headerHeight: CGFloat = 36
                let fillerRowCount = max(0, Int((geometry.size.height - headerHeight - dataHeight) / rowHeight))

                ScrollView([.horizontal, .vertical]) {
                    LazyVStack(alignment: .leading, spacing: 0, pinnedViews: .sectionHeaders) {
                        Section {
                            // Data rows with inline row numbers
                            ForEach(Array(result.rows.enumerated()), id: \.offset) { rowIndex, row in
                                HStack(spacing: 0) {
                                    // Row number (inline, scrolls with data)
                                    Text("\((currentPage - 1) * pageSize + rowIndex + 1)")
                                        .font(.system(size: fontSize - 1, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                        .frame(width: rowNumWidth, height: rowHeight, alignment: .center)

                                    // Data cells
                                    ForEach(Array(row.enumerated()), id: \.offset) { colIndex, value in
                                        Text(value.displayString)
                                            .font(.system(size: fontSize, design: .monospaced))
                                            .lineLimit(1)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .frame(width: widths[colIndex], height: rowHeight, alignment: .leading)
                                            .foregroundStyle(value.isNull ? .tertiary : .primary)
                                            .accessibilityLabel("\(result.columns[colIndex].name): \(value.isNull ? "null" : value.displayString)")
                                    }
                                    if fillerWidth > 0 {
                                        Color.clear.frame(width: fillerWidth, height: rowHeight)
                                    }
                                }
                                .background(rowBackground(rowIndex: rowIndex, totalDataRows: result.rows.count))
                                .onTapGesture { selectRow(rowIndex) }
                            }
                            // Filler rows
                            ForEach(0..<fillerRowCount, id: \.self) { fillerIndex in
                                let globalIndex = result.rows.count + fillerIndex
                                HStack(spacing: 0) {
                                    Color.clear.frame(width: rowNumWidth, height: rowHeight)
                                    ForEach(Array(widths.enumerated()), id: \.offset) { _, w in
                                        Color.clear.frame(width: w, height: rowHeight)
                                    }
                                    if fillerWidth > 0 {
                                        Color.clear.frame(width: fillerWidth, height: rowHeight)
                                    }
                                }
                                .background(globalIndex.isMultiple(of: 2) ? Color.clear : Color.primary.opacity(0.02))
                            }
                        } header: {
                            HStack(spacing: 0) {
                                Text("#")
                                    .font(.system(size: fontSize, weight: .bold, design: .monospaced))
                                    .frame(width: rowNumWidth, alignment: .center)

                                ForEach(Array(result.columns.enumerated()), id: \.offset) { colIndex, col in
                                    Text(col.name)
                                        .font(.system(size: fontSize, weight: .bold, design: .monospaced))
                                        .lineLimit(1)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .frame(width: widths[colIndex], alignment: .leading)
                                        .accessibilityAddTraits(.isHeader)
                                }
                                if fillerWidth > 0 {
                                    Spacer().frame(width: fillerWidth)
                                }
                            }
                            .frame(height: headerHeight)
                            .background(.ultraThinMaterial)
                        }
                    }
                }
                .scrollIndicators(.visible)
                .scrollInputBehavior(.enabled, for: .look)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func rowBackground(rowIndex: Int, totalDataRows: Int) -> some ShapeStyle {
        if rowIndex == selectedRowIndex {
            return AnyShapeStyle(Color.accentColor.opacity(0.15))
        }
        return AnyShapeStyle(rowIndex.isMultiple(of: 2) ? Color.clear : Color.primary.opacity(0.02))
    }

    private func selectRow(_ rowIndex: Int) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if selectedRowIndex == rowIndex {
                showEditor.toggle()
            } else {
                selectedRowIndex = rowIndex
                showEditor = true
            }
        }
    }

    // MARK: - Column Widths

    private func columnWidths(columns: [ColumnInfo], rows: [[DatabaseValue]]) -> [CGFloat] {
        let charWidth = settingsManager.dataGridFontSize * 0.65
        return columns.enumerated().map { colIndex, col in
            let headerLen = CGFloat(col.name.count)
            var maxDataLen: CGFloat = 0
            for row in rows.prefix(50) {
                if colIndex < row.count {
                    maxDataLen = max(maxDataLen, CGFloat(row[colIndex].displayString.count))
                }
            }
            let computed = max(headerLen, maxDataLen) * charWidth + 24
            return max(80, min(computed, 400))
        }
    }

    // MARK: - Data Loading

    private func generateAutoQuery() -> String {
        let offset = (currentPage - 1) * pageSize
        return "SELECT * FROM `\(database)`.`\(table)` LIMIT \(pageSize) OFFSET \(offset)"
    }

    private func loadData() async {
        guard let connection = session?.connection else { return }
        isAutoQuery = true
        queryText = generateAutoQuery()
        isLoading = true
        errorMessage = nil
        selectedRowIndex = nil
        showEditor = false
        do {
            async let metaTask = connection.columns(in: table, database: database)
            async let dataTask = sessionManager.executeQuery(queryText, sessionID: sessionID)
            async let countTask = connection.rowCount(table: table, database: database)
            columnMeta = try await metaTask
            result = try await dataTask
            totalRowCount = try? await countTask
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func executeCurrentQuery() async {
        let sql = queryText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sql.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        selectedRowIndex = nil
        showEditor = false
        do {
            // Split on semicolons for multi-query support
            let statements = sql.split(separator: ";")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            var lastResult: QueryResult?
            for statement in statements {
                lastResult = try await sessionManager.executeQuery(statement, sessionID: sessionID)
            }
            result = lastResult
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Auto-Repeat

    private func startAutoRepeat() {
        stopAutoRepeat()
        isAutoRepeating = true
        autoRepeatTask = Task {
            while !Task.isCancelled {
                await executeCurrentQuery()
                try? await Task.sleep(for: .seconds(autoRepeatInterval))
            }
        }
    }

    private func stopAutoRepeat() {
        autoRepeatTask?.cancel()
        autoRepeatTask = nil
        isAutoRepeating = false
    }

    // MARK: - Apply Edits

    private func applyEdits(_ edits: [StagedEdit], rowIndex: Int) async {
        guard let result else { return }

        // Use columnMeta for PK info (query result columns don't have it)
        let cols = columnMeta.isEmpty ? result.columns : columnMeta
        let pkColumns = cols.filter(\.isPrimaryKey)
        guard !pkColumns.isEmpty else {
            errorMessage = "Cannot update: table has no primary key"
            return
        }

        let setClauses = edits.map { edit -> String in
            let col = "`\(cols[edit.columnIndex].name)`"
            if edit.newValue.isNull {
                return "\(col) = NULL"
            }
            let escaped = edit.newValue.displayString
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "'", with: "''")
            return "\(col) = '\(escaped)'"
        }.joined(separator: ", ")

        let whereClauses = pkColumns.map { pk -> String in
            let colIndex = cols.firstIndex(where: { $0.name == pk.name }) ?? 0
            let value = result.rows[rowIndex][colIndex]
            if value.isNull { return "`\(pk.name)` IS NULL" }
            let escaped = value.displayString
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "'", with: "''")
            return "`\(pk.name)` = '\(escaped)'"
        }.joined(separator: " AND ")

        let sql = "UPDATE `\(database)`.`\(table)` SET \(setClauses) WHERE \(whereClauses) LIMIT 1"

        do {
            _ = try await sessionManager.executeQuery(sql, sessionID: sessionID)
            withAnimation { showEditor = false }
            await loadData()
        } catch {
            errorMessage = "Update failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Insert Row

    private func insertRow(_ edits: [StagedEdit]) async {
        let cols = columnMeta
        guard !cols.isEmpty else {
            errorMessage = "Cannot insert: no column metadata"
            return
        }

        let nonNullEdits = edits.filter { !$0.isNull }
        guard !nonNullEdits.isEmpty else {
            errorMessage = "Cannot insert: all values are NULL"
            return
        }

        let columnNames = nonNullEdits.map { "`\(cols[$0.columnIndex].name)`" }.joined(separator: ", ")
        let values = nonNullEdits.map { edit -> String in
            let escaped = edit.editText
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "'", with: "''")
            return "'\(escaped)'"
        }.joined(separator: ", ")

        let sql = "INSERT INTO `\(database)`.`\(table)` (\(columnNames)) VALUES (\(values))"

        do {
            _ = try await sessionManager.executeQuery(sql, sessionID: sessionID)
            addingNewRow = false
            await loadData()
        } catch {
            errorMessage = "Insert failed: \(error.localizedDescription)"
        }
    }
}

// MARK: - Structure Tab

struct StructureTabView: View {
    let sessionID: UUID
    let database: String
    let table: String

    @Environment(DatabaseSessionManager.self) private var sessionManager
    @Environment(SettingsManager.self) private var settingsManager
    @State private var columns: [ColumnInfo] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var session: DatabaseSession? {
        sessionManager.session(for: sessionID)
    }

    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                ProgressView("Loading structure...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = errorMessage {
                ContentUnavailableView("Error", systemImage: "exclamationmark.triangle", description: Text(error))
            } else if columns.isEmpty {
                ContentUnavailableView("No Columns", systemImage: "list.bullet.rectangle", description: Text("Table has no columns."))
            } else {
                ScrollView(.vertical) {
                    LazyVStack(alignment: .leading, spacing: 0, pinnedViews: .sectionHeaders) {
                        Section {
                            ForEach(columns) { col in
                                HStack(spacing: 0) {
                                    dataCell(col.name, monospaced: true)
                                    dataCell(col.type)
                                    dataCell(col.isNullable ? "YES" : "NO")
                                    dataCell(col.isPrimaryKey ? "PRI" : "")
                                    dataCell("\(col.ordinalPosition)")
                                    Spacer(minLength: 0)
                                }
                            }
                        } header: {
                            HStack(spacing: 0) {
                                headerCell("Name")
                                headerCell("Type")
                                headerCell("Nullable")
                                headerCell("Key")
                                headerCell("Position")
                                Spacer(minLength: 0)
                            }
                            .background(.ultraThinMaterial)
                        }
                    }
                    .padding(16)
                }
                .scrollIndicators(.visible)
                .scrollInputBehavior(.enabled, for: .look)
            }
        }
        .task(id: "\(database).\(table)") {
            await loadStructure()
        }
    }

    private func headerCell(_ text: String) -> some View {
        Text(text)
            .font(.system(size: settingsManager.dataGridFontSize, weight: .bold, design: .monospaced))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(minWidth: 100, alignment: .leading)
            .background(.ultraThinMaterial)
            .accessibilityAddTraits(.isHeader)
    }

    private func dataCell(_ text: String, monospaced: Bool = false) -> some View {
        Text(text)
            .font(.system(size: settingsManager.dataGridFontSize, design: monospaced ? .monospaced : .default))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .frame(minWidth: 100, alignment: .leading)
    }

    private func loadStructure() async {
        guard let connection = session?.connection else { return }
        isLoading = true
        errorMessage = nil
        do {
            columns = try await connection.columns(in: table, database: database)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - DDL Tab

struct DDLTabView: View {
    let sessionID: UUID
    let database: String
    let table: String

    @Environment(DatabaseSessionManager.self) private var sessionManager
    @State private var ddl: String?
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var session: DatabaseSession? {
        sessionManager.session(for: sessionID)
    }

    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                ProgressView("Loading DDL...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = errorMessage {
                ContentUnavailableView("Error", systemImage: "exclamationmark.triangle", description: Text(error))
            } else if let ddl {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Spacer()
                        Button {
                            UIPasteboard.general.string = ddl
                        } label: {
                            Label("Copy", systemImage: "doc.on.doc")
                                .font(.caption)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)

                    ScrollView {
                        Text(AttributedString(SQLHighlighter.highlight(ddl)))
                            .textSelection(.enabled)
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .scrollInputBehavior(.enabled, for: .look)
                }
            }
        }
        .task(id: "\(database).\(table)") {
            await loadDDL()
        }
    }

    private func loadDDL() async {
        guard let connection = session?.connection else { return }
        isLoading = true
        errorMessage = nil
        do {
            ddl = try await connection.showCreateTable(table, database: database)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Indexes Tab

struct IndexesTabView: View {
    let sessionID: UUID
    let database: String
    let table: String

    @Environment(DatabaseSessionManager.self) private var sessionManager
    @Environment(SettingsManager.self) private var settingsManager
    @State private var indexes: [IndexInfo] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var session: DatabaseSession? {
        sessionManager.session(for: sessionID)
    }

    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                ProgressView("Loading indexes...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = errorMessage {
                ContentUnavailableView("Error", systemImage: "exclamationmark.triangle", description: Text(error))
            } else if indexes.isEmpty {
                ContentUnavailableView("No Indexes", systemImage: "arrow.triangle.branch", description: Text("This table has no indexes."))
            } else {
                ScrollView(.vertical) {
                    LazyVStack(alignment: .leading, spacing: 0, pinnedViews: .sectionHeaders) {
                        Section {
                            ForEach(indexes) { idx in
                                HStack(spacing: 0) {
                                    dataCell(idx.name, monospaced: true)
                                    dataCell(idx.columnName, monospaced: true)
                                    dataCell(idx.isUnique ? "YES" : "NO")
                                    dataCell(idx.type)
                                    dataCell("\(idx.sequenceInIndex)")
                                    Spacer(minLength: 0)
                                }
                            }
                        } header: {
                            HStack(spacing: 0) {
                                headerCell("Name")
                                headerCell("Column")
                                headerCell("Unique")
                                headerCell("Type")
                                headerCell("Seq")
                                Spacer(minLength: 0)
                            }
                            .background(.ultraThinMaterial)
                        }
                    }
                    .padding(16)
                }
                .scrollIndicators(.visible)
                .scrollInputBehavior(.enabled, for: .look)
            }
        }
        .task(id: "\(database).\(table)") {
            await loadIndexes()
        }
    }

    private func headerCell(_ text: String) -> some View {
        Text(text)
            .font(.system(size: settingsManager.dataGridFontSize, weight: .bold, design: .monospaced))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(minWidth: 100, alignment: .leading)
            .background(.ultraThinMaterial)
            .accessibilityAddTraits(.isHeader)
    }

    private func dataCell(_ text: String, monospaced: Bool = false) -> some View {
        Text(text)
            .font(.system(size: settingsManager.dataGridFontSize, design: monospaced ? .monospaced : .default))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .frame(minWidth: 100, alignment: .leading)
    }

    private func loadIndexes() async {
        guard let connection = session?.connection else { return }
        isLoading = true
        errorMessage = nil
        do {
            indexes = try await connection.indexes(in: table, database: database)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Foreign Keys Tab

struct ForeignKeysTabView: View {
    let sessionID: UUID
    let database: String
    let table: String

    @Environment(DatabaseSessionManager.self) private var sessionManager
    @Environment(SettingsManager.self) private var settingsManager
    @State private var foreignKeys: [ForeignKeyInfo] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var session: DatabaseSession? {
        sessionManager.session(for: sessionID)
    }

    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                ProgressView("Loading foreign keys...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = errorMessage {
                ContentUnavailableView("Error", systemImage: "exclamationmark.triangle", description: Text(error))
            } else if foreignKeys.isEmpty {
                ContentUnavailableView("No Foreign Keys", systemImage: "arrow.triangle.turn.up.right.diamond", description: Text("This table has no foreign key constraints."))
            } else {
                ScrollView(.vertical) {
                    LazyVStack(alignment: .leading, spacing: 0, pinnedViews: .sectionHeaders) {
                        Section {
                            ForEach(foreignKeys) { fk in
                                HStack(spacing: 0) {
                                    dataCell(fk.constraintName, monospaced: true)
                                    dataCell(fk.columnName, monospaced: true)
                                    dataCell(fk.referencedTable)
                                    dataCell(fk.referencedColumn, monospaced: true)
                                    Spacer(minLength: 0)
                                }
                            }
                        } header: {
                            HStack(spacing: 0) {
                                headerCell("Constraint")
                                headerCell("Column")
                                headerCell("Referenced Table")
                                headerCell("Referenced Column")
                                Spacer(minLength: 0)
                            }
                            .background(.ultraThinMaterial)
                        }
                    }
                    .padding(16)
                }
                .scrollIndicators(.visible)
                .scrollInputBehavior(.enabled, for: .look)
            }
        }
        .task(id: "\(database).\(table)") {
            await loadForeignKeys()
        }
    }

    private func headerCell(_ text: String) -> some View {
        Text(text)
            .font(.caption.bold())
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(minWidth: 120, alignment: .leading)
            .background(.ultraThinMaterial)
            .accessibilityAddTraits(.isHeader)
    }

    private func dataCell(_ text: String, monospaced: Bool = false) -> some View {
        Text(text)
            .font(monospaced ? .system(.caption, design: .monospaced) : .caption)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .frame(minWidth: 120, alignment: .leading)
    }

    private func loadForeignKeys() async {
        guard let connection = session?.connection else { return }
        isLoading = true
        errorMessage = nil
        do {
            foreignKeys = try await connection.foreignKeys(in: table, database: database)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
