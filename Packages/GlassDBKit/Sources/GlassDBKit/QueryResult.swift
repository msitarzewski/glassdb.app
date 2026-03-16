//
//  QueryResult.swift
//  GlassDBKit
//
//  Unified result model for query execution across all database engines
//

import Foundation

public struct QueryResult: Identifiable, Sendable {
    public let id: UUID
    public let query: String
    public let columns: [ColumnInfo]
    public let rows: [[DatabaseValue]]
    public let affectedRows: Int?
    public let executionTime: TimeInterval
    public let timestamp: Date
    public let error: String?

    public init(
        id: UUID = UUID(),
        query: String,
        columns: [ColumnInfo] = [],
        rows: [[DatabaseValue]] = [],
        affectedRows: Int? = nil,
        executionTime: TimeInterval,
        timestamp: Date = Date(),
        error: String? = nil
    ) {
        self.id = id
        self.query = query
        self.columns = columns
        self.rows = rows
        self.affectedRows = affectedRows
        self.executionTime = executionTime
        self.timestamp = timestamp
        self.error = error
    }

    public var isError: Bool { error != nil }
    public var rowCount: Int { rows.count }
    public var columnCount: Int { columns.count }
}

public struct ColumnInfo: Identifiable, Sendable, Hashable {
    public let id: UUID
    public let name: String
    public let type: String
    public let isNullable: Bool
    public let isPrimaryKey: Bool
    public let ordinalPosition: Int

    public init(
        id: UUID = UUID(),
        name: String,
        type: String,
        isNullable: Bool = true,
        isPrimaryKey: Bool = false,
        ordinalPosition: Int = 0
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.isNullable = isNullable
        self.isPrimaryKey = isPrimaryKey
        self.ordinalPosition = ordinalPosition
    }
}

public enum DatabaseValue: Sendable, Hashable {
    case string(String)
    case int(Int64)
    case double(Double)
    case data(Data)
    case null
    case date(Date)
    case bool(Bool)

    public var displayString: String {
        switch self {
        case .string(let s): return s
        case .int(let i): return String(i)
        case .double(let d): return String(d)
        case .data(let d): return "<\(d.count) bytes>"
        case .null: return "NULL"
        case .date(let d): return ISO8601DateFormatter().string(from: d)
        case .bool(let b): return b ? "true" : "false"
        }
    }

    public var isNull: Bool {
        if case .null = self { return true }
        return false
    }
}

public struct IndexInfo: Identifiable, Sendable {
    public let id = UUID()
    public let name: String
    public let columnName: String
    public let isUnique: Bool
    public let type: String
    public let sequenceInIndex: Int

    public init(name: String, columnName: String, isUnique: Bool, type: String, sequenceInIndex: Int) {
        self.name = name
        self.columnName = columnName
        self.isUnique = isUnique
        self.type = type
        self.sequenceInIndex = sequenceInIndex
    }
}

public struct ForeignKeyInfo: Identifiable, Sendable {
    public let id = UUID()
    public let constraintName: String
    public let columnName: String
    public let referencedTable: String
    public let referencedColumn: String
    public let ordinalPosition: Int

    public init(constraintName: String, columnName: String, referencedTable: String, referencedColumn: String, ordinalPosition: Int) {
        self.constraintName = constraintName
        self.columnName = columnName
        self.referencedTable = referencedTable
        self.referencedColumn = referencedColumn
        self.ordinalPosition = ordinalPosition
    }
}

public struct TableStatus: Identifiable, Sendable {
    public let id = UUID()
    public let name: String
    public let engine: String?
    public let rowCount: Int
    public let dataLength: Int
    public let collation: String?

    public init(name: String, engine: String?, rowCount: Int, dataLength: Int, collation: String?) {
        self.name = name
        self.engine = engine
        self.rowCount = rowCount
        self.dataLength = dataLength
        self.collation = collation
    }
}
