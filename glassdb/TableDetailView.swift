//
//  TableDetailView.swift
//  glassdb
//
//  Context-sensitive detail surface for a selected table.
//  TabView with Data, Structure, DDL, Indexes, Foreign Keys tabs.
//

import SwiftUI
import UniformTypeIdentifiers
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
            ToolbarItemGroup(placement: .primaryAction) {
                if selectedTab == .data {
                    #if canImport(FoundationModels)
                    Button {
                        NotificationCenter.default.post(name: .glassdbShowAI, object: nil)
                    } label: {
                        Image(systemName: "sparkles")
                    }
                    #endif

                    Button {
                        NotificationCenter.default.post(name: .glassdbExecuteQuery, object: nil)
                    } label: {
                        Image(systemName: "play.fill")
                    }
                    .keyboardShortcut(.return, modifiers: .command)
                    .contextMenu {
                        Button("Run every 10s") {
                            NotificationCenter.default.post(name: .glassdbStartRepeat, object: nil)
                        }
                    }
                }
            }
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
                    Menu {
                        ForEach(GridExportFormat.allCases) { format in
                            Button(format.displayName) {
                                NotificationCenter.default.post(
                                    name: .glassdbExport,
                                    object: format.rawValue
                                )
                            }
                        }
                    } label: {
                        Label("Export", systemImage: "square.and.arrow.up")
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
    static let glassdbShowAI = Notification.Name("glassdbShowAI")
    static let glassdbStartRepeat = Notification.Name("glassdbStartRepeat")
    static let glassdbExport = Notification.Name("glassdbExport")
}

// MARK: - Tab Enum

enum TableTab: Hashable {
    case data, structure, ddl, indexes, foreignKeys
}

enum GridSortDirection: String, Codable, Sendable {
    case ascending
    case descending

    var sql: String { self == .ascending ? "ASC" : "DESC" }
}

struct GridSortDescriptor: Codable, Hashable, Identifiable, Sendable {
    let columnName: String
    var direction: GridSortDirection
    var id: String { columnName }
}

enum GridFilterOperator: String, CaseIterable, Codable, Identifiable, Sendable {
    case equals
    case notEquals
    case greaterThan
    case lessThan
    case isNull
    case isNotNull

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .equals: return "Equals"
        case .notEquals: return "Does Not Equal"
        case .greaterThan: return "Greater Than"
        case .lessThan: return "Less Than"
        case .isNull: return "Is NULL"
        case .isNotNull: return "Is Not NULL"
        }
    }
    var requiresValue: Bool { self != .isNull && self != .isNotNull }
}

struct GridColumnFilter: Codable, Hashable, Identifiable, Sendable {
    let columnName: String
    let columnType: String
    let isUnsigned: Bool
    var operation: GridFilterOperator
    var value: String
    var id: String { columnName }

    init(
        columnName: String,
        columnType: String,
        isUnsigned: Bool = false,
        operation: GridFilterOperator,
        value: String
    ) {
        self.columnName = columnName
        self.columnType = columnType
        self.isUnsigned = isUnsigned
        self.operation = operation
        self.value = value
    }

    func boundValue() throws -> DatabaseValue? {
        guard operation.requiresValue else { return nil }
        return try StagedEdit(
            columnIndex: 0,
            columnName: columnName,
            columnType: columnType,
            isPrimaryKey: false,
            isNullable: true,
            isUnsigned: isUnsigned,
            isGenerated: false,
            defaultValue: nil,
            originalValue: .null,
            editText: value,
            isNull: false,
            useDefault: false
        ).boundValue()
    }
}

struct GridServerQuery: Equatable, Sendable {
    let sql: String
    let parameters: [DatabaseValue]
}

enum GridAggregateFunction: String, CaseIterable, Codable, Identifiable, Sendable {
    case countAll
    case count
    case sum
    case average
    case minimum
    case maximum

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .countAll: return "Count All"
        case .count: return "Count"
        case .sum: return "Sum"
        case .average: return "Average"
        case .minimum: return "Minimum"
        case .maximum: return "Maximum"
        }
    }
    var sqlName: String {
        switch self {
        case .countAll, .count: return "COUNT"
        case .sum: return "SUM"
        case .average: return "AVG"
        case .minimum: return "MIN"
        case .maximum: return "MAX"
        }
    }
    var requiresColumn: Bool { self != .countAll }
}

struct GridAggregateDescriptor: Codable, Hashable, Identifiable, Sendable {
    let function: GridAggregateFunction
    let columnName: String?
    var id: String { "\(function.rawValue):\(columnName ?? "*")" }
}

struct GridQueryState: Codable, Equatable, Sendable {
    var filters: [GridColumnFilter] = []
    var sorts: [GridSortDescriptor] = []
    var groupColumns: [String] = []
    var aggregates: [GridAggregateDescriptor] = []
    var pageSize: Int = 100

    mutating func reconcile(columns: [ColumnInfo]) {
        let valid = Set(columns.map(\.name))
        filters = filters.filter { valid.contains($0.columnName) }
        sorts = sorts.filter { valid.contains($0.columnName) }
        groupColumns = groupColumns.filter(valid.contains)
        aggregates = aggregates.filter { descriptor in
            !descriptor.function.requiresColumn || descriptor.columnName.map(valid.contains) == true
        }
        pageSize = max(1, min(pageSize, 10_000))
    }

    static func storageKey(connectionID: UUID, database: String, table: String) -> String {
        let object = Data("\(database)\u{0}\(table)".utf8).base64EncodedString()
        return "app.glassdb.gridQuery.\(connectionID.uuidString.lowercased()).\(object)"
    }
}

enum GridServerQueryBuilder {
    static func select(
        database: String,
        table: String,
        columns: [ColumnInfo],
        filters: [GridColumnFilter],
        sorts: [GridSortDescriptor],
        page: Int,
        pageSize: Int,
        identifierQuote: Character,
        dialect: DatabaseDialect = .mysql
    ) throws -> GridServerQuery {
        let predicate = try predicate(
            columns: columns,
            filters: filters,
            identifierQuote: identifierQuote,
            dialect: dialect
        )
        let order = try orderClause(columns: columns, sorts: sorts, identifierQuote: identifierQuote)
        let boundedSize = max(1, min(pageSize, 10_000))
        let offset = max(0, page - 1) * boundedSize
        let qualified = "\(quote(database, with: identifierQuote)).\(quote(table, with: identifierQuote))"
        return GridServerQuery(
            sql: "SELECT * FROM \(qualified)\(predicate.sql)\(order) LIMIT \(boundedSize) OFFSET \(offset)",
            parameters: predicate.parameters
        )
    }

    static func count(
        database: String,
        table: String,
        columns: [ColumnInfo],
        filters: [GridColumnFilter],
        identifierQuote: Character,
        dialect: DatabaseDialect = .mysql
    ) throws -> GridServerQuery {
        let predicate = try predicate(
            columns: columns,
            filters: filters,
            identifierQuote: identifierQuote,
            dialect: dialect
        )
        let qualified = "\(quote(database, with: identifierQuote)).\(quote(table, with: identifierQuote))"
        return GridServerQuery(
            sql: "SELECT COUNT(*) FROM \(qualified)\(predicate.sql)",
            parameters: predicate.parameters
        )
    }

    static func aggregate(
        database: String,
        table: String,
        columns: [ColumnInfo],
        filters: [GridColumnFilter],
        groupColumns: [String],
        aggregates: [GridAggregateDescriptor],
        page: Int,
        pageSize: Int,
        identifierQuote: Character,
        dialect: DatabaseDialect = .mysql
    ) throws -> GridServerQuery {
        let selection = try aggregateSelection(
            columns: columns,
            groupColumns: groupColumns,
            aggregates: aggregates,
            identifierQuote: identifierQuote
        )
        let predicate = try predicate(
            columns: columns,
            filters: filters,
            identifierQuote: identifierQuote,
            dialect: dialect
        )
        let boundedSize = max(1, min(pageSize, 10_000))
        let offset = max(0, page - 1) * boundedSize
        let qualified = "\(quote(database, with: identifierQuote)).\(quote(table, with: identifierQuote))"
        let grouping = groupColumns.isEmpty ? "" : " GROUP BY " + groupColumns.map {
            quote($0, with: identifierQuote)
        }.joined(separator: ", ")
        let ordering = groupColumns.isEmpty ? "" : " ORDER BY " + groupColumns.map {
            "\(quote($0, with: identifierQuote)) ASC"
        }.joined(separator: ", ")
        return GridServerQuery(
            sql: "SELECT \(selection) FROM \(qualified)\(predicate.sql)\(grouping)\(ordering) LIMIT \(boundedSize) OFFSET \(offset)",
            parameters: predicate.parameters
        )
    }

