//
//  SQLiteAdapter.swift
//  GlassDBKit
//
//  Native sqlite3 adapter for local database files.
//

import Foundation
import SQLite3

public final class SQLiteEngine: DatabaseEngine, Sendable {
    public init() {}

    public var engineName: String { "SQLite" }
    public var dialect: DatabaseDialect { .sqlite }
    public var capabilities: Set<DatabaseCapability> {
        [
            .transactions, .parameterBinding, .queryTimeout, .cancellation,
            .metadata, .schemas, .indexes, .foreignKeys,
            .createTableDefinition, .explain, .serverVersion,
        ]
    }

    /// Opens an SQLite database without forcing filesystem state into network fields.
    public func connect(path: String, readOnly: Bool = false) async throws -> any DatabaseConnection {
        try SQLiteDatabaseConnection(path: path, readOnly: readOnly)
    }

    /// Compatibility with `DatabaseEngine`. `database` is the SQLite file path;
    /// when it is omitted, `host` is used as the path. Credentials and ports have
    /// no meaning for SQLite and must remain empty/zero.
    public func connect(
        host: String,
        port: Int,
        username: String,
        password: String,
        database: String?,
        tlsPolicy: DatabaseTLSPolicy
    ) async throws -> any DatabaseConnection {
        guard tlsPolicy == .disabled else {
            throw DatabaseError.unsupportedCapability(.transportTLS, engine: engineName)
        }
        guard port == 0, username.isEmpty, password.isEmpty else {
            throw DatabaseError.unexpectedResult(
                "SQLite uses a local file path and does not accept a port or credentials."
            )
        }
        let path = database.flatMap { $0.isEmpty ? nil : $0 } ?? host
        guard !path.isEmpty else {
            throw DatabaseError.unexpectedResult("An SQLite database path is required.")
        }
        return try await connect(path: path)
    }
}

final class SQLiteDatabaseConnection: DatabaseConnection, @unchecked Sendable {
    let engineName = "SQLite"
    let dialect: DatabaseDialect = .sqlite
    let capabilities: Set<DatabaseCapability> = [
        .transactions, .parameterBinding, .queryTimeout, .cancellation,
        .metadata, .schemas, .indexes, .foreignKeys,
        .createTableDefinition, .explain, .serverVersion,
    ]
    let identifierQuoteCharacter: Character = "\""

    private let operationLock = NSLock()
    private let stateLock = NSLock()
    private var database: OpaquePointer?
    private var connected = false

    init(path: String, readOnly: Bool) throws {
        let flags = readOnly
            ? SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX
            : SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX
        var handle: OpaquePointer?
        let status = sqlite3_open_v2(path, &handle, flags, nil)
        guard status == SQLITE_OK, let handle else {
            let message = handle.map { String(cString: sqlite3_errmsg($0)) }
                ?? "SQLite could not open the database."
            if let handle { sqlite3_close_v2(handle) }
            throw DatabaseError.unexpectedResult(message)
        }
        database = handle
        connected = true
        sqlite3_extended_result_codes(handle, 1)
        sqlite3_busy_timeout(handle, 5_000)
        let pragmaStatus = sqlite3_exec(handle, "PRAGMA foreign_keys = ON", nil, nil, nil)
        guard pragmaStatus == SQLITE_OK else {
            let message = String(cString: sqlite3_errmsg(handle))
            sqlite3_close_v2(handle)
            database = nil
            connected = false
            throw DatabaseError.unexpectedResult(message)
        }
    }

    var isConnected: Bool {
        get async { stateLock.withLock { connected } }
    }

    func execute(_ query: String, parameters: [DatabaseValue]) async throws -> QueryResult {
        try await execute(query, parameters: parameters, timeout: nil)
    }

    func execute(
        _ query: String,
        parameters: [DatabaseValue],
        timeout: Duration?
    ) async throws -> QueryResult {
        try Task.checkCancellation()
        guard !query.utf8.contains(0) else {
            throw DatabaseError.unexpectedResult("SQLite query text cannot contain NUL bytes.")
        }
        let timeoutState = SQLiteTimeoutState()
        let timeoutTask: DispatchWorkItem?
        if let timeout {
            let nanoseconds = Self.timeoutNanoseconds(timeout)
            guard nanoseconds > 0 else { throw DatabaseError.queryTimedOut }
            let task = DispatchWorkItem { [weak self, timeoutState] in
                timeoutState.markFired()
                self?.interrupt()
            }
            DispatchQueue.global(qos: .userInitiated).asyncAfter(
                deadline: .now() + .nanoseconds(Int(clamping: nanoseconds)),
                execute: task
            )
            timeoutTask = task
        } else {
            timeoutTask = nil
        }

        return try await withTaskCancellationHandler {
            defer { timeoutTask?.cancel() }
            let result = try await Task.detached(priority: .userInitiated) { [self] in
                try executeSynchronously(
                    query,
                    parameters: parameters,
                    timeoutState: timeoutState
                )
            }.value
            try Task.checkCancellation()
            return result
        } onCancel: { [weak self] in
            self?.interrupt()
        }
    }

