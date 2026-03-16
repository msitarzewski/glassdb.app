//
//  MySQLAdapter.swift
//  GlassDBKit
//
//  mysql-nio wrapper implementing DatabaseProtocol
//

import Foundation
import MySQLNIO
import NIOCore
import NIOPosix
import Logging

public final class MySQLEngine: DatabaseEngine, @unchecked Sendable {
    private let eventLoopGroup: EventLoopGroup

    public init() {
        self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 2)
    }

    public var engineName: String { "MySQL" }

    public func connect(
        host: String,
        port: Int,
        username: String,
        password: String,
        database: String?
    ) async throws -> any DatabaseConnection {
        let connection = try await MySQLConnection.connect(
            to: .makeAddressResolvingHost(host, port: port),
            username: username,
            database: database ?? "",
            password: password,
            tlsConfiguration: nil,
            on: eventLoopGroup.next()
        ).get()

        return MySQLDatabaseConnection(connection: connection)
    }

    deinit {
        try? eventLoopGroup.syncShutdownGracefully()
    }
}

final class MySQLDatabaseConnection: DatabaseConnection, @unchecked Sendable {
    private let connection: MySQLConnection

    init(connection: MySQLConnection) {
        self.connection = connection
    }

    var isConnected: Bool {
        get async {
            connection.channel.isActive
        }
    }

    func execute(_ query: String) async throws -> QueryResult {
        let start = ContinuousClock.now

        // MySQL rejects utility commands (USE, SET, SHOW, DESCRIBE, etc.)
        // in the prepared statement protocol. Route them through simpleQuery.
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let rows: [MySQLRow]
        if Self.isUtilityCommand(trimmed) {
            rows = try await connection.simpleQuery(trimmed).get()
        } else {
            rows = try await connection.query(trimmed, []).get()
        }

        let elapsed = ContinuousClock.now - start
        let executionTime = Double(elapsed.components.attoseconds) / 1_000_000_000_000_000_000.0

        var columns: [ColumnInfo] = []
        var resultRows: [[DatabaseValue]] = []

        if let firstRow = rows.first {
            columns = firstRow.columnDefinitions.enumerated().map { index, col in
                ColumnInfo(
                    name: col.name,
                    type: mysqlTypeName(col.columnType),
                    ordinalPosition: index
                )
            }
        }

        for row in rows {
            var values: [DatabaseValue] = []
            for column in row.columnDefinitions {
                if let stringValue = row.column(column.name)?.string {
                    values.append(.string(stringValue))
                } else {
                    values.append(.null)
                }
            }
            resultRows.append(values)
        }

        return QueryResult(
            query: query,
            columns: columns,
            rows: resultRows,
            affectedRows: nil,
            executionTime: executionTime
        )
    }

    /// Commands that MySQL does not support in the prepared statement protocol.
    /// These must be sent via COM_QUERY (simpleQuery) instead of COM_STMT_PREPARE.
    private static func isUtilityCommand(_ sql: String) -> Bool {
        let upper = sql.uppercased()
        let prefixes = [
            "USE ", "SET ", "SHOW ", "DESCRIBE ", "DESC ",
            "EXPLAIN ", "FLUSH ", "KILL ", "RESET ", "TRUNCATE ",
            "CREATE ", "DROP ", "ALTER ", "GRANT ", "REVOKE ",
            "LOCK ", "UNLOCK ", "BEGIN", "START ", "COMMIT", "ROLLBACK",
            "SAVEPOINT ", "RELEASE ",
        ]
        return prefixes.contains { upper.hasPrefix($0) || upper == $0.trimmingCharacters(in: .whitespaces) }
    }

    func close() async throws {
        try await connection.close().get()
    }

    func databases() async throws -> [String] {
        let result = try await execute("SHOW DATABASES")
        return result.rows.compactMap { row in
            if case .string(let name) = row.first {
                return name
            }
            return nil
        }
    }

    func tables(in database: String) async throws -> [String] {
        let result = try await execute("SHOW TABLES FROM `\(Self.escapeIdentifier(database))`")
        return result.rows.compactMap { row in
            if case .string(let name) = row.first {
                return name
            }
            return nil
        }
    }

    func columns(in table: String, database: String) async throws -> [ColumnInfo] {
        let safeDB = Self.escapeLiteral(database)
        let safeTable = Self.escapeLiteral(table)
        let result = try await execute(
            "SELECT COLUMN_NAME, DATA_TYPE, IS_NULLABLE, COLUMN_KEY, ORDINAL_POSITION " +
            "FROM INFORMATION_SCHEMA.COLUMNS " +
            "WHERE TABLE_SCHEMA = '\(safeDB)' AND TABLE_NAME = '\(safeTable)' " +
            "ORDER BY ORDINAL_POSITION"
        )
        return result.rows.enumerated().compactMap { index, row in
            guard row.count >= 5,
                  case .string(let name) = row[0],
                  case .string(let type) = row[1] else {
                return nil
            }
            let nullable: Bool
            if case .string(let n) = row[2] {
                nullable = n == "YES"
            } else {
                nullable = true
            }
            let isPK: Bool
            if case .string(let k) = row[3] {
                isPK = k == "PRI"
            } else {
                isPK = false
            }
            return ColumnInfo(
                name: name,
                type: type,
                isNullable: nullable,
                isPrimaryKey: isPK,
                ordinalPosition: index
            )
        }
    }

