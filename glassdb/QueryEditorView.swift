//
//  QueryEditorView.swift
//  glassdb
//
//  SQL query editor with execution and inline results
//

import SwiftUI
import GlassDBKit

struct QueryEditorView: View {
    let sessionID: UUID

    @Environment(DatabaseSessionManager.self) private var sessionManager
    @Environment(SettingsManager.self) private var settingsManager
    @Environment(\.openWindow) private var openWindow

    @State private var queryText = ""
    @State private var currentResult: QueryResult?
    @State private var isExecuting = false

    private var session: DatabaseSession? {
        sessionManager.session(for: sessionID)
    }

    var body: some View {
        Group {
            if session != nil {
                VStack(spacing: 0) {
                    editorArea
                    Divider()
                    resultsArea
                }
            } else {
                ContentUnavailableView(
                    "Session Disconnected",
                    systemImage: "cable.connector.slash",
                    description: Text("This database session is no longer active.")
                )
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    Task { await executeQuery() }
                } label: {
                    Label("Execute", systemImage: "play.fill")
                }
                .disabled(queryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isExecuting)
                .keyboardShortcut(.return, modifiers: .command)
                .accessibilityHint("Keyboard shortcut: Command Return")

                Button {
                    queryText = ""
                    currentResult = nil
                } label: {
                    Label("Clear", systemImage: "trash")
                }
                .disabled(queryText.isEmpty && currentResult == nil)
            }
        }
    }

    // MARK: - Editor

    private var editorArea: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Query")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Spacer()
                if let session, let db = session.currentDatabase {
                    Text(db)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial, in: Capsule())
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            HighlightedTextEditor(
                text: $queryText,
                fontSize: CGFloat(settingsManager.editorFontSize)
            )
            .frame(minHeight: 200)
            .accessibilityLabel("SQL query editor")
        }
    }

    // MARK: - Results

    @ViewBuilder
    private var resultsArea: some View {
        if isExecuting {
            VStack(spacing: 12) {
                ProgressView()
                Text("Executing query...")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 200)
        } else if let result = currentResult {
            if let error = result.error {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title)
                        .foregroundStyle(.red)
                    Text(error)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, minHeight: 200)
                .padding()
            } else {
                inlineResultsGrid(result)
            }
        } else {
            ContentUnavailableView(
                "No Results",
                systemImage: "text.page",
                description: Text("Write a query and press Execute.")
            )
            .frame(minHeight: 200)
        }
    }

    private func inlineResultsGrid(_ result: QueryResult) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("\(result.rowCount) rows")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("in \(String(format: "%.3f", result.executionTime))s")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    openWindow(id: "results", value: result.id)
                } label: {
                    Label("Detach", systemImage: "rectangle.portrait.and.arrow.right")
                        .font(.caption)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .accessibilityElement(children: .combine)

            GeometryReader { geometry in
                let widths = inlineColumnWidths(result: result)
                let totalDataWidth = widths.reduce(0, +)
                let fillerWidth = max(0, geometry.size.width - totalDataWidth)
                let rowHeight: CGFloat = 30

                ScrollView([.horizontal, .vertical]) {
                    LazyVStack(alignment: .leading, spacing: 0, pinnedViews: .sectionHeaders) {
                        Section {
                            ForEach(Array(result.rows.prefix(100).enumerated()), id: \.offset) { rowIndex, row in
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
                                .background(rowIndex.isMultiple(of: 2) ? Color.clear : Color.primary.opacity(0.02))
                            }
                        } header: {
                            HStack(spacing: 0) {
                                ForEach(Array(result.columns.enumerated()), id: \.offset) { colIndex, col in
                                    Text(col.name)
                                        .font(.caption.bold())
                                        .lineLimit(1)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .frame(width: widths[colIndex], alignment: .leading)
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
    }

    private func inlineColumnWidths(result: QueryResult) -> [CGFloat] {
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

    // MARK: - Execution

    private func executeQuery() async {
        let sql = queryText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sql.isEmpty else { return }

        isExecuting = true

        do {
            currentResult = try await sessionManager.executeQuery(sql, sessionID: sessionID)
        } catch {
            currentResult = QueryResult(
                query: sql,
                executionTime: 0,
                error: error.localizedDescription
            )
        }

        isExecuting = false
    }
}
