//
//  ResultsGridView.swift
//  glassdb
//
//  Detachable results grid window — pin query results in spatial space
//

import SwiftUI
import GlassDBKit

struct ResultsGridView: View {
    let resultSetID: UUID

    @Environment(DatabaseSessionManager.self) private var sessionManager

    private var result: QueryResult? {
        for (_, session) in sessionManager.sessions {
            if let r = session.queryHistory.first(where: { $0.id == resultSetID }) {
                return r
            }
        }
        return nil
    }

    var body: some View {
        Group {
            if let result {
                VStack(alignment: .leading, spacing: 0) {
                    resultHeader(result)
                    Divider()
                    resultGrid(result)
                }
            } else {
                ContentUnavailableView(
                    "Result Not Found",
                    systemImage: "tablecells",
                    description: Text("This result set is no longer available.")
                )
            }
        }
    }

    private func resultHeader(_ result: QueryResult) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(result.query)
                    .font(.system(.caption, design: .monospaced))
                    .lineLimit(2)
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    Label("\(result.rowCount) rows", systemImage: "tablecells")
                    Label("\(result.columnCount) columns", systemImage: "rectangle.split.3x1")
                    Label(String(format: "%.3fs", result.executionTime), systemImage: "clock")
                }
                .font(.caption2)
                .foregroundStyle(.tertiary)
            }
            Spacer()
        }
        .padding(16)
        .accessibilityElement(children: .combine)
    }

    private func resultGrid(_ result: QueryResult) -> some View {
        ScrollView([.horizontal, .vertical]) {
            Grid(alignment: .leading, horizontalSpacing: 0, verticalSpacing: 0) {
                // Header row
                GridRow {
                    ForEach(result.columns) { col in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(col.name)
                                .font(.caption.bold())
                            Text(col.type)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .frame(minWidth: 120, alignment: .leading)
                        .background(.ultraThinMaterial)
                        .accessibilityElement(children: .combine)
                        .accessibilityAddTraits(.isHeader)
                    }
                }

                Divider()

                // Data rows
                ForEach(Array(result.rows.enumerated()), id: \.offset) { rowIndex, row in
                    GridRow {
                        ForEach(Array(row.enumerated()), id: \.offset) { colIndex, value in
                            Text(value.displayString)
                                .font(.system(.caption, design: .monospaced))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .frame(minWidth: 120, alignment: .leading)
                                .foregroundStyle(value.isNull ? .tertiary : .primary)
                                .accessibilityLabel("\(result.columns[colIndex].name): \(value.isNull ? "null" : value.displayString)")
                        }
                    }
                    .background(rowIndex % 2 == 0 ? Color.clear : Color.primary.opacity(0.02))
                }
            }
        }
        .scrollInputBehavior(.enabled, for: .look)
    }
}