    func showCreateTable(_ table: String, database: String) async throws -> String {
        let safeDB = Self.escapeIdentifier(database)
        let safeTable = Self.escapeIdentifier(table)
        let rows = try await connection.simpleQuery("SHOW CREATE TABLE `\(safeDB)`.`\(safeTable)`").get()
        guard let row = rows.first,
              let createSQL = row.column("Create Table")?.string else {
            throw DatabaseError.unexpectedResult("SHOW CREATE TABLE returned no result")
        }
        return createSQL
    }

    func indexes(in table: String, database: String) async throws -> [IndexInfo] {
        let safeTable = Self.escapeIdentifier(table)
        let safeDB = Self.escapeIdentifier(database)
        let rows = try await connection.simpleQuery("SHOW INDEX FROM `\(safeTable)` FROM `\(safeDB)`").get()
        return rows.compactMap { row in
            guard let keyName = row.column("Key_name")?.string,
                  let columnName = row.column("Column_name")?.string,
                  let indexType = row.column("Index_type")?.string else {
                return nil
            }
            let nonUnique = row.column("Non_unique")?.string ?? "1"
            let seqInIndex = Int(row.column("Seq_in_index")?.string ?? "1") ?? 1
            return IndexInfo(
                name: keyName,
                columnName: columnName,
                isUnique: nonUnique == "0",
                type: indexType,
                sequenceInIndex: seqInIndex
            )
        }
    }

    func foreignKeys(in table: String, database: String) async throws -> [ForeignKeyInfo] {
        let safeDB = Self.escapeLiteral(database)
        let safeTable = Self.escapeLiteral(table)
        let result = try await execute(
            "SELECT CONSTRAINT_NAME, COLUMN_NAME, REFERENCED_TABLE_NAME, REFERENCED_COLUMN_NAME, ORDINAL_POSITION " +
            "FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE " +
            "WHERE TABLE_SCHEMA = '\(safeDB)' AND TABLE_NAME = '\(safeTable)' AND REFERENCED_TABLE_NAME IS NOT NULL " +
            "ORDER BY CONSTRAINT_NAME, ORDINAL_POSITION"
        )
        return result.rows.compactMap { row in
            guard row.count >= 5,
                  case .string(let constraintName) = row[0],
                  case .string(let columnName) = row[1],
                  case .string(let refTable) = row[2],
                  case .string(let refColumn) = row[3] else {
                return nil
            }
            let ordinal: Int
            if case .string(let pos) = row[4] {
                ordinal = Int(pos) ?? 0
            } else {
                ordinal = 0
            }
            return ForeignKeyInfo(
                constraintName: constraintName,
                columnName: columnName,
                referencedTable: refTable,
                referencedColumn: refColumn,
                ordinalPosition: ordinal
            )
        }
    }

    func tableStatus(in database: String) async throws -> [TableStatus] {
        let safeDB = Self.escapeIdentifier(database)
        let rows = try await connection.simpleQuery("SHOW TABLE STATUS FROM `\(safeDB)`").get()
        return rows.compactMap { row in
            guard let name = row.column("Name")?.string else {
                return nil
            }
            let engine = row.column("Engine")?.string
            let rowCount = Int(row.column("Rows")?.string ?? "0") ?? 0
            let dataLength = Int(row.column("Data_length")?.string ?? "0") ?? 0
            let collation = row.column("Collation")?.string
            return TableStatus(
                name: name,
                engine: engine,
                rowCount: rowCount,
                dataLength: dataLength,
                collation: collation
            )
        }
    }

    func rowCount(table: String, database: String) async throws -> Int {
        let safeDB = Self.escapeIdentifier(database)
        let safeTable = Self.escapeIdentifier(table)
        let result = try await execute("SELECT COUNT(*) FROM `\(safeDB)`.`\(safeTable)`")
        guard let firstRow = result.rows.first,
              let firstValue = firstRow.first else {
            return 0
        }
        switch firstValue {
        case .string(let s): return Int(s) ?? 0
        case .int(let i): return Int(i)
        default: return 0
        }
    }

    /// Escapes a MySQL identifier (database/table/column name) for use inside backticks.
    /// Doubles any existing backticks so `db`name` becomes `db``name`.
    private static func escapeIdentifier(_ value: String) -> String {
        value.replacingOccurrences(of: "`", with: "``")
    }

    /// Escapes a string literal for use inside single quotes in SQL.
    /// Doubles single quotes and escapes backslashes.
    private static func escapeLiteral(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "''")
    }

    private func mysqlTypeName(_ type: MySQLProtocol.DataType) -> String {
        switch type {
        case .varchar, .varString, .string: return "VARCHAR"
        case .long, .longlong: return "INT"
        case .tiny: return "TINYINT"
        case .short: return "SMALLINT"
        case .int24: return "MEDIUMINT"
        case .float: return "FLOAT"
        case .double: return "DOUBLE"
        case .decimal, .newdecimal: return "DECIMAL"
        case .date: return "DATE"
        case .datetime, .datetime2: return "DATETIME"
        case .timestamp, .timestamp2: return "TIMESTAMP"
        case .time, .time2: return "TIME"
        case .blob: return "BLOB"
        case .bit: return "BIT"
        case .json: return "JSON"
        case .enum: return "ENUM"
        case .set: return "SET"
        case .null: return "NULL"
        default: return "UNKNOWN"
        }
    }
}