    static func aggregateCount(
        database: String,
        table: String,
        columns: [ColumnInfo],
        filters: [GridColumnFilter],
        groupColumns: [String],
        aggregates: [GridAggregateDescriptor],
        identifierQuote: Character,
        dialect: DatabaseDialect = .mysql
    ) throws -> GridServerQuery {
        _ = try aggregateSelection(
            columns: columns,
            groupColumns: groupColumns,
            aggregates: aggregates,
            identifierQuote: identifierQuote
        )
        let predicate = try predicate(
            columns: columns,
            filters: filters,
            identifierQuote: identifierQuote,
            dialect: dialect
        )
        let qualified = "\(quote(database, with: identifierQuote)).\(quote(table, with: identifierQuote))"
        guard !groupColumns.isEmpty else {
            return GridServerQuery(sql: "SELECT 1", parameters: [])
        }
        let grouping = groupColumns.map { quote($0, with: identifierQuote) }.joined(separator: ", ")
        return GridServerQuery(
            sql: "SELECT COUNT(*) FROM (SELECT 1 FROM \(qualified)\(predicate.sql) GROUP BY \(grouping)) AS \(quote("glassdb_group_count", with: identifierQuote))",
            parameters: predicate.parameters
        )
    }

    private static func aggregateSelection(
        columns: [ColumnInfo],
        groupColumns: [String],
        aggregates: [GridAggregateDescriptor],
        identifierQuote: Character
    ) throws -> String {
        let validNames = Set(columns.map(\.name))
        guard !aggregates.isEmpty else {
            throw RecordValueError.invalidValue(column: "Aggregate", expected: "at least one aggregate function")
        }
        guard Set(groupColumns).count == groupColumns.count,
              groupColumns.allSatisfy(validNames.contains) else {
            throw RecordValueError.invalidValue(column: "Group", expected: "unique existing table columns")
        }
        var selections = groupColumns.map { quote($0, with: identifierQuote) }
        for (index, descriptor) in aggregates.enumerated() {
            let argument: String
            if descriptor.function == .countAll {
                guard descriptor.columnName == nil else {
                    throw RecordValueError.invalidValue(column: "Count All", expected: "no column")
                }
                argument = "*"
            } else {
                guard let columnName = descriptor.columnName, validNames.contains(columnName) else {
                    throw RecordValueError.invalidValue(column: descriptor.columnName ?? "Aggregate", expected: "an existing table column")
                }
                if descriptor.function == .sum || descriptor.function == .average,
                   let column = columns.first(where: { $0.name == columnName }),
                   !isNumericType(column.type) {
                    throw RecordValueError.invalidValue(column: columnName, expected: "a numeric column for sum or average")
                }
                argument = quote(columnName, with: identifierQuote)
            }
            let alias = "glassdb_\(index + 1)_\(descriptor.function.rawValue)"
            selections.append("\(descriptor.function.sqlName)(\(argument)) AS \(quote(alias, with: identifierQuote))")
        }
        return selections.joined(separator: ", ")
    }

    private static func isNumericType(_ type: String) -> Bool {
        let base = type.lowercased().split(separator: "(", maxSplits: 1).first.map(String.init) ?? type.lowercased()
        return ["tinyint", "smallint", "mediumint", "int", "integer", "bigint", "decimal", "numeric", "float", "double", "real"].contains(base)
    }

    private static func predicate(
        columns: [ColumnInfo],
        filters: [GridColumnFilter],
        identifierQuote: Character,
        dialect: DatabaseDialect
    ) throws -> (sql: String, parameters: [DatabaseValue]) {
        var clauses: [String] = []
        var parameters: [DatabaseValue] = []
        let validNames = Set(columns.map(\.name))
        for filter in filters {
            guard validNames.contains(filter.columnName) else {
                throw RecordValueError.invalidValue(column: filter.columnName, expected: "an existing table column")
            }
            let identifier = quote(filter.columnName, with: identifierQuote)
            switch filter.operation {
            case .isNull: clauses.append("\(identifier) IS NULL")
            case .isNotNull: clauses.append("\(identifier) IS NOT NULL")
            case .equals, .notEquals, .greaterThan, .lessThan:
                guard let value = try filter.boundValue() else { continue }
                let operation: String
                switch filter.operation {
                case .equals: operation = "="
                case .notEquals: operation = "<>"
                case .greaterThan: operation = ">"
                case .lessThan: operation = "<"
                default: operation = "="
                }
                parameters.append(value)
                clauses.append("\(identifier) \(operation) \(placeholder(parameters.count, dialect: dialect))")
            }
        }
        return (clauses.isEmpty ? "" : " WHERE " + clauses.joined(separator: " AND "), parameters)
    }

    private static func orderClause(
        columns: [ColumnInfo],
        sorts: [GridSortDescriptor],
        identifierQuote: Character
    ) throws -> String {
        guard !sorts.isEmpty else { return "" }
        let validNames = Set(columns.map(\.name))
        guard sorts.allSatisfy({ validNames.contains($0.columnName) }) else {
            throw RecordValueError.invalidValue(column: "Sort", expected: "existing table columns")
        }
        return " ORDER BY " + sorts.map {
            "\(quote($0.columnName, with: identifierQuote)) \($0.direction.sql)"
        }.joined(separator: ", ")
    }

    private static func quote(_ identifier: String, with delimiter: Character) -> String {
        let quote = String(delimiter)
        return quote + identifier.replacingOccurrences(of: quote, with: quote + quote) + quote
    }

    private static func placeholder(_ position: Int, dialect: DatabaseDialect) -> String {
        dialect == .postgresql ? "$\(position)" : "?"
    }
}

struct GridColumnLayout: Codable, Equatable, Sendable {
    var order: [String] = []
    var hidden: Set<String> = []
    var frozen: Set<String> = []
    var widths: [String: Double] = [:]

    mutating func reconcile(columns: [ColumnInfo]) {
        let names = columns.map(\.name)
        let valid = Set(names)
        order = order.filter(valid.contains)
        var orderedNames = Set(order)
        for name in names where orderedNames.insert(name).inserted {
            order.append(name)
        }
        hidden.formIntersection(valid)
        frozen.formIntersection(valid)
        widths = widths.filter { valid.contains($0.key) }
    }

    func visibleColumnIndices(columns: [ColumnInfo]) -> [Int] {
        let indexByName = Dictionary(uniqueKeysWithValues: columns.enumerated().map { ($0.element.name, $0.offset) })
        let visible = order.filter { !hidden.contains($0) }
        return (visible.filter(frozen.contains) + visible.filter { !frozen.contains($0) })
            .compactMap { indexByName[$0] }
    }

    static func storageKey(connectionID: UUID, database: String, table: String) -> String {
        let object = Data("\(database)\u{0}\(table)".utf8).base64EncodedString()
        return "app.glassdb.gridLayout.\(connectionID.uuidString.lowercased()).\(object)"
    }

    static func leadingOffsets(widths: [CGFloat], startingAt initial: CGFloat) -> [CGFloat] {
        var running = initial
        return widths.map { width in
            defer { running += width }
            return running
        }
    }
}

struct GridCellCoordinate: Hashable, Sendable {
    let row: Int
    let column: Int
}

struct GridRowDifference: Equatable, Sendable {
    let columnName: String
    let left: DatabaseValue
    let right: DatabaseValue
}

enum GridRowComparison {
    static func differences(
        result: QueryResult,
        leftRow: Int,
        rightRow: Int,
        columnIndices: [Int]
    ) throws -> [GridRowDifference] {
        guard result.rows.indices.contains(leftRow), result.rows.indices.contains(rightRow), leftRow != rightRow else {
            throw RecordValueError.invalidValue(column: "Compare", expected: "two distinct result rows")
        }
        guard columnIndices.allSatisfy(result.columns.indices.contains) else {
            throw RecordValueError.invalidValue(column: "Compare", expected: "existing result columns")
        }
        return columnIndices.compactMap { index in
            let left = index < result.rows[leftRow].count ? result.rows[leftRow][index] : .null
            let right = index < result.rows[rightRow].count ? result.rows[rightRow][index] : .null
            return left == right ? nil : GridRowDifference(
                columnName: result.columns[index].name,
                left: left,
                right: right
            )
        }
    }
}

enum GridPasteMappingMode: String, Codable, Sendable {
    case positional
    case headerRow
}

enum GridImportPolicy {
    static let maximumBytes = 10 * 1_024 * 1_024

    static func validate(byteCount: Int) throws {
        guard byteCount >= 0, byteCount <= maximumBytes else {
            throw RecordValueError.invalidValue(column: "Import", expected: "UTF-8 TSV data no larger than 10 MB")
        }
    }

    static func validate(text: String) throws {
        try validate(byteCount: text.utf8.count)
    }
}

struct GridBatchRowEdit {
    let rowIndex: Int
    let edits: [StagedEdit]
}

struct GridPastePlan {
    let rows: [GridBatchRowEdit]
    let mappedColumnNames: [String]
    let sourceRowCount: Int
    let mappingMode: GridPasteMappingMode
}

