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
        GeometryReader { geometry in
            let widths = detachedColumnWidths(result: result)
            let totalDataWidth = widths.reduce(0, +)
            let fillerWidth = max(0, geometry.size.width - totalDataWidth)
            let rowHeight: CGFloat = 30
            let dataHeight = CGFloat(result.rows.count) * rowHeight
            let headerHeight: CGFloat = 44
            let fillerRowCount = max(0, Int((geometry.size.height - headerHeight - dataHeight) / rowHeight))

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
                            .background(rowIndex % 2 == 0 ? Color.clear : Color.primary.opacity(0.02))
                        }
                        // Empty filler rows
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
                            .background(globalIndex % 2 == 0 ? Color.clear : Color.primary.opacity(0.02))
                        }
                    } header: {
                        HStack(spacing: 0) {
                            ForEach(Array(result.columns.enumerated()), id: \.offset) { colIndex, col in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(col.name)
                                        .font(.caption.bold())
                                    Text(col.type)
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .frame(width: widths[colIndex], alignment: .leading)
                                .accessibilityElement(children: .combine)
                                .accessibilityAddTraits(.isHeader)
                            }
                            if fillerWidth > 0 {
                                Spacer().frame(width: fillerWidth)
                            }
                        }
                        .background(.ultraThinMaterial)
                    }
                }
            }
            .scrollIndicators(.visible)
            .scrollInputBehavior(.enabled, for: .look)
        }
    }

    private func detachedColumnWidths(result: QueryResult) -> [CGFloat] {
        guard !result.columns.isEmpty else { return [] }
        return result.columns.enumerated().map { colIndex, col -> CGFloat in
            let headerLen = CGFloat(col.name.count)
            var maxDataLen: CGFloat = 0
            for row in result.rows.prefix(50) {
                if colIndex < row.count {
                    maxDataLen = max(maxDataLen, CGFloat(row[colIndex].displayString.count))
                }
            }
            let computed = max(headerLen, maxDataLen) * 8.5 + 24
            return max(80, min(computed, 400))
        }
    }
}
