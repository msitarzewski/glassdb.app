//
//  AIAssistant.swift
//  glassdb
//
//  On-device AI SQL assistant and error explainer using Foundation Models
//

#if canImport(FoundationModels)
import FoundationModels
#endif
import SwiftUI
import os

// MARK: - Generable Structs

#if canImport(FoundationModels)
@Generable
struct SQLSuggestion {
    @Guide(description: "The exact SQL query to run")
    var query: String

    @Guide(description: "Brief explanation of what the query does")
    var explanation: String

    @Guide(description: "Risk level: safe, moderate, or destructive")
    var riskLevel: String
}

@Generable
struct SQLErrorExplanation {
    @Guide(description: "What went wrong in plain language")
    var problem: String

    @Guide(description: "SQL query to fix the issue, or empty string if no fix available")
    var suggestedFix: String

    @Guide(description: "Why this fix works or why there is no fix")
    var reasoning: String
}

@Generable
struct QuerySummary {
    @Guide(description: "Plain language description of what the SQL query does")
    var summary: String
}
#endif

// MARK: - Schema Context

struct SchemaContext: Sendable {
    var databaseName: String
    var tables: [TableInfo]

    struct TableInfo: Sendable {
        var name: String
        var columns: [ColumnInfo]
    }

    struct ColumnInfo: Sendable {
        var name: String
        var type: String
    }

    var schemaDescription: String {
        var lines = ["Database: \(databaseName)"]
        for table in tables {
            let cols = table.columns.map { "\($0.name) (\($0.type))" }.joined(separator: ", ")
            lines.append("Table \(table.name): \(cols)")
        }
        return lines.joined(separator: "\n")
    }
}

// MARK: - AIAssistant

@MainActor
@Observable
final class AIAssistant {
    var isAvailable = false
    var isProcessing = false
    var lastSuggestion: (query: String, explanation: String, riskLevel: String)?
    var lastError: (problem: String, suggestedFix: String, reasoning: String)?
    var errorMessage: String?

    func checkAvailability() {
        #if canImport(FoundationModels)
        Task {
            let availability = SystemLanguageModel.default.availability
            isAvailable = (availability == .available)
            Logger.ai.info("Foundation Models availability: \(String(describing: availability))")
        }
        #else
        isAvailable = false
        #endif
    }

    func generateSQL(prompt: String, context: SchemaContext) async {
        #if canImport(FoundationModels)
        guard isAvailable else {
            errorMessage = "AI model not available on this device."
            return
        }

        isProcessing = true
        lastSuggestion = nil
        errorMessage = nil

        do {
            let systemPrompt = """
            You are a MySQL expert. Generate a SQL query for the given request. \
            The database schema is provided for context. \
            Assess risk: "safe" for SELECT/SHOW/DESCRIBE queries, "moderate" for \
            INSERT/UPDATE, "destructive" for DELETE/DROP/TRUNCATE/ALTER.

            Schema:
            \(context.schemaDescription)
            """
            let session = LanguageModelSession(instructions: systemPrompt)

            let response = try await session.respond(
                to: prompt,
                generating: SQLSuggestion.self
            )

            let result = response.content
            lastSuggestion = (
                query: result.query,
                explanation: result.explanation,
                riskLevel: result.riskLevel
            )
            Logger.ai.info("SQL suggestion generated: \(result.query)")
        } catch {
            Logger.ai.error("SQL suggestion failed: \(error)")
            errorMessage = "Failed to generate SQL: \(error.localizedDescription)"
        }

        isProcessing = false
        #endif
    }

    func explainError(error: String, query: String, context: SchemaContext) async {
        #if canImport(FoundationModels)
        guard isAvailable else {
            errorMessage = "AI model not available on this device."
            return
        }

        isProcessing = true
        lastError = nil
        errorMessage = nil

        do {
            let systemPrompt = """
            You are a MySQL error expert. Explain the error and suggest a fix. \
            The user ran a query that produced an error. Analyze the error message \
            in the context of the database schema and suggest a corrected query.

            Schema:
            \(context.schemaDescription)
            """
            let session = LanguageModelSession(instructions: systemPrompt)

            let userPrompt = """
            Query: \(query)
            Error: \(error)
            """
            let response = try await session.respond(
                to: userPrompt,
                generating: SQLErrorExplanation.self
            )

            let result = response.content
            lastError = (
                problem: result.problem,
                suggestedFix: result.suggestedFix,
                reasoning: result.reasoning
            )
            Logger.ai.info("Error explanation generated")
        } catch {
            Logger.ai.error("Error explanation failed: \(error)")
            self.errorMessage = "Failed to explain error: \(error.localizedDescription)"
        }

        isProcessing = false
        #endif
    }

