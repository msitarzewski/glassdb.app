//
//  DatabaseProtocol.swift
//  GlassDBKit
//
//  Protocol abstraction for database engines (MySQL, PostgreSQL, etc.)
//

import Foundation

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
}