enum GridPastePlanBuilder {
    static func build(
        tsv: String,
        anchor: GridCellCoordinate,
        result: QueryResult,
        columns: [ColumnInfo],
        visibleColumnIndices: [Int],
        mappingMode: GridPasteMappingMode
    ) throws -> GridPastePlan {
        guard result.rows.indices.contains(anchor.row), columns == result.columns || columns.count == result.columns.count else {
            throw RecordValueError.invalidValue(column: "Paste", expected: "a current base-table result row")
        }
        let parsed = parse(tsv)
        guard !parsed.isEmpty else {
            throw RecordValueError.invalidValue(column: "Paste", expected: "at least one data row")
        }

        let mappedIndices: [Int]
        let dataRows: [[String]]
        switch mappingMode {
        case .positional:
            guard let start = visibleColumnIndices.firstIndex(of: anchor.column),
                  let width = parsed.first?.count,
                  width > 0,
                  start + width <= visibleColumnIndices.count else {
                throw RecordValueError.invalidValue(column: "Paste", expected: "a range within the visible columns")
            }
            mappedIndices = Array(visibleColumnIndices[start..<(start + width)])
            dataRows = parsed
        case .headerRow:
            guard parsed.count > 1 else {
                throw RecordValueError.invalidValue(column: "Paste header", expected: "a header plus at least one data row")
            }
            let names = parsed[0].map(decodeTSV)
            guard Set(names).count == names.count else {
                throw RecordValueError.invalidValue(column: "Paste header", expected: "unique column names")
            }
            let indexByName = Dictionary(uniqueKeysWithValues: columns.enumerated().map { ($0.element.name, $0.offset) })
            mappedIndices = try names.map { name in
                guard let index = indexByName[name] else {
                    throw RecordValueError.invalidValue(column: name, expected: "an existing table column")
                }
                return index
            }
            dataRows = Array(parsed.dropFirst())
        }

        guard !mappedIndices.isEmpty,
              dataRows.allSatisfy({ $0.count == mappedIndices.count }),
              anchor.row + dataRows.count <= result.rows.count else {
            throw RecordValueError.invalidValue(column: "Paste", expected: "rectangular data that fits the loaded rows")
        }
        let primaryKeyIndices = columns.indices.filter { columns[$0].isPrimaryKey }
        guard !primaryKeyIndices.isEmpty else {
            throw RecordValueError.invalidValue(column: "Paste", expected: "a table with a primary key")
        }
        var targetIdentities: Set<[DatabaseValue]> = []
        for rowIndex in anchor.row..<(anchor.row + dataRows.count) {
            let identity = primaryKeyIndices.map { index in
                index < result.rows[rowIndex].count ? result.rows[rowIndex][index] : .null
            }
            guard targetIdentities.insert(identity).inserted else {
                throw RecordValueError.invalidValue(column: "Paste", expected: "unique target primary keys")
            }
        }

        var plannedRows: [GridBatchRowEdit] = []
        for (rowOffset, encodedValues) in dataRows.enumerated() {
            let rowIndex = anchor.row + rowOffset
            var edits: [StagedEdit] = []
            for (valueOffset, encoded) in encodedValues.enumerated() {
                let columnIndex = mappedIndices[valueOffset]
                guard columns.indices.contains(columnIndex), columnIndex < result.rows[rowIndex].count else {
                    throw RecordValueError.invalidValue(column: "Paste", expected: "matching table and result columns")
                }
                let column = columns[columnIndex]
                guard !column.isGenerated else {
                    throw RecordValueError.invalidValue(column: column.name, expected: "a writable column")
                }
                let isNull = encoded == "\\N"
                guard !isNull || column.isNullable else {
                    throw RecordValueError.invalidValue(column: column.name, expected: "a non-NULL value")
                }
                let edit = StagedEdit(
                    columnIndex: columnIndex,
                    columnName: column.name,
                    columnType: column.type,
                    isPrimaryKey: column.isPrimaryKey,
                    isNullable: column.isNullable,
                    isUnsigned: column.isUnsigned,
                    isGenerated: column.isGenerated,
                    defaultValue: column.defaultValue,
                    originalValue: result.rows[rowIndex][columnIndex],
                    editText: isNull ? "" : decodeTSV(encoded),
                    isNull: isNull,
                    useDefault: false
                )
                let value = try edit.boundValue()
                if value != edit.originalValue { edits.append(edit) }
            }
            if !edits.isEmpty { plannedRows.append(GridBatchRowEdit(rowIndex: rowIndex, edits: edits)) }
        }
        guard !plannedRows.isEmpty else {
            throw RecordValueError.invalidValue(column: "Paste", expected: "at least one changed value")
        }
        return GridPastePlan(
            rows: plannedRows,
            mappedColumnNames: mappedIndices.map { columns[$0].name },
            sourceRowCount: dataRows.count,
            mappingMode: mappingMode
        )
    }

    static func parse(_ tsv: String) -> [[String]] {
        var rows = tsv.split(separator: "\n", omittingEmptySubsequences: false).map { line in
            String(line).trimmingCharacters(in: CharacterSet(charactersIn: "\r"))
                .split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
        }
        if tsv.hasSuffix("\n"), rows.last == [""] { rows.removeLast() }
        return rows
    }

    static func decodeTSV(_ value: String) -> String {
        var output = ""
        var index = value.startIndex
        while index < value.endIndex {
            if value[index] == "\\" {
                let next = value.index(after: index)
                guard next < value.endIndex else { output.append("\\"); break }
                switch value[next] {
                case "t": output.append("\t")
                case "r": output.append("\r")
                case "n": output.append("\n")
                case "\\": output.append("\\")
                default: output.append("\\"); output.append(value[next])
                }
                index = value.index(after: next)
            } else {
                output.append(value[index])
                index = value.index(after: index)
            }
        }
        return output
    }
}

private enum PendingRecordMutation {
    case update(edits: [StagedEdit], rowIndex: Int)
    case insert(edits: [StagedEdit])
    case batchUpdate(GridPastePlan)
}

private enum MutationExecutionError: LocalizedError {
    case affectedRows(expected: UInt64, actual: UInt64?)
    case server(String)

    var errorDescription: String? {
        switch self {
        case .affectedRows(let expected, let actual):
            return "The server reported \(actual.map(String.init) ?? "an unknown number of") affected rows; expected exactly \(expected). The edit was not accepted."
        case .server(let message):
            return message
        }
    }
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
    @State private var showExporter = false
    @State private var exportFormat: GridExportFormat = .csv
    @State private var pendingQueryStatements: [SQLStatement]?
    @State private var pendingRecordMutation: PendingRecordMutation?

    // Server-side grid state
    @State private var filters: [GridColumnFilter] = []
    @State private var sorts: [GridSortDescriptor] = []
    @State private var groupColumns: [String] = []
    @State private var aggregates: [GridAggregateDescriptor] = []
    @State private var filterColumnName = ""
    @State private var filterOperation: GridFilterOperator = .equals
    @State private var filterValue = ""

    // Persisted presentation and bounded range selection
    @State private var columnLayout = GridColumnLayout()
    @State private var resizeStartWidths: [String: Double] = [:]
    @State private var selectionAnchor: GridCellCoordinate?
    @State private var selectionEnd: GridCellCoordinate?
    @State private var pendingPasteTSV: String?
    @State private var pasteMappingMode: GridPasteMappingMode = .positional
    @State private var comparisonText: String?
    @State private var showTSVImporter = false

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
                if !isLoading { isAutoQuery = false }
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

