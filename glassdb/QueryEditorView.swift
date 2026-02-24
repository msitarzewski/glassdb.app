//
//  QueryEditorView.swift
//  glassdb
//
//  SQL query editor window with execution and results
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
    @State private var errorMessage: String?

    private var session: DatabaseSession? {
        sessionManager.session(for: sessionID)
    }

    var body: some View {
        VStack(spacing: 0) {
            editorArea
            Divider()
            resultsArea
        }
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 24))
        .navigationTitle(session?.connectionConfig.name ?? "Query Editor")
        .ornament(attachmentAnchor: .scene(.bottom)) {
            editorToolbar
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

            TextEditor(text: $queryText)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(16)
                .frame(minHeight: 200)
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

            ScrollView([.horizontal, .vertical]) {
                Grid(alignment: .leading, horizontalSpacing: 0, verticalSpacing: 0) {
                    // Header
                    GridRow {
                        ForEach(result.columns) { col in
                            Text(col.name)
                                .font(.caption.bold())
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .frame(minWidth: 100, alignment: .leading)
                                .background(.ultraThinMaterial)
                        }
                    }

                    Divider()

                    // Rows
                    ForEach(Array(result.rows.prefix(100).enumerated()), id: \.offset) { _, row in
                        GridRow {
                            ForEach(Array(row.enumerated()), id: \.offset) { _, value in
                                Text(value.displayString)
                                    .font(.system(.caption, design: .monospaced))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .frame(minWidth: 100, alignment: .leading)
                                    .foregroundStyle(value.isNull ? .tertiary : .primary)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Toolbar Ornament

    private var editorToolbar: some View {
        HStack(spacing: 16) {
            Button {
                Task { await executeQuery() }
            } label: {
                Label("Execute", systemImage: "play.fill")
            }
            .disabled(queryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isExecuting)
            .keyboardShortcut(.return, modifiers: .command)

            Divider()
                .frame(height: 20)

            Button {
                queryText = ""
                currentResult = nil
            } label: {
                Label("Clear", systemImage: "trash")
            }
            .disabled(queryText.isEmpty && currentResult == nil)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .glassBackgroundEffect()
    }

    // MARK: - Execution

    private func executeQuery() async {
        let sql = queryText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sql.isEmpty else { return }

        isExecuting = true
        errorMessage = nil

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