    func summarizeQuery(query: String) async -> String? {
        #if canImport(FoundationModels)
        guard isAvailable else {
            errorMessage = "AI model not available on this device."
            return nil
        }

        isProcessing = true
        errorMessage = nil

        defer { isProcessing = false }

        do {
            let systemPrompt = """
            You are a MySQL expert. Explain what the given SQL query does in plain \
            language. Be concise but thorough. Mention which tables and columns are \
            involved and what the expected result would be.
            """
            let session = LanguageModelSession(instructions: systemPrompt)

            let response = try await session.respond(
                to: query,
                generating: QuerySummary.self
            )

            let result = response.content
            Logger.ai.info("Query summary generated")
            return result.summary
        } catch {
            Logger.ai.error("Query summary failed: \(error)")
            errorMessage = "Failed to summarize query: \(error.localizedDescription)"
            return nil
        }
        #else
        return nil
        #endif
    }

    func reset() {
        lastSuggestion = nil
        lastError = nil
        errorMessage = nil
        isProcessing = false
    }
}

// MARK: - AI Assistant View

struct AIAssistantView: View {
    let aiAssistant: AIAssistant
    let schemaContext: SchemaContext
    let onRunQuery: (String) -> Void

    @State private var prompt = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                #if canImport(FoundationModels)
                assistantContent
                #else
                ContentUnavailableView(
                    "AI Not Available",
                    systemImage: "cpu",
                    description: Text("Foundation Models requires visionOS 26 or later.")
                )
                #endif
            }
            .navigationTitle("AI SQL Assistant")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .frame(width: 560, height: 480)
    }

    private var assistantContent: some View {
        VStack(spacing: 16) {
            if !aiAssistant.isAvailable {
                ContentUnavailableView(
                    "Model Unavailable",
                    systemImage: "cpu.fill",
                    description: Text("The on-device language model is not available. Check Settings > Apple Intelligence.")
                )
            } else {
                HStack(spacing: 8) {
                    TextField("Describe the query you need...", text: $prompt)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { runSuggestion() }

                    Button {
                        runSuggestion()
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                    }
                    .disabled(prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || aiAssistant.isProcessing)
                }
                .padding(.horizontal)

                if aiAssistant.isProcessing {
                    ProgressView("Thinking...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let suggestion = aiAssistant.lastSuggestion {
                    suggestionCard(suggestion)
                } else if let error = aiAssistant.errorMessage {
                    Text(error)
                        .foregroundStyle(.red)
                        .padding()
                } else {
                    ContentUnavailableView(
                        "Ask a Question",
                        systemImage: "sparkles",
                        description: Text("Describe what data you need in natural language, and AI will generate a SQL query.")
                    )
                }
            }

            Spacer()
        }
        .padding(.top, 16)
    }

    private func suggestionCard(_ suggestion: (query: String, explanation: String, riskLevel: String)) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Suggested Query")
                    .font(.headline)
                Spacer()
                riskBadge(suggestion.riskLevel)
            }

            Text(suggestion.query)
                .font(.system(.body, design: .monospaced))
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))

            Text(suggestion.explanation)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Button {
                    onRunQuery(suggestion.query)
                    dismiss()
                } label: {
                    Label("Run", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)

                Button {
                    #if canImport(UIKit)
                    UIPasteboard.general.string = suggestion.query
                    #endif
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    private func riskBadge(_ level: String) -> some View {
        let color: Color
        switch level.lowercased() {
        case "safe": color = .green
        case "moderate": color = .yellow
        case "destructive": color = .red
        default: color = .gray
        }

        return Text(level.capitalized)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.2), in: Capsule())
            .foregroundStyle(color)
    }

    private func runSuggestion() {
        let text = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        Task {
            await aiAssistant.generateSQL(prompt: text, context: schemaContext)
        }
    }
}

// MARK: - AI Error Card

struct AIErrorCard: View {
    let error: (problem: String, suggestedFix: String, reasoning: String)
    let onRunFix: (String) -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.yellow)
                Text(error.problem)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                Spacer()
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            if !error.suggestedFix.isEmpty {
                Text(error.suggestedFix)
                    .font(.system(.caption, design: .monospaced))
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 6))

                HStack(spacing: 8) {
                    Button {
                        onRunFix(error.suggestedFix)
                        onDismiss()
                    } label: {
                        Label("Run Fix", systemImage: "play.fill")
                            .font(.caption)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)

                    Button {
                        #if canImport(UIKit)
                        UIPasteboard.general.string = error.suggestedFix
                        #endif
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            Text(error.reasoning)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
        }
        .padding(14)
        .frame(maxWidth: 420)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}