            if !columnMeta.isEmpty {
                gridControlBar
                Divider()
            }

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
                    if let totalRowCount {
                        Text("\(totalRowCount) matching total")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("total unavailable")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    Text("in \(String(format: "%.3f", result.executionTime))s")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if isAutoRepeating {
                        Label("Repeating \(Int(autoRepeatInterval))s", systemImage: "repeat")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }

                    Spacer()

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
                        pendingRecordMutation = .update(edits: edits, rowIndex: rowIdx)
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
                    pendingRecordMutation = .insert(edits: edits)
                },
                onDiscard: { addingNewRow = false }
            )
        }
        #if canImport(FoundationModels)
        .sheet(isPresented: $showAIAssistant) {
            if let assistant = session?.aiAssistant {
                AIAssistantView(
                    aiAssistant: assistant,
                    schemaContext: SchemaContext(
                        databaseName: database,
                        tables: columnMeta.isEmpty ? [] : [
                            SchemaContext.TableInfo(
                                name: table,
                                columns: columnMeta.map { SchemaContext.ColumnInfo(name: $0.name, type: $0.type) }
                            )
                        ]
                    ),
                    onInsertQuery: { sql in
                        queryText = sql
                        showAIAssistant = false
                    }
                )
            } else {
                ContentUnavailableView("Session Disconnected", systemImage: "cable.connector.slash")
            }
        }
        #endif
        .alert("Review SQL Before Execution", isPresented: .init(
            get: { pendingQueryStatements != nil },
            set: { if !$0 { pendingQueryStatements = nil } }
        )) {
            Button("Execute", role: .destructive) {
                let statements = pendingQueryStatements ?? []
                pendingQueryStatements = nil
                Task { await execute(statements) }
            }
            Button("Cancel", role: .cancel) { pendingQueryStatements = nil }
        } message: {
            Text(queryMutationPreview)
        }
        .alert("Review Row Mutation", isPresented: .init(
            get: { pendingRecordMutation != nil },
            set: { if !$0 { pendingRecordMutation = nil } }
        )) {
            Button("Commit", role: .destructive) {
                let mutation = pendingRecordMutation
                pendingRecordMutation = nil
                Task {
                    switch mutation {
                    case .update(let edits, let rowIndex): await applyEdits(edits, rowIndex: rowIndex)
                    case .insert(let edits): await insertRow(edits)
                    case .batchUpdate(let plan): await applyBatchPaste(plan)
                    case .none: break
                    }
                }
            }
            Button("Cancel", role: .cancel) { pendingRecordMutation = nil }
        } message: {
            Text(recordMutationPreview)
        }
        .alert("Review Pasted Range", isPresented: .init(
            get: { pendingPasteTSV != nil },
            set: { if !$0 { pendingPasteTSV = nil } }
        )) {
            Button("Stage Paste") {
                let tsv = pendingPasteTSV ?? ""
                pendingPasteTSV = nil
                stagePastedRange(tsv)
            }
            Button("Cancel", role: .cancel) { pendingPasteTSV = nil }
        } message: {
            Text(pastePreview)
        }
        .alert("Compare Rows", isPresented: .init(
            get: { comparisonText != nil },
            set: { if !$0 { comparisonText = nil } }
        )) {
            Button("Done", role: .cancel) { comparisonText = nil }
        } message: {
            Text(comparisonText ?? "")
        }
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
        .onReceive(NotificationCenter.default.publisher(for: .glassdbShowAI)) { _ in
            showAIAssistant = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .glassdbStartRepeat)) { _ in
            startAutoRepeat()
        }
        .onReceive(NotificationCenter.default.publisher(for: .glassdbExport)) { notification in
            guard let raw = notification.object as? String,
                  let format = GridExportFormat(rawValue: raw) else { return }
            exportFormat = format
            showExporter = true
        }
        .fileExporter(
            isPresented: $showExporter,
            document: exportResult.map {
                GridExportDocument(
                    result: $0,
                    format: exportFormat,
                    database: database,
                    table: table,
                    identifierQuote: session?.connection?.identifierQuoteCharacter ?? "`"
                )
            },
            contentType: exportFormat.contentType,
            defaultFilename: "\(database)_\(table).\(exportFormat.rawValue)"
        ) { _ in }
        .fileImporter(
            isPresented: $showTSVImporter,
            allowedContentTypes: [.tabSeparatedText, .plainText],
            allowsMultipleSelection: false
        ) { selection in
            do {
                guard let url = try selection.get().first else { return }
                let accessed = url.startAccessingSecurityScopedResource()
                defer { if accessed { url.stopAccessingSecurityScopedResource() } }
                let byteCount = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? -1
                try GridImportPolicy.validate(byteCount: byteCount)
                let data = try Data(contentsOf: url, options: [.mappedIfSafe])
                try GridImportPolicy.validate(byteCount: data.count)
                guard let text = String(data: data, encoding: .utf8) else {
                    throw RecordValueError.invalidValue(column: "Import", expected: "UTF-8 TSV data")
                }
                pendingPasteTSV = text
            } catch {
                errorMessage = "Import was not staged. \(error.localizedDescription)"
            }
        }
        .onChange(of: currentPage) {
            if isAutoQuery { Task { await loadData() } }
        }
        .onChange(of: pageSize) {
            if isAutoQuery {
                persistGridQueryState()
                currentPage = 1
                Task { await loadData() }
            }
        }
        .task(id: "\(database).\(table)") {
            loadColumnLayout()
            loadGridQueryState()
            await loadData()
        }
    }

    // MARK: - Data Grid

    private var gridControlBar: some View {
        HStack(spacing: 8) {
            Menu {
                ForEach(columnMeta) { column in
                    Button(column.name) { filterColumnName = column.name }
                }
            } label: {
                Label(filterColumnName.isEmpty ? "Column" : filterColumnName, systemImage: "line.3.horizontal.decrease")
            }

            Picker("Filter", selection: $filterOperation) {
                ForEach(GridFilterOperator.allCases) { operation in
                    Text(operation.displayName).tag(operation)
                }
            }
            .labelsHidden()
            .frame(maxWidth: 160)

            if filterOperation.requiresValue {
                TextField("Filter value", text: $filterValue)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 180)
                    .onSubmit { applyFilter() }
            }
            Button("Apply") { applyFilter() }
                .disabled(filterColumnName.isEmpty || (filterOperation.requiresValue && filterValue.isEmpty))

            if !filters.isEmpty || !sorts.isEmpty {
                Button("Clear") {
                    filters = []
                    sorts = []
                    persistGridQueryState()
                    currentPage = 1
                    Task { await loadData() }
                }
                .buttonStyle(.bordered)
            }

            if !filters.isEmpty {
                Label("\(filters.count)", systemImage: "line.3.horizontal.decrease.circle.fill")
                    .foregroundStyle(.orange)
                    .help(filters.map { "\($0.columnName) \($0.operation.displayName)" }.joined(separator: ", "))
            }
            if !sorts.isEmpty {
                Text(sorts.enumerated().map { index, sort in
                    "\(index + 1):\(sort.columnName) \(sort.direction == .ascending ? "↑" : "↓")"
                }.joined(separator: "  "))
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }

            Spacer()

            Menu {
                Menu("Group Columns") {
                    ForEach(columnMeta) { column in
                        Button(groupColumns.contains(column.name) ? "Remove \(column.name)" : "Add \(column.name)") {
                            toggleGrouping(column.name)
                        }
                    }
                }
                Button("Add Count All") {
                    addAggregate(.countAll, columnName: nil)
                }
                Menu("Add Column Aggregate") {
                    ForEach(GridAggregateFunction.allCases.filter(\.requiresColumn)) { function in
                        Menu(function.displayName) {
                            ForEach(columnMeta) { column in
                                Button(column.name) { addAggregate(function, columnName: column.name) }
                            }
                        }
                    }
                }
                if !groupColumns.isEmpty || !aggregates.isEmpty {
                    Divider()
                    Button("Clear Analysis") { clearAnalysis() }
                }
            } label: {
                Label(
                    aggregates.isEmpty ? "Analyze" : "Analyze \(aggregates.count)",
                    systemImage: "function"
                )
            }

            Button("Compare") { compareSelectedRows() }
                .disabled(!canCompareSelectedRows)

            ControlGroup {
                Button { moveSelection(rowDelta: 0, columnDelta: -1) } label: { Image(systemName: "arrow.left") }
                    .keyboardShortcut(.leftArrow, modifiers: .shift)
                Button { moveSelection(rowDelta: 0, columnDelta: 1) } label: { Image(systemName: "arrow.right") }
                    .keyboardShortcut(.rightArrow, modifiers: .shift)
                Button { moveSelection(rowDelta: -1, columnDelta: 0) } label: { Image(systemName: "arrow.up") }
                    .keyboardShortcut(.upArrow, modifiers: .shift)
                Button { moveSelection(rowDelta: 1, columnDelta: 0) } label: { Image(systemName: "arrow.down") }
                    .keyboardShortcut(.downArrow, modifiers: .shift)
            }
            .disabled(result?.rows.isEmpty != false)

            Menu {
                ForEach(columnMeta) { column in
                    Button(columnLayout.hidden.contains(column.name) ? "Show \(column.name)" : "Hide \(column.name)") {
                        toggleColumnVisibility(column.name)
                    }
                    Button(columnLayout.frozen.contains(column.name) ? "Unfreeze \(column.name)" : "Freeze \(column.name)") {
                        toggleColumnFreeze(column.name)
                    }
                }
                Divider()
                Button("Reset Column Layout") { resetColumnLayout() }
            } label: {
                Label("Columns", systemImage: "rectangle.split.3x1")
            }

            Button {
                copySelectedRange()
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }
            .keyboardShortcut("c", modifiers: .command)
            .disabled(selectedRectangle == nil)

            PasteButton(payloadType: String.self) { values in
                guard let value = values.first, !value.isEmpty else { return }
                do {
                    try GridImportPolicy.validate(text: value)
                    pendingPasteTSV = value
                } catch {
                    errorMessage = "Paste was not staged. \(error.localizedDescription)"
                }
            }
            .labelStyle(.iconOnly)
            .keyboardShortcut("v", modifiers: .command)
            .disabled(selectionAnchor == nil || isAnalysisActive)

            Button { showTSVImporter = true } label: {
                Label("Import TSV", systemImage: "square.and.arrow.down")
            }
            .disabled(selectionAnchor == nil || isAnalysisActive)

            Toggle("Header", isOn: .init(
                get: { pasteMappingMode == .headerRow },
                set: { pasteMappingMode = $0 ? .headerRow : .positional }
            ))
            .help("Treat the first pasted row as exact table column names")
            .disabled(isAnalysisActive)
        }
        .controlSize(.small)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private var selectedRectangle: (rows: ClosedRange<Int>, columns: [Int])? {
        guard let anchor = selectionAnchor,
              let end = selectionEnd,
              let result else { return nil }
        let visible = gridVisibleColumnIndices(for: result)
        guard let anchorIndex = visible.firstIndex(of: anchor.column),
              let endIndex = visible.firstIndex(of: end.column) else { return nil }
        let lowerColumn = min(anchorIndex, endIndex)
        let upperColumn = max(anchorIndex, endIndex)
        return (
            min(anchor.row, end.row)...max(anchor.row, end.row),
            Array(visible[lowerColumn...upperColumn])
        )
    }

    private func gridVisibleColumnIndices(for result: QueryResult) -> [Int] {
        isAnalysisActive ? Array(result.columns.indices) : columnLayout.visibleColumnIndices(columns: result.columns)
    }

    private var pastePreview: String {
        guard let pendingPasteTSV, let anchor = selectionAnchor else { return "" }
        let rows = GridPastePlanBuilder.parse(pendingPasteTSV)
        let dataRowCount = max(0, rows.count - (pasteMappingMode == .headerRow ? 1 : 0))
        let columns = rows.first?.count ?? 0
        let mapping = pasteMappingMode == .headerRow
            ? "The first row maps exact table column names."
            : "Columns map positionally from the selected cell."
        return "Target starts at loaded row \(anchor.row + 1).\nPasted data: \(dataRowCount) row(s) × \(columns) column(s).\n\(mapping)\n\nEvery changed row will use its original full-row values as an optimistic predicate inside one transaction. Any validation, conflict, or server error rolls back the entire batch."
    }

    private var isAnalysisActive: Bool { !aggregates.isEmpty }

    private var canCompareSelectedRows: Bool {
        guard let selectedRectangle else { return false }
        return selectedRectangle.rows.count == 2 && !isAnalysisActive
    }

    private var exportResult: QueryResult? {
        guard let result else { return nil }
        let visible = gridVisibleColumnIndices(for: result)
        let rowIndices: [Int]
        if let selectedRectangle {
            rowIndices = selectedRectangle.rows.filter { result.rows.indices.contains($0) }
        } else {
            rowIndices = Array(result.rows.indices)
        }
        let selectedColumns: [Int]
        if let selectedRectangle {
            selectedColumns = selectedRectangle.columns
        } else {
            selectedColumns = visible
        }
        return QueryResult(
            query: result.query,
            columns: selectedColumns.map { result.columns[$0] },
            rows: rowIndices.map { rowIndex in
                selectedColumns.map { columnIndex in
                    columnIndex < result.rows[rowIndex].count ? result.rows[rowIndex][columnIndex] : .null
                }
            },
            executionTime: result.executionTime,
            timestamp: result.timestamp
        )
    }

    private func dataGrid(_ result: QueryResult) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            GeometryReader { geometry in
                let fontSize = settingsManager.dataGridFontSize
                let visibleIndices = gridVisibleColumnIndices(for: result)
                let automaticWidths = columnWidths(columns: result.columns, rows: result.rows)
                let widths = visibleIndices.map { index in
                    CGFloat(columnLayout.widths[result.columns[index].name] ?? Double(automaticWidths[index]))
                }
                let frozenLeadingOffsets = GridColumnLayout.leadingOffsets(widths: widths, startingAt: rowNumWidth)
                let activeSelection = selectedRectangle
                let selectedColumns = Set(activeSelection?.columns ?? [])
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
                                        .background(.ultraThinMaterial)
                                        .visualEffect { content, proxy in
                                            content.offset(x: max(0, -proxy.frame(in: .scrollView(axis: .horizontal)).minX))
                                        }
                                        .zIndex(3)

                                    // Data cells
                                    ForEach(Array(visibleIndices.enumerated()), id: \.element) { visibleOffset, colIndex in
                                        let value = colIndex < row.count ? row[colIndex] : DatabaseValue.null
                                        let frozenLeadingOffset = frozenLeadingOffsets[visibleOffset]
                                        let isFrozen = columnLayout.frozen.contains(result.columns[colIndex].name)
                                        let isSelected = activeSelection?.rows.contains(rowIndex) == true && selectedColumns.contains(colIndex)
                                        Text(value.displayString)
                                            .font(.system(size: fontSize, design: .monospaced))
                                            .lineLimit(1)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .frame(width: widths[visibleOffset], height: rowHeight, alignment: .leading)
                                            .foregroundStyle(value.isNull ? .tertiary : .primary)
                                            .background(isFrozen ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color.clear))
                                            .background(isSelected ? AnyShapeStyle(Color.accentColor.opacity(0.22)) : AnyShapeStyle(Color.clear))
                                            .visualEffect { content, proxy in
                                                content.offset(
                                                    x: isFrozen
                                                        ? max(0, frozenLeadingOffset - proxy.frame(in: .scrollView(axis: .horizontal)).minX)
                                                        : 0
                                                )
                                            }
                                            .zIndex(isFrozen ? 2 : 0)
                                            .accessibilityLabel("\(result.columns[colIndex].name): \(value.isNull ? "null" : value.displayString)")
                                            .contentShape(Rectangle())
                                            .onTapGesture(count: 2) { selectRow(rowIndex) }
                                            .onTapGesture { selectCell(row: rowIndex, column: colIndex) }
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
                                    .background(.ultraThinMaterial)
                                    .visualEffect { content, proxy in
                                        content.offset(x: max(0, -proxy.frame(in: .scrollView(axis: .horizontal)).minX))
                                    }
                                    .zIndex(4)

                                ForEach(Array(visibleIndices.enumerated()), id: \.element) { visibleOffset, colIndex in
                                    let col = result.columns[colIndex]
                                    let frozenLeadingOffset = frozenLeadingOffsets[visibleOffset]
                                    let isFrozen = columnLayout.frozen.contains(col.name)
                                    HStack(spacing: 4) {
                                        Text(col.name)
                                            .lineLimit(1)
                                        if let priority = sorts.firstIndex(where: { $0.columnName == col.name }) {
                                            Text("\(priority + 1)\(sorts[priority].direction == .ascending ? "↑" : "↓")")
                                                .font(.caption2)
                                                .foregroundStyle(.orange)
                                        }
                                        if columnLayout.frozen.contains(col.name) {
                                            Image(systemName: "pin.fill")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer(minLength: 0)
                                    }
                                    .font(.system(size: fontSize, weight: .bold, design: .monospaced))
                                    .padding(.leading, 12)
                                    .padding(.vertical, 8)
                                    .frame(width: widths[visibleOffset], alignment: .leading)
                                    .background(isFrozen ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color.clear))
                                    .visualEffect { content, proxy in
                                        content.offset(
                                            x: isFrozen
                                                ? max(0, frozenLeadingOffset - proxy.frame(in: .scrollView(axis: .horizontal)).minX)
                                                : 0
                                        )
                                    }
                                    .zIndex(isFrozen ? 3 : 0)
                                    .contentShape(Rectangle())
                                    .onTapGesture { cycleSort(for: col.name) }
                                    .contextMenu {
                                        Button("Sort Ascending") { setSort(col.name, direction: .ascending) }
                                        Button("Sort Descending") { setSort(col.name, direction: .descending) }
                                        Button("Remove Sort") { removeSort(col.name) }
                                        Divider()
                                        Button(columnLayout.frozen.contains(col.name) ? "Unfreeze" : "Freeze") {
                                            toggleColumnFreeze(col.name)
                                        }
                                        Button("Hide") { toggleColumnVisibility(col.name) }
                                        Button("Move Left") { moveColumn(col.name, offset: -1) }
                                        Button("Move Right") { moveColumn(col.name, offset: 1) }
                                    }
                                    .overlay(alignment: .trailing) {
                                        Rectangle()
                                            .fill(Color.secondary.opacity(0.35))
                                            .frame(width: 5)
                                            .contentShape(Rectangle().inset(by: -6))
                                            .gesture(
                                                DragGesture(minimumDistance: 1)
                                                    .onChanged { value in resizeColumn(col.name, baseWidth: widths[visibleOffset], translation: value.translation.width) }
                                                    .onEnded { _ in finishResizingColumn(col.name) }
                                            )
                                    }
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
        guard !isAnalysisActive else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            if selectedRowIndex == rowIndex {
                showEditor.toggle()
            } else {
                selectedRowIndex = rowIndex
                showEditor = true
            }
        }
    }

    private func selectCell(row: Int, column: Int) {
        let coordinate = GridCellCoordinate(row: row, column: column)
        if selectionAnchor == nil || selectionAnchor != selectionEnd {
            selectionAnchor = coordinate
            selectionEnd = coordinate
        } else {
            selectionEnd = coordinate
        }
        selectedRowIndex = row
    }

    private func copySelectedRange() {
        guard let exportResult,
              !exportResult.rows.isEmpty,
              !exportResult.columns.isEmpty else { return }
        UIPasteboard.general.string = GridExportFormatter.tsv(
            result: exportResult,
            rowRange: exportResult.rows.indices.lowerBound...(exportResult.rows.indices.upperBound - 1),
            columnRange: exportResult.columns.indices.lowerBound...(exportResult.columns.indices.upperBound - 1)
        )
    }

    private func moveSelection(rowDelta: Int, columnDelta: Int) {
        guard let result, !result.rows.isEmpty else { return }
        let visible = gridVisibleColumnIndices(for: result)
        guard !visible.isEmpty else { return }
        let current = selectionEnd ?? GridCellCoordinate(row: 0, column: visible[0])
        let currentVisibleIndex = visible.firstIndex(of: current.column) ?? 0
        let next = GridCellCoordinate(
            row: max(0, min(result.rows.count - 1, current.row + rowDelta)),
            column: visible[max(0, min(visible.count - 1, currentVisibleIndex + columnDelta))]
        )
        if selectionAnchor == nil { selectionAnchor = current }
        selectionEnd = next
        selectedRowIndex = next.row
    }

    private func stagePastedRange(_ tsv: String) {
        guard let result, let anchor = selectionAnchor else { return }
        let columns = columnMeta.isEmpty ? result.columns : columnMeta
        let visible = columnLayout.visibleColumnIndices(columns: columns)
        do {
            let plan = try GridPastePlanBuilder.build(
                tsv: tsv,
                anchor: anchor,
                result: result,
                columns: columns,
                visibleColumnIndices: visible,
                mappingMode: pasteMappingMode
            )
            pendingRecordMutation = plan.rows.count == 1
                ? .update(edits: plan.rows[0].edits, rowIndex: plan.rows[0].rowIndex)
                : .batchUpdate(plan)
        } catch {
            errorMessage = "Paste was not staged. No values were changed. \(error.localizedDescription)"
        }
    }

    private func compareSelectedRows() {
        guard let result, let selectedRectangle, selectedRectangle.rows.count == 2 else { return }
        do {
            let differences = try GridRowComparison.differences(
                result: result,
                leftRow: selectedRectangle.rows.lowerBound,
                rightRow: selectedRectangle.rows.upperBound,
                columnIndices: selectedRectangle.columns
            )
            let header = "Loaded rows \(selectedRectangle.rows.lowerBound + 1) and \(selectedRectangle.rows.upperBound + 1)"
            comparisonText = differences.isEmpty
                ? "\(header) are identical in the selected columns."
                : header + "\n\n" + differences.map {
                    "\($0.columnName)\n  Left: \($0.left.isNull ? "NULL" : $0.left.displayString)\n  Right: \($0.right.isNull ? "NULL" : $0.right.displayString)"
                }.joined(separator: "\n\n")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func applyFilter() {
        guard let column = columnMeta.first(where: { $0.name == filterColumnName }) else { return }
        let filter = GridColumnFilter(
            columnName: column.name,
            columnType: column.type,
            isUnsigned: column.isUnsigned,
            operation: filterOperation,
            value: filterValue
        )
        filters.removeAll { $0.columnName == column.name }
        filters.append(filter)
        persistGridQueryState()
        currentPage = 1
        Task { await loadData() }
    }

    private func cycleSort(for columnName: String) {
        if let index = sorts.firstIndex(where: { $0.columnName == columnName }) {
            if sorts[index].direction == .ascending {
                sorts[index].direction = .descending
            } else {
                sorts.remove(at: index)
            }
        } else {
            sorts.append(GridSortDescriptor(columnName: columnName, direction: .ascending))
        }
        persistGridQueryState()
        currentPage = 1
        Task { await loadData() }
    }

    private func setSort(_ columnName: String, direction: GridSortDirection) {
        if let index = sorts.firstIndex(where: { $0.columnName == columnName }) {
            sorts[index].direction = direction
        } else {
            sorts.append(GridSortDescriptor(columnName: columnName, direction: direction))
        }
        persistGridQueryState()
        currentPage = 1
        Task { await loadData() }
    }

    private func removeSort(_ columnName: String) {
        sorts.removeAll { $0.columnName == columnName }
        persistGridQueryState()
        currentPage = 1
        Task { await loadData() }
    }

    private func toggleColumnVisibility(_ columnName: String) {
        if columnLayout.hidden.contains(columnName) {
            columnLayout.hidden.remove(columnName)
        } else if columnLayout.visibleColumnIndices(columns: columnMeta).count > 1 {
            columnLayout.hidden.insert(columnName)
            columnLayout.frozen.remove(columnName)
        }
        persistColumnLayout()
    }

    private func toggleColumnFreeze(_ columnName: String) {
        if columnLayout.frozen.contains(columnName) {
            columnLayout.frozen.remove(columnName)
        } else {
            columnLayout.frozen.insert(columnName)
            columnLayout.hidden.remove(columnName)
        }
        persistColumnLayout()
    }

    private func moveColumn(_ columnName: String, offset: Int) {
        guard let source = columnLayout.order.firstIndex(of: columnName) else { return }
        let destination = max(0, min(columnLayout.order.count - 1, source + offset))
        guard source != destination else { return }
        columnLayout.order.remove(at: source)
        columnLayout.order.insert(columnName, at: destination)
        persistColumnLayout()
    }

    private func resizeColumn(_ columnName: String, baseWidth: CGFloat, translation: CGFloat) {
        let start = resizeStartWidths[columnName] ?? Double(baseWidth)
        resizeStartWidths[columnName] = start
        columnLayout.widths[columnName] = Double(max(60, min(600, CGFloat(start) + translation)))
    }

    private func finishResizingColumn(_ columnName: String) {
        resizeStartWidths.removeValue(forKey: columnName)
        persistColumnLayout()
    }

    private func resetColumnLayout() {
        columnLayout = GridColumnLayout(order: columnMeta.map(\.name))
        persistColumnLayout()
    }

    private func toggleGrouping(_ columnName: String) {
        if let index = groupColumns.firstIndex(of: columnName) {
            groupColumns.remove(at: index)
        } else {
            groupColumns.append(columnName)
        }
        persistGridQueryState()
        currentPage = 1
        if !aggregates.isEmpty { Task { await loadData() } }
    }

    private func addAggregate(_ function: GridAggregateFunction, columnName: String?) {
        let descriptor = GridAggregateDescriptor(function: function, columnName: columnName)
        if !aggregates.contains(descriptor) { aggregates.append(descriptor) }
        persistGridQueryState()
        currentPage = 1
        Task { await loadData() }
    }

    private func clearAnalysis() {
        groupColumns = []
        aggregates = []
        persistGridQueryState()
        currentPage = 1
        Task { await loadData() }
    }

    private func loadColumnLayout() {
        guard let connectionID = session?.connectionConfig.id else { return }
        let key = GridColumnLayout.storageKey(connectionID: connectionID, database: database, table: table)
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode(GridColumnLayout.self, from: data) {
            columnLayout = decoded
        }
    }

    private func persistColumnLayout() {
        guard let connectionID = session?.connectionConfig.id,
              let data = try? JSONEncoder().encode(columnLayout) else { return }
        let key = GridColumnLayout.storageKey(connectionID: connectionID, database: database, table: table)
        UserDefaults.standard.set(data, forKey: key)
    }

    private func loadGridQueryState() {
        guard let connectionID = session?.connectionConfig.id else { return }
        let key = GridQueryState.storageKey(connectionID: connectionID, database: database, table: table)
        guard let data = UserDefaults.standard.data(forKey: key),
              let state = try? JSONDecoder().decode(GridQueryState.self, from: data) else { return }
        filters = state.filters
        sorts = state.sorts
        groupColumns = state.groupColumns
        aggregates = state.aggregates
        pageSize = state.pageSize
    }

    private func persistGridQueryState() {
        guard let connectionID = session?.connectionConfig.id else { return }
        let state = GridQueryState(
            filters: filters,
            sorts: sorts,
            groupColumns: groupColumns,
            aggregates: aggregates,
            pageSize: pageSize
        )
        guard let data = try? JSONEncoder().encode(state) else { return }
        let key = GridQueryState.storageKey(connectionID: connectionID, database: database, table: table)
        UserDefaults.standard.set(data, forKey: key)
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

    private func loadData() async {
        guard let connection = session?.connection else { return }
        let preservedIdentity = selectedRowIdentity()
        isAutoQuery = true
        isLoading = true
        errorMessage = nil
        showEditor = false
        do {
            columnMeta = try await connection.columns(in: table, database: database)
            columnLayout.reconcile(columns: columnMeta)
            persistColumnLayout()
            var queryState = GridQueryState(
                filters: filters,
                sorts: sorts,
                groupColumns: groupColumns,
                aggregates: aggregates,
                pageSize: pageSize
            )
            queryState.reconcile(columns: columnMeta)
            filters = queryState.filters
            sorts = queryState.sorts
            groupColumns = queryState.groupColumns
            aggregates = queryState.aggregates
            pageSize = queryState.pageSize
            persistGridQueryState()
            if filterColumnName.isEmpty || !columnMeta.contains(where: { $0.name == filterColumnName }) {
                filterColumnName = columnMeta.first?.name ?? ""
            }
            let query: GridServerQuery
            let countQuery: GridServerQuery
            if isAnalysisActive {
                query = try GridServerQueryBuilder.aggregate(
                    database: database,
                    table: table,
                    columns: columnMeta,
                    filters: filters,
                    groupColumns: groupColumns,
                    aggregates: aggregates,
                    page: currentPage,
                    pageSize: pageSize,
                    identifierQuote: connection.identifierQuoteCharacter,
                    dialect: connection.dialect
                )
                countQuery = try GridServerQueryBuilder.aggregateCount(
                    database: database,
                    table: table,
                    columns: columnMeta,
                    filters: filters,
                    groupColumns: groupColumns,
                    aggregates: aggregates,
                    identifierQuote: connection.identifierQuoteCharacter,
                    dialect: connection.dialect
                )
            } else {
                query = try GridServerQueryBuilder.select(
                    database: database,
                    table: table,
                    columns: columnMeta,
                    filters: filters,
                    sorts: sorts,
                    page: currentPage,
                    pageSize: pageSize,
                    identifierQuote: connection.identifierQuoteCharacter,
                    dialect: connection.dialect
                )
                countQuery = try GridServerQueryBuilder.count(
                    database: database,
                    table: table,
                    columns: columnMeta,
                    filters: filters,
                    identifierQuote: connection.identifierQuoteCharacter,
                    dialect: connection.dialect
                )
            }
            queryText = query.sql
            async let dataTask = sessionManager.executeQuery(
                query.sql,
                parameters: query.parameters,
                sessionID: sessionID
            )
            async let countTask = connection.execute(countQuery.sql, parameters: countQuery.parameters)
            let loadedResult = try await dataTask
            result = loadedResult
            if let countResult = try? await countTask,
               let value = countResult.rows.first?.first,
               let count = Int(value.displayString) {
                totalRowCount = count
            } else {
                totalRowCount = nil
            }
            restoreSelection(identity: preservedIdentity, in: loadedResult)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func selectedRowIdentity() -> [String: DatabaseValue]? {
        guard !isAnalysisActive else { return nil }
        guard let result, let selectedRowIndex, result.rows.indices.contains(selectedRowIndex) else { return nil }
        let columns = columnMeta.isEmpty ? result.columns : columnMeta
        let primaryKeys = columns.enumerated().filter { $0.element.isPrimaryKey }
        guard !primaryKeys.isEmpty else { return nil }
        return Dictionary(uniqueKeysWithValues: primaryKeys.compactMap { index, column in
            guard index < result.rows[selectedRowIndex].count else { return nil }
            return (column.name, result.rows[selectedRowIndex][index])
        })
    }

    private func restoreSelection(identity: [String: DatabaseValue]?, in result: QueryResult) {
        guard let identity, !identity.isEmpty else {
            selectedRowIndex = nil
            selectionAnchor = nil
            selectionEnd = nil
            return
        }
        let indexByName = Dictionary(uniqueKeysWithValues: result.columns.enumerated().map { ($0.element.name, $0.offset) })
        selectedRowIndex = result.rows.firstIndex { row in
            identity.allSatisfy { name, value in
                guard let index = indexByName[name], index < row.count else { return false }
                return row[index] == value
            }
        }
        if selectedRowIndex == nil {
            selectionAnchor = nil
            selectionEnd = nil
        }
    }

    private var queryMutationPreview: String {
        guard let statements = pendingQueryStatements else { return "" }
        let categories = Set(statements.filter(\.safety.requiresConfirmation).map { $0.safety.displayName }).sorted()
        let sql = statements.map(\.text).joined(separator: ";\n")
        return "Connection: \(session?.connectionConfig.name ?? "Disconnected")\nDatabase: \(database)\nTable: \(table)\nRisk: \(categories.joined(separator: ", "))\nTransaction: statement-defined/server default\n\n\(sql)"
    }

    private var recordMutationPreview: String {
        guard let pendingRecordMutation else { return "" }
        switch pendingRecordMutation {
        case .update(let edits, _):
            return "Connection: \(session?.connectionConfig.name ?? "Disconnected")\nDatabase: \(database)\nTable: \(table)\nOperation: UPDATE one row\nChanged columns: \(edits.map(\.columnName).joined(separator: ", "))\nPredicate: primary key plus all original row values (optimistic conflict check)\nTransaction: atomic commit or rollback"
        case .insert(let edits):
            return "Connection: \(session?.connectionConfig.name ?? "Disconnected")\nDatabase: \(database)\nTable: \(table)\nOperation: INSERT one row\nProvided columns: \(edits.map(\.columnName).joined(separator: ", "))\nOmitted columns: server DEFAULT\nTransaction: atomic commit or rollback"
        case .batchUpdate(let plan):
            return "Connection: \(session?.connectionConfig.name ?? "Disconnected")\nDatabase: \(database)\nTable: \(table)\nOperation: UPDATE \(plan.rows.count) changed row(s) from \(plan.sourceRowCount) pasted row(s)\nMapped columns: \(plan.mappedColumnNames.joined(separator: ", "))\nMapping: \(plan.mappingMode == .headerRow ? "exact header names" : "positional from selected cell")\nPredicate: primary key plus every original row value (optimistic conflict checks)\nTransaction: all rows commit together or all rows roll back"
        }
    }

    private func executeCurrentQuery() async {
        let sql = queryText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sql.isEmpty else { return }
        let statements = SQLHighlighter.statements(in: sql)
        guard !statements.isEmpty else { return }
        if statements.contains(where: { $0.safety.requiresConfirmation }) {
            pendingQueryStatements = statements
            return
        }
        await execute(statements)
    }

    private func execute(_ statements: [SQLStatement]) async {
        isLoading = true
        errorMessage = nil
        selectedRowIndex = nil
        showEditor = false
        do {
            var lastResult: QueryResult?
            for statement in statements {
                let queryResult = try await sessionManager.executeQuery(statement.text, sessionID: sessionID)
                if let serverError = queryResult.error {
                    throw MutationExecutionError.server(serverError)
                }
                lastResult = queryResult
                if statement.safety.requiresConfirmation, let connectionID = session?.connectionConfig.id {
                    MutationAuditStore.append(MutationAuditRecord(
                        connectionID: connectionID,
                        database: database,
                        object: table,
                        normalizedOperation: statement.safety.rawValue,
                        source: "query-editor",
                        outcome: .committed,
                        affectedRows: queryResult.affectedRows
                    ))
                }
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
        guard let result, let connection = session?.connection else { return }

        // Use columnMeta for PK info (query result columns don't have it)
        let cols = columnMeta.isEmpty ? result.columns : columnMeta
        let pkColumns = cols.filter(\.isPrimaryKey)
        guard !pkColumns.isEmpty else {
            errorMessage = "Cannot update: table has no primary key"
            return
        }

        guard rowIndex < result.rows.count, !edits.isEmpty else { return }
        var parameters: [DatabaseValue] = []
        var transactionStarted = false
        var commitAttempted = false
        do {
            let setClauses = try edits.map { edit -> String in
                guard edit.columnIndex < cols.count else {
                    throw RecordValueError.invalidValue(column: edit.columnName, expected: "a valid table column")
                }
                parameters.append(try edit.boundValue())
                return "\(connection.quotedIdentifier(cols[edit.columnIndex].name)) = \(connection.parameterPlaceholder(at: parameters.count))"
            }.joined(separator: ", ")

            var whereClauses: [String] = []
            for (index, column) in cols.enumerated() where index < result.rows[rowIndex].count {
                let original = result.rows[rowIndex][index]
                let identifier = connection.quotedIdentifier(column.name)
                if original.isNull {
                    whereClauses.append("\(identifier) IS NULL")
                } else {
                    parameters.append(original)
                    whereClauses.append("\(identifier) = \(connection.parameterPlaceholder(at: parameters.count))")
                }
            }

            let sql = "UPDATE \(connection.quotedIdentifier(database)).\(connection.quotedIdentifier(table)) SET \(setClauses) WHERE \(whereClauses.joined(separator: " AND "))"
            try await connection.beginTransaction()
            transactionStarted = true
            let updateResult = try await connection.execute(sql, parameters: parameters)
            if let serverError = updateResult.error { throw MutationExecutionError.server(serverError) }
            guard updateResult.affectedRows == 1 else {
                throw MutationExecutionError.affectedRows(expected: 1, actual: updateResult.affectedRows)
            }
            commitAttempted = true
            try await connection.commitTransaction()
            transactionStarted = false
            MutationAuditStore.append(MutationAuditRecord(
                connectionID: session?.connectionConfig.id ?? sessionID,
                database: database,
                object: table,
                normalizedOperation: "update",
                source: "record-editor",
                outcome: .committed,
                affectedRows: updateResult.affectedRows
            ))
            withAnimation { showEditor = false }
            await loadData()
        } catch {
            let outcome: MutationOutcome
            if commitAttempted {
                outcome = .serverStateUnknown
            } else if transactionStarted {
                outcome = await rollback(connection) ? .rolledBack : .serverStateUnknown
            } else {
                outcome = .notStarted
            }
            MutationAuditStore.append(MutationAuditRecord(
                connectionID: session?.connectionConfig.id ?? sessionID,
                database: database,
                object: table,
                normalizedOperation: "update",
                source: "record-editor",
                outcome: outcome,
                affectedRows: nil
            ))
            errorMessage = "Update failed (\(outcomeDescription(outcome))): \(error.localizedDescription)"
        }
    }

    private func applyBatchPaste(_ plan: GridPastePlan) async {
        guard !isAnalysisActive,
              let result,
              let connection = session?.connection else { return }
        let columns = columnMeta.isEmpty ? result.columns : columnMeta
        guard columns.contains(where: \.isPrimaryKey), !plan.rows.isEmpty else {
            errorMessage = "Batch paste was not started because the table has no primary key or the plan is empty."
            return
        }

        var transactionStarted = false
        var commitAttempted = false
        var affectedRows: UInt64 = 0
        isLoading = true
        errorMessage = nil
        do {
            try await connection.beginTransaction()
            transactionStarted = true
            for rowEdit in plan.rows {
                guard result.rows.indices.contains(rowEdit.rowIndex), !rowEdit.edits.isEmpty else {
                    throw RecordValueError.invalidValue(column: "Paste", expected: "current non-empty target rows")
                }
                var parameters: [DatabaseValue] = []
                let setClauses = try rowEdit.edits.map { edit -> String in
                    guard columns.indices.contains(edit.columnIndex), !columns[edit.columnIndex].isGenerated else {
                        throw RecordValueError.invalidValue(column: edit.columnName, expected: "a writable table column")
                    }
                    parameters.append(try edit.boundValue())
                    return "\(connection.quotedIdentifier(columns[edit.columnIndex].name)) = \(connection.parameterPlaceholder(at: parameters.count))"
                }.joined(separator: ", ")

                var predicates: [String] = []
                for (index, column) in columns.enumerated() where index < result.rows[rowEdit.rowIndex].count {
                    let original = result.rows[rowEdit.rowIndex][index]
                    let identifier = connection.quotedIdentifier(column.name)
                    if original.isNull {
                        predicates.append("\(identifier) IS NULL")
                    } else {
                        parameters.append(original)
                        predicates.append("\(identifier) = \(connection.parameterPlaceholder(at: parameters.count))")
                    }
                }
                guard !predicates.isEmpty else {
                    throw RecordValueError.invalidValue(column: "Paste", expected: "an optimistic row predicate")
                }
                let sql = "UPDATE \(connection.quotedIdentifier(database)).\(connection.quotedIdentifier(table)) SET \(setClauses) WHERE \(predicates.joined(separator: " AND "))"
                let updateResult = try await connection.execute(sql, parameters: parameters)
                if let serverError = updateResult.error { throw MutationExecutionError.server(serverError) }
                guard updateResult.affectedRows == 1 else {
                    throw MutationExecutionError.affectedRows(expected: 1, actual: updateResult.affectedRows)
                }
                affectedRows += 1
            }
            commitAttempted = true
            try await connection.commitTransaction()
            transactionStarted = false
            MutationAuditStore.append(MutationAuditRecord(
                connectionID: session?.connectionConfig.id ?? sessionID,
                database: database,
                object: table,
                normalizedOperation: "update-batch",
                source: "grid-paste",
                outcome: .committed,
                affectedRows: affectedRows
            ))
            await loadData()
        } catch {
            let outcome: MutationOutcome
            if commitAttempted {
                outcome = .serverStateUnknown
            } else if transactionStarted {
                outcome = await rollback(connection) ? .rolledBack : .serverStateUnknown
            } else {
                outcome = .notStarted
            }
            MutationAuditStore.append(MutationAuditRecord(
                connectionID: session?.connectionConfig.id ?? sessionID,
                database: database,
                object: table,
                normalizedOperation: "update-batch",
                source: "grid-paste",
                outcome: outcome,
                affectedRows: affectedRows
            ))
            errorMessage = "Batch paste failed after \(affectedRows) row(s) (\(outcomeDescription(outcome))): \(error.localizedDescription)"
            isLoading = false
        }
    }

    // MARK: - Insert Row

    private func insertRow(_ edits: [StagedEdit]) async {
        let cols = columnMeta
        guard let connection = session?.connection else { return }
        guard !cols.isEmpty else {
            errorMessage = "Cannot insert: no column metadata"
            return
        }

        var transactionStarted = false
        var commitAttempted = false
        do {
            let usableEdits = edits.filter { !$0.useDefault }
            let sql: String
            var parameters: [DatabaseValue] = []
            if usableEdits.isEmpty {
                let tableName = "\(connection.quotedIdentifier(database)).\(connection.quotedIdentifier(table))"
                sql = connection.dialect == .mysql
                    ? "INSERT INTO \(tableName) () VALUES ()"
                    : "INSERT INTO \(tableName) DEFAULT VALUES"
            } else {
                let columnNames = try usableEdits.map { edit -> String in
                    guard edit.columnIndex < cols.count else {
                        throw RecordValueError.invalidValue(column: edit.columnName, expected: "a valid table column")
                    }
                    parameters.append(try edit.boundValue())
                    return connection.quotedIdentifier(cols[edit.columnIndex].name)
                }.joined(separator: ", ")
                let placeholders = (1...parameters.count)
                    .map(connection.parameterPlaceholder(at:))
                    .joined(separator: ", ")
                sql = "INSERT INTO \(connection.quotedIdentifier(database)).\(connection.quotedIdentifier(table)) (\(columnNames)) VALUES (\(placeholders))"
            }

            try await connection.beginTransaction()
            transactionStarted = true
            let insertResult = try await connection.execute(sql, parameters: parameters)
            if let serverError = insertResult.error { throw MutationExecutionError.server(serverError) }
            guard insertResult.affectedRows == 1 else {
                throw MutationExecutionError.affectedRows(expected: 1, actual: insertResult.affectedRows)
            }
            commitAttempted = true
            try await connection.commitTransaction()
            transactionStarted = false
            MutationAuditStore.append(MutationAuditRecord(
                connectionID: session?.connectionConfig.id ?? sessionID,
                database: database,
                object: table,
                normalizedOperation: "insert",
                source: "record-editor",
                outcome: .committed,
                affectedRows: insertResult.affectedRows
            ))
            addingNewRow = false
            await loadData()
        } catch {
            let outcome: MutationOutcome
            if commitAttempted {
                outcome = .serverStateUnknown
            } else if transactionStarted {
                outcome = await rollback(connection) ? .rolledBack : .serverStateUnknown
            } else {
                outcome = .notStarted
            }
            MutationAuditStore.append(MutationAuditRecord(
                connectionID: session?.connectionConfig.id ?? sessionID,
                database: database,
                object: table,
                normalizedOperation: "insert",
                source: "record-editor",
                outcome: outcome,
                affectedRows: nil
            ))
            errorMessage = "Insert failed (\(outcomeDescription(outcome))): \(error.localizedDescription)"
        }
    }

    private func rollback(_ connection: any DatabaseConnection) async -> Bool {
        do {
            try await connection.rollbackTransaction()
            return true
        } catch {
            return false
        }
    }

    private func outcomeDescription(_ outcome: MutationOutcome) -> String {
        switch outcome {
        case .committed: return "committed"
        case .rolledBack: return "rolled back"
        case .serverStateUnknown: return "server state unknown; refresh before retrying"
        case .notStarted: return "not started"
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
            if session?.connection?.capabilities.contains(.createTableDefinition) == false {
                ContentUnavailableView(
                    "DDL Unavailable",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text("This database engine does not expose complete CREATE TABLE definitions.")
                )
            } else if isLoading {
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
        guard let connection = session?.connection,
              connection.capabilities.contains(.createTableDefinition) else { return }
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