    func cancelCurrentQuery() async throws {
        interrupt()
    }

    func beginTransaction() async throws {
        _ = try await execute("BEGIN IMMEDIATE", parameters: [])
    }

    func commitTransaction() async throws {
        _ = try await execute("COMMIT", parameters: [])
    }

    func rollbackTransaction() async throws {
        _ = try await execute("ROLLBACK", parameters: [])
    }

    func close() async throws {
        try operationLock.withLock {
            guard let database else { return }
            let status = sqlite3_close_v2(database)
            guard status == SQLITE_OK else {
                throw DatabaseError.unexpectedResult(String(cString: sqlite3_errmsg(database)))
            }
            self.database = nil
            stateLock.withLock { connected = false }
        }
    }

    func databases() async throws -> [String] {
        let result = try await execute("PRAGMA database_list", parameters: [])
        return result.rows.compactMap { row in
            guard row.count > 1 else { return nil }
            return row[1].displayString
        }
    }

    func tables(in database: String) async throws -> [String] {
        let result = try await execute(
            """
            SELECT name
            FROM \(quotedIdentifier(database)).sqlite_schema
            WHERE type IN ('table', 'view') AND name NOT LIKE 'sqlite_%'
            ORDER BY name
            """,
            parameters: []
        )
        return result.rows.compactMap { $0.first?.displayString }
    }

    func columns(in table: String, database: String) async throws -> [ColumnInfo] {
        let result = try await execute(
            "PRAGMA \(quotedIdentifier(database)).table_xinfo(\(quotedIdentifier(table)))",
            parameters: []
        )
        return result.rows.map { row in
            let primaryKeyPosition = Int(row[safe: 5]?.displayString ?? "0") ?? 0
            let hidden = Int(row[safe: 6]?.displayString ?? "0") ?? 0
            return ColumnInfo(
                name: row[safe: 1]?.displayString ?? "",
                type: row[safe: 2]?.displayString ?? "",
                isNullable: row[safe: 3]?.displayString != "1",
                isPrimaryKey: primaryKeyPosition > 0,
                ordinalPosition: Int(row[safe: 0]?.displayString ?? "0") ?? 0,
                sourceSchema: database,
                sourceTable: table,
                defaultValue: row[safe: 4].flatMap { $0.isNull ? nil : $0.displayString },
                isGenerated: hidden == 2 || hidden == 3
            )
        }
    }

    func showCreateTable(_ table: String, database: String) async throws -> String {
        let result = try await execute(
            """
            SELECT sql FROM \(quotedIdentifier(database)).sqlite_schema
            WHERE type = 'table' AND name = ?
            """,
            parameters: [.string(table)]
        )
        guard let sql = result.rows.first?.first?.displayString else {
            throw DatabaseError.unexpectedResult("SQLite did not return a CREATE TABLE statement.")
        }
        return sql
    }

    func indexes(in table: String, database: String) async throws -> [IndexInfo] {
        let list = try await execute(
            "PRAGMA \(quotedIdentifier(database)).index_list(\(quotedIdentifier(table)))",
            parameters: []
        )
        var indexes: [IndexInfo] = []
        for indexRow in list.rows {
            guard let name = indexRow[safe: 1]?.displayString else { continue }
            let unique = indexRow[safe: 2]?.displayString == "1"
            let detail = try await execute(
                "PRAGMA \(quotedIdentifier(database)).index_info(\(quotedIdentifier(name)))",
                parameters: []
            )
            if detail.rows.isEmpty {
                indexes.append(
                    IndexInfo(
                        name: name,
                        columnName: "<expression>",
                        isUnique: unique,
                        type: "BTREE",
                        sequenceInIndex: 1
                    )
                )
            } else {
                for row in detail.rows {
                    let columnName = row[safe: 2]?.displayString ?? "<expression>"
                    let position = Int(row[safe: 0]?.displayString ?? "0") ?? 0
                    indexes.append(IndexInfo(
                        name: name,
                        columnName: columnName,
                        isUnique: unique,
                        type: "BTREE",
                        sequenceInIndex: position + 1
                    ))
                }
            }
        }
        return indexes
    }

