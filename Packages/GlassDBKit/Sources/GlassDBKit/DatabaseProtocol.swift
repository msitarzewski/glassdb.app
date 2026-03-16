//
//  DatabaseProtocol.swift
//  GlassDBKit
//
//  Protocol abstraction for database engines (MySQL, PostgreSQL, etc.)
//

import Foundation

public enum DatabaseError: Error, LocalizedError {
    case unexpectedResult(String)

    public var errorDescription: String? {
        switch self {
        case .unexpectedResult(let message): return message
        }
    }
}

public protocol DatabaseEngine: Sendable {
    func connect(
        host: String,
        port: Int,
        username: String,
        password: String,
        database: String?
    ) async throws -> any DatabaseConnection

    var engineName: String { get }
}

public protocol DatabaseConnection: Sendable {
    var isConnected: Bool { get async }

    func execute(_ query: String) async throws -> QueryResult
    func close() async throws

    func databases() async throws -> [String]
    func tables(in database: String) async throws -> [String]
    func columns(in table: String, database: String) async throws -> [ColumnInfo]
    func showCreateTable(_ table: String, database: String) async throws -> String
    func indexes(in table: String, database: String) async throws -> [IndexInfo]
    func foreignKeys(in table: String, database: String) async throws -> [ForeignKeyInfo]
    func tableStatus(in database: String) async throws -> [TableStatus]
    func rowCount(table: String, database: String) async throws -> Int
}
