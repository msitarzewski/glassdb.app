//
//  GlassDBKitTests.swift
//  GlassDBKit
//

import Testing
@testable import GlassDBKit

@Suite struct QueryResultTests {
    @Test func queryResultCreation() {
        let result = QueryResult(
            query: "SELECT 1",
            columns: [
                ColumnInfo(name: "1", type: "INT")
            ],
            rows: [[.int(1)]],
            executionTime: 0.001
        )
        #expect(result.rowCount == 1)
        #expect(result.columnCount == 1)
        #expect(!result.isError)
    }

    @Test func databaseValueDisplay() {
        #expect(DatabaseValue.string("hello").displayString == "hello")
        #expect(DatabaseValue.int(42).displayString == "42")
        #expect(DatabaseValue.null.displayString == "NULL")
        #expect(DatabaseValue.null.isNull)
        #expect(!DatabaseValue.string("test").isNull)
    }

    @Test func errorResult() {
        let result = QueryResult(
            query: "INVALID SQL",
            executionTime: 0,
            error: "Syntax error"
        )
        #expect(result.isError)
        #expect(result.rowCount == 0)
    }
}