    func foreignKeys(in table: String, database: String) async throws -> [ForeignKeyInfo] {
        let result = try await execute(
            "PRAGMA \(quotedIdentifier(database)).foreign_key_list(\(quotedIdentifier(table)))",
            parameters: []
        )
        return result.rows.map { row in
            ForeignKeyInfo(
                constraintName: "fk_\(row[safe: 0]?.displayString ?? "0")",
                columnName: row[safe: 3]?.displayString ?? "",
                referencedTable: row[safe: 2]?.displayString ?? "",
                referencedColumn: row[safe: 4]?.displayString ?? "",
                ordinalPosition: (Int(row[safe: 1]?.displayString ?? "0") ?? 0) + 1
            )
        }
    }

    func tableStatus(in database: String) async throws -> [TableStatus] {
        throw DatabaseError.unsupportedCapability(.tableStatistics, engine: engineName)
    }

    func rowCount(table: String, database: String) async throws -> Int {
        let result = try await execute(
            "SELECT COUNT(*) FROM \(quotedIdentifier(database)).\(quotedIdentifier(table))",
            parameters: []
        )
        guard let value = result.rows.first?.first,
              let count = Int(value.displayString) else {
            throw DatabaseError.unexpectedResult("SQLite did not return a row count.")
        }
        return count
    }

    func serverVersion() async throws -> String {
        let result = try await execute("SELECT sqlite_version()", parameters: [])
        guard let version = result.rows.first?.first?.displayString else {
            throw DatabaseError.unexpectedResult("SQLite did not return a library version.")
        }
        return version
    }

    func explain(_ query: String, parameters: [DatabaseValue]) async throws -> QueryResult {
        try await execute("EXPLAIN QUERY PLAN \(query)", parameters: parameters)
    }

    private func interrupt() {
        let handle = stateLock.withLock { database }
        if let handle { sqlite3_interrupt(handle) }
    }

