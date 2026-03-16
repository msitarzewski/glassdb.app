//
//  DataExporter.swift
//  glassdb
//
//  CSV export for query results and table data.
//

import SwiftUI
import UniformTypeIdentifiers
import GlassDBKit

struct CSVDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }

    let csv: String

    init(result: QueryResult) {
        var lines: [String] = []

        // Header row
        let header = result.columns.map { Self.escapeCSV($0.name) }.joined(separator: ",")
        lines.append(header)

        // Data rows
        for row in result.rows {
            let line = row.map { Self.escapeCSV($0.displayString) }.joined(separator: ",")
            lines.append(line)
        }

        csv = lines.joined(separator: "\n")
    }

    init(configuration: ReadConfiguration) throws {
        csv = ""
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = csv.data(using: .utf8) ?? Data()
        return FileWrapper(regularFileWithContents: data)
    }

    private static func escapeCSV(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return value
    }
}
