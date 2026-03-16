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
    }
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

    @State private var result: QueryResult?
    @State private var columnMeta: [ColumnInfo] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedRowIndex: Int?
    @State private var showEditor = false

    private let rowNumWidth: CGFloat = 50
    private let rowHeight: CGFloat = 30

    private var session: DatabaseSession? {
        sessionManager.session(for: sessionID)
    }

    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                ProgressView("Loading data...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = errorMessage {
                ContentUnavailableView(
                    "Error",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error)
                )
            } else if let result {
                dataGrid(result)
            } else {
                ContentUnavailableView(
                    "No Data",
                    systemImage: "tablecells",
                    description: Text("Loading table data...")
                )
            }
        }
        .sheet(isPresented: $showEditor) {
            if let result, let rowIdx = selectedRowIndex, rowIdx < result.rows.count {
                RecordEditorView(
                    columns: columnMeta.isEmpty ? result.columns : columnMeta,
                    rowIndex: rowIdx,
                    originalRow: result.rows[rowIdx],
                    onApply: { edits in
                        Task { await applyEdits(edits, rowIndex: rowIdx) }
                    },
                    onDiscard: {
                        showEditor = false
                    }
                )
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    Task { await loadData() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                if let result {
                    Button {
                        openWindow(id: "results", value: result.id)
                    } label: {
                        Label("Detach", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
        }
        .task(id: "\(database).\(table)") {
            await loadData()
        }
    }

    // MARK: - Data Grid

    private func dataGrid(_ result: QueryResult) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("\(result.rowCount) rows")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("in \(String(format: "%.3f", result.executionTime))s")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            GeometryReader { geometry in
                let widths = columnWidths(columns: result.columns, rows: result.rows)
                let totalDataWidth = widths.reduce(0, +)
                let availableForData = geometry.size.width - rowNumWidth
                let fillerWidth = max(0, availableForData - totalDataWidth)
                let dataHeight = CGFloat(result.rows.count) * rowHeight
                let headerHeight: CGFloat = 36
                let fillerRowCount = max(0, Int((geometry.size.height - headerHeight - dataHeight) / rowHeight))

                HStack(alignment: .top, spacing: 0) {
                    // Frozen row number column
                    VStack(spacing: 0) {
                        // Row number header
                        Text("#")
                            .font(.caption.bold())
                            .frame(width: rowNumWidth, height: headerHeight, alignment: .center)
                            .background(.ultraThinMaterial)

                        // Row numbers
                        ScrollView(.vertical, showsIndicators: false) {
                            LazyVStack(spacing: 0) {
                                ForEach(0..<result.rows.count, id: \.self) { rowIndex in
                                    Text("\(rowIndex + 1)")
                                        .font(.system(.caption2, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                        .frame(width: rowNumWidth, height: rowHeight, alignment: .center)
                                        .background(rowBackground(rowIndex: rowIndex, totalDataRows: result.rows.count))
                                        .onTapGesture { selectRow(rowIndex) }
                                }
                                // Filler row numbers
                                ForEach(0..<fillerRowCount, id: \.self) { fillerIndex in
                                    let globalIndex = result.rows.count + fillerIndex
                                    Color.clear
                                        .frame(width: rowNumWidth, height: rowHeight)
                                        .background(globalIndex.isMultiple(of: 2) ? Color.clear : Color.primary.opacity(0.02))
                                }
                            }
                        }
                    }
                    .frame(width: rowNumWidth)

                    Divider()

                    // Scrollable data columns
                    ScrollView([.horizontal, .vertical]) {
                        LazyVStack(alignment: .leading, spacing: 0, pinnedViews: .sectionHeaders) {
                            Section {
                                ForEach(Array(result.rows.enumerated()), id: \.offset) { rowIndex, row in
                                    HStack(spacing: 0) {
                                        ForEach(Array(row.enumerated()), id: \.offset) { colIndex, value in
                                            Text(value.displayString)
                                                .font(.system(.caption, design: .monospaced))
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
                                    ForEach(Array(result.columns.enumerated()), id: \.offset) { colIndex, col in
                                        Text(col.name)
                                            .font(.caption.bold())
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
        columns.enumerated().map { colIndex, col in
            let headerLen = CGFloat(col.name.count)
            var maxDataLen: CGFloat = 0
            for row in rows.prefix(50) {
                if colIndex < row.count {
                    maxDataLen = max(maxDataLen, CGFloat(row[colIndex].displayString.count))
                }
            }
            let charWidth: CGFloat = 8.5
            let padding: CGFloat = 24
            let computed = max(headerLen, maxDataLen) * charWidth + padding
            return max(80, min(computed, 400))
        }
    }

    // MARK: - Data Loading

    private func loadData() async {
        guard let connection = session?.connection else { return }
        isLoading = true
        errorMessage = nil
        selectedRowIndex = nil
        showEditor = false
        let limit = settingsManager.resultRowLimit
        let sql = "SELECT * FROM `\(database)`.`\(table)` LIMIT \(limit)"
        do {
            // Load column metadata (has PK info) alongside data
            async let metaTask = connection.columns(in: table, database: database)
            async let dataTask = sessionManager.executeQuery(sql, sessionID: sessionID)
            columnMeta = try await metaTask
            result = try await dataTask
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
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
}

// MARK: - Structure Tab

struct StructureTabView: View {
    let sessionID: UUID
    let database: String
    let table: String

    @Environment(DatabaseSessionManager.self) private var sessionManager
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
            .font(.caption.bold())
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(minWidth: 100, alignment: .leading)
            .background(.ultraThinMaterial)
            .accessibilityAddTraits(.isHeader)
    }

    private func dataCell(_ text: String, monospaced: Bool = false) -> some View {
        Text(text)
            .font(monospaced ? .system(.caption, design: .monospaced) : .caption)
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
            .font(.caption.bold())
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(minWidth: 100, alignment: .leading)
            .background(.ultraThinMaterial)
            .accessibilityAddTraits(.isHeader)
    }

    private func dataCell(_ text: String, monospaced: Bool = false) -> some View {
        Text(text)
            .font(monospaced ? .system(.caption, design: .monospaced) : .caption)
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