    private func executeSynchronously(
        _ query: String,
        parameters: [DatabaseValue],
        timeoutState: SQLiteTimeoutState
    ) throws -> QueryResult {
        try operationLock.withLock {
            guard let database = stateLock.withLock({ self.database }) else {
                throw DatabaseError.unexpectedResult("The SQLite connection is closed.")
            }
            let start = ContinuousClock.now
            var statement: OpaquePointer?
            var trailingSQL = ""
            let prepareStatus = query.withCString { queryBytes in
                var tail: UnsafePointer<CChar>?
                let status = sqlite3_prepare_v3(
                    database,
                    queryBytes,
                    -1,
                    UInt32(SQLITE_PREPARE_PERSISTENT),
                    &statement,
                    &tail
                )
                // SQLite's tail pointer aliases the input buffer. Capture it while
                // Swift is still keeping that buffer alive so additional statements
                // cannot disappear when the temporary C string is released.
                if let tail {
                    trailingSQL = String(cString: tail)
                }
                return status
            }
            guard prepareStatus == SQLITE_OK, let statement else {
                throw Self.sqliteError(database)
            }
            defer { sqlite3_finalize(statement) }

            if !trailingSQL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                throw DatabaseError.unexpectedResult(
                    "SQLite execute accepts one statement; split scripts before execution."
                )
            }
            guard sqlite3_bind_parameter_count(statement) == Int32(parameters.count) else {
                throw DatabaseError.unsupportedParameter(
                    "Expected \(sqlite3_bind_parameter_count(statement)) values, received \(parameters.count)."
                )
            }
            for (offset, value) in parameters.enumerated() {
                try Self.bind(value, at: Int32(offset + 1), to: statement, database: database)
            }

            let columnCount = Int(sqlite3_column_count(statement))
            var columns: [ColumnInfo] = []
            if columnCount > 0 {
                columns = (0..<columnCount).map { index in
                    let name = sqlite3_column_name(statement, Int32(index)).map(String.init(cString:)) ?? ""
                    let type = sqlite3_column_decltype(statement, Int32(index)).map(String.init(cString:)) ?? ""
                    return ColumnInfo(name: name, type: type, ordinalPosition: index)
                }
            }

            var rows: [[DatabaseValue]] = []
            while true {
                let stepStatus = sqlite3_step(statement)
                switch stepStatus {
                case SQLITE_ROW:
                    rows.append((0..<columnCount).map { index in
                        Self.value(from: statement, column: Int32(index))
                    })
                case SQLITE_DONE:
                    let elapsed = ContinuousClock.now - start
                    let readOnly = sqlite3_stmt_readonly(statement) != 0
                    let affected = readOnly ? nil : UInt64(max(0, sqlite3_changes64(database)))
                    let command = query.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                    let insertID = (command.hasPrefix("INSERT") || command.hasPrefix("REPLACE"))
                        ? UInt64(max(0, sqlite3_last_insert_rowid(database)))
                        : nil
                    return QueryResult(
                        query: query,
                        columns: columns,
                        rows: rows,
                        affectedRows: affected,
                        lastInsertID: insertID,
                        executionTime: Self.seconds(elapsed)
                    )
                case SQLITE_INTERRUPT:
                    if timeoutState.didFire { throw DatabaseError.queryTimedOut }
                    throw CancellationError()
                default:
                    throw Self.sqliteError(database)
                }
            }
        }
    }

    static func bind(
        _ value: DatabaseValue,
        at index: Int32,
        to statement: OpaquePointer,
        database: OpaquePointer
    ) throws {
        let status: Int32
        switch value {
        case .string(let value), .decimal(let value), .json(let value):
            status = try bindText(value, at: index, to: statement)
        case .temporal(let value):
            status = try bindText(value.rawValue, at: index, to: statement)
        case .int(let value):
            status = sqlite3_bind_int64(statement, index, value)
        case .uint(let value):
            guard value <= UInt64(Int64.max) else {
                throw DatabaseError.unsupportedParameter(
                    "SQLite INTEGER is signed; \(value) exceeds its 64-bit range."
                )
            }
            status = sqlite3_bind_int64(statement, index, Int64(value))
        case .double(let value):
            status = sqlite3_bind_double(statement, index, value)
        case .data(let value), .bit(let value):
            status = value.withUnsafeBytes { bytes in
                sqlite3_bind_blob(statement, index, bytes.baseAddress, Int32(bytes.count), SQLITE_TRANSIENT)
            }
        case .null:
            status = sqlite3_bind_null(statement, index)
        case .date(let value):
            status = try bindText(ISO8601DateFormatter().string(from: value), at: index, to: statement)
        case .bool(let value):
            status = sqlite3_bind_int(statement, index, value ? 1 : 0)
        }
        guard status == SQLITE_OK else { throw sqliteError(database) }
    }

    private static func bindText(
        _ value: String,
        at index: Int32,
        to statement: OpaquePointer
    ) throws -> Int32 {
        let utf8 = value.utf8CString
        let byteCount = utf8.count - 1
        guard byteCount <= Int(Int32.max) else {
            throw DatabaseError.unsupportedParameter("SQLite text values cannot exceed 2 GiB.")
        }
        return utf8.withUnsafeBufferPointer { bytes in
            sqlite3_bind_text(
                statement,
                index,
                bytes.baseAddress,
                Int32(byteCount),
                SQLITE_TRANSIENT
            )
        }
    }

    static func value(from statement: OpaquePointer, column: Int32) -> DatabaseValue {
        switch sqlite3_column_type(statement, column) {
        case SQLITE_INTEGER:
            return .int(sqlite3_column_int64(statement, column))
        case SQLITE_FLOAT:
            return .double(sqlite3_column_double(statement, column))
        case SQLITE_TEXT:
            guard let text = sqlite3_column_text(statement, column) else { return .null }
            let count = Int(sqlite3_column_bytes(statement, column))
            let data = Data(bytes: text, count: count)
            if let value = String(data: data, encoding: .utf8) {
                return .string(value)
            }
            return .data(data)
        case SQLITE_BLOB:
            let count = Int(sqlite3_column_bytes(statement, column))
            guard count > 0, let bytes = sqlite3_column_blob(statement, column) else {
                return .data(Data())
            }
            return .data(Data(bytes: bytes, count: count))
        default:
            return .null
        }
    }

    static func sqliteError(_ database: OpaquePointer) -> DatabaseError {
        .unexpectedResult(String(cString: sqlite3_errmsg(database)))
    }

    static func timeoutNanoseconds(_ duration: Duration) -> Int64 {
        let components = duration.components
        let seconds = components.seconds.multipliedReportingOverflow(by: 1_000_000_000)
        guard !seconds.overflow else { return Int64.max }
        return max(0, seconds.partialValue + components.attoseconds / 1_000_000_000)
    }

    static func seconds(_ duration: Duration) -> Double {
        let components = duration.components
        return Double(components.seconds)
            + Double(components.attoseconds) / 1_000_000_000_000_000_000
    }

    deinit {
        if let database { sqlite3_close_v2(database) }
    }
}

private final class SQLiteTimeoutState: @unchecked Sendable {
    private let lock = NSLock()
    private var fired = false

    var didFire: Bool { lock.withLock { fired } }
    func markFired() { lock.withLock { fired = true } }
}

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
