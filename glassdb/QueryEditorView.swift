//
//  QueryEditorView.swift
//  glassdb
//
//  SQL query editor with execution and inline results
//

import SwiftUI
import GlassDBKit
import UniformTypeIdentifiers

struct SQLTextDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText] }
    static var writableContentTypes: [UTType] { [.plainText] }

    var text: String

    init(text: String = "") {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              data.count <= 10 * 1_024 * 1_024,
              let text = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.text = text
    }

    var utf8Data: Data { Data(text.utf8) }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: utf8Data)
    }
}

struct QueryFailurePresentation: Equatable, Sendable {
    let title: String
    let detail: String

    init(message: String) {
        let normalized = message
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\u{0000}", with: "")
        detail = normalized.isEmpty
            ? "The database did not provide an error description."
            : String(normalized.prefix(16_384))

        let lowercase = normalized.lowercased()
        if lowercase.contains("syntax") || lowercase.contains("parse error") {
            title = "Invalid SQL Syntax"
        } else if lowercase.contains("access denied") || lowercase.contains("authentication") {
            title = "Authentication Failed"
        } else if lowercase.contains("timed out") || lowercase.contains("timeout") {
            title = "Query Timed Out"
        } else if lowercase.contains("duplicate") || lowercase.contains("unique constraint") {
            title = "Duplicate Value"
        } else if lowercase.contains("foreign key") {
            title = "Foreign Key Constraint"
        } else {
            title = "Query Failed"
        }
    }
}

struct QueryErrorCard: View {
    let error: String
    let query: String
    let schemaContext: SchemaContext
    let aiAssistant: AIAssistant?
    var summary = "The database rejected this query."
    var offersNotifications = true
    var offersAISuggestion = true
    let onUseSuggestedSQL: (String) -> Void
    let onDismiss: () -> Void

    @Environment(SettingsManager.self) private var settingsManager
    @State private var requestedAISuggestion = false
    @State private var handledNotification = false
    @State private var notificationAuthorizationFailed = false

    private var presentation: QueryFailurePresentation {
        QueryFailurePresentation(message: error)
    }

    private var suggestedSQL: String? {
        guard let raw = aiAssistant?.lastError?.suggestedFix else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if trimmed.hasPrefix("```") {
            let lines = trimmed.split(separator: "\n", omittingEmptySubsequences: false)
            return lines
                .dropFirst()
                .drop(while: { $0.trimmingCharacters(in: .whitespaces).isEmpty })
                .dropLast(lines.last?.trimmingCharacters(in: .whitespacesAndNewlines) == "```" ? 1 : 0)
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return trimmed
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title2)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.red)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(presentation.title)
                        .font(.headline)
                    Text(summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 16)

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.borderless)
                .help("Dismiss this error")
                .accessibilityLabel("Dismiss query error")
            }

            Text(presentation.detail)
                .font(.system(.callout, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 10) {
                Button {
                    PlatformClipboard.copy(presentation.detail)
                } label: {
                    Label("Copy Error", systemImage: "doc.on.doc")
                }

                if offersAISuggestion, aiAssistant?.isAvailable == true {
                    Button {
                        requestAISuggestion()
                    } label: {
                        Label("Suggest Fix", systemImage: "apple.intelligence")
                    }
                    .disabled(aiAssistant?.isProcessing == true || query.isEmpty)
                    .help("Ask the on-device model for a potential correction")
                }
            }
            .controlSize(.small)

            if offersNotifications, settingsManager.shouldOfferQueryFailureNotifications {
                notificationOffer
            } else if notificationAuthorizationFailed {
                Label(
                    "Notifications remain off. You can allow them in System Settings.",
                    systemImage: "bell.slash"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            if requestedAISuggestion {
                aiSuggestion
            }
        }
        .padding(20)
        .frame(maxWidth: 760, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.red.opacity(0.22), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.08), radius: 18, y: 8)
        .padding(24)
        .task(id: error) {
            guard offersNotifications,
                  !handledNotification,
                  settingsManager.queryFailureNotificationsEnabled else { return }
            handledNotification = true
            await settingsManager.postQueryFailureNotification()
        }
    }

    private var notificationOffer: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Get notified when a query fails", systemImage: "bell.badge")
                .font(.subheadline.weight(.semibold))
            Text("Notifications contain no SQL, schema names, literals, or server diagnostics.")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Button("Not Now") {
                    settingsManager.declineQueryFailureNotifications()
                }
                Button("Enable Notifications") {
                    Task {
                        let enabled = await settingsManager.enableQueryFailureNotifications()
                        notificationAuthorizationFailed = !enabled
                        if enabled {
                            handledNotification = true
                            await settingsManager.postQueryFailureNotification()
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .controlSize(.small)
        }
        .padding(12)
        .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private var aiSuggestion: some View {
        Divider()
        if aiAssistant?.isProcessing == true {
            HStack(spacing: 10) {
                ProgressView()
                    .controlSize(.small)
                Text("Apple Intelligence is reviewing the query and schema metadata…")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        } else if let explanation = aiAssistant?.lastError,
                  let suggestedSQL {
            VStack(alignment: .leading, spacing: 12) {
                Label("Potential Fix", systemImage: "apple.intelligence")
                    .font(.headline)

                Text(explanation.problem)
                    .font(.callout)

                Text(suggestedSQL)
                    .font(.system(.callout, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 10))

                let safety = SQLHighlighter.safetyClassification(of: suggestedSQL)
                if safety.requiresConfirmation {
                    Label(
                        "This suggestion can modify database state and will still require confirmation.",
                        systemImage: "exclamationmark.shield"
                    )
                    .font(.caption)
                    .foregroundStyle(.orange)
                }

                HStack {
                    Button("Copy Suggested SQL", systemImage: "doc.on.doc") {
                        PlatformClipboard.copy(suggestedSQL)
                    }
                    Button("Use in Editor", systemImage: "arrow.up.doc") {
                        onUseSuggestedSQL(suggestedSQL)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .controlSize(.small)

                DisclosureGroup("Why this may work") {
                    Text(explanation.reasoning)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .padding(.top, 6)
                }
            }
        } else if let message = aiAssistant?.errorMessage {
            Label(message, systemImage: "apple.intelligence")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private func requestAISuggestion() {
        guard let aiAssistant else { return }
        requestedAISuggestion = true
        aiAssistant.reset()
        Task {
            await aiAssistant.explainError(
                error: presentation.detail,
                query: query,
                context: schemaContext
            )
        }
    }
}

private struct QueryDocumentTab: Identifiable {
    let id: UUID
    var text: String
    var selectedRange: NSRange
    var result: QueryResult?

    init(
        id: UUID = UUID(),
        text: String = "",
        selectedRange: NSRange = NSRange(location: 0, length: 0),
        result: QueryResult? = nil
    ) {
        self.id = id
        self.text = text
        self.selectedRange = selectedRange
        self.result = result
    }

    var title: String {
        let firstLine = text
            .split(whereSeparator: \.isNewline)
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let firstLine, !firstLine.isEmpty else { return "Untitled" }
        return String(firstLine.prefix(32))
    }
}

struct QueryEditorView: View {
    let sessionID: UUID
    var isWorkspaceActive = true
    var onOpenSQLEditor: (() -> Void)?

    @Environment(DatabaseSessionManager.self) private var sessionManager
    @Environment(SettingsManager.self) private var settingsManager
    @Environment(\.openWindow) private var openWindow

    @State private var queryText = ""
    @State private var selectedRange = NSRange(location: 0, length: 0)
    @State private var currentResult: QueryResult?
    @State private var tabs: [QueryDocumentTab] = [QueryDocumentTab()]
    @State private var selectedTabID: UUID?
    @State private var tabPendingClose: UUID?
    @State private var isExecuting = false
    @State private var showingHistory = false
    @State private var showingSavedQueries = false
    @State private var showingSaveQuery = false
    @State private var showingSQLImporter = false
    @State private var showingSQLExporter = false
    @State private var savedQueryName = ""
    @FocusState private var savedQueryNameFocused: Bool
    @State private var documentError: String?
    @State private var schemaCompletionIdentifiers: [String] = []
    @State private var completionLoadError: String?
    @State private var aiErrorSchemaContext: SchemaContext?
    @State private var statementsAwaitingConfirmation: [SQLStatement] = []
    @State private var showingExecutionConfirmation = false

    private var session: DatabaseSession? {
        sessionManager.session(for: sessionID)
    }

    private var normalizedSavedQueryName: String {
        savedQueryName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSaveCurrentQuery: Bool {
        !normalizedSavedQueryName.isEmpty
            && !queryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
            if isWorkspaceActive {
                #if os(macOS)
                ToolbarSpacer(.flexible, placement: databaseToolbarPlacement)
                DatabasePersistentToolbar {
                    onOpenSQLEditor?()
                }
                #endif
                ToolbarItem(placement: databaseToolbarPlacement) {
                    Button {
                        prepareCurrentStatementExecution()
                    } label: {
                        Label("Execute Statement", systemImage: "play.fill")
                    }
                    .disabled(queryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isExecuting)
                    .keyboardShortcut(.return, modifiers: .command)
                }
                .databaseHighVisibilityPriority()

                ToolbarItemGroup(placement: databaseToolbarPlacement) {
                    Button {
                        prepareScriptExecution()
                    } label: {
                        Label("Execute Script", systemImage: "play.square.stack")
                    }
                    .disabled(queryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isExecuting)
                    .keyboardShortcut(.return, modifiers: [.command, .shift])

                    Button {
                        prepareExplainExecution()
                    } label: {
                        Label("Explain Plan", systemImage: "point.3.connected.trianglepath.dotted")
                    }
                    .disabled(queryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isExecuting)
                    .keyboardShortcut("e", modifiers: [.command, .shift])

                    if isExecuting,
                       session?.connection?.capabilities.contains(.cancellation) == true {
                        Button(role: .destructive) {
                            Task { await cancelExecution() }
                        } label: {
                            Label("Cancel Query", systemImage: "stop.fill")
                        }
                    }

                    Menu {
                        Button("Open SQL Document", systemImage: "folder") {
                            showingSQLImporter = true
                        }
                        Button("Save SQL Document", systemImage: "square.and.arrow.down") {
                            showingSQLExporter = true
                        }
                        .disabled(queryText.isEmpty)
                        Divider()
                        Button("Query History", systemImage: "clock.arrow.circlepath") {
                            showingHistory = true
                        }
                        Button("Saved Queries", systemImage: "bookmark") {
                            showingSavedQueries = true
                        }
                        Divider()
                        Button("Save Current Query", systemImage: "bookmark.fill") {
                            savedQueryName = queryText
                                .split(whereSeparator: \.isNewline)
                                .first
                                .map { String($0.prefix(48)) } ?? ""
                            showingSaveQuery = true
                        }
                        .disabled(queryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    } label: {
                        Label("Queries", systemImage: "books.vertical")
                    }

                    Button {
                        queryText = ""
                        currentResult = nil
                    } label: {
                        Label("Clear", systemImage: "trash")
                    }
                    .disabled(queryText.isEmpty && currentResult == nil)

                    Button {
                        let formatted = SQLHighlighter.formatted(queryText)
                        queryText = formatted
                        selectedRange = NSRange(location: (formatted as NSString).length, length: 0)
                        saveActiveTab()
                    } label: {
                        Label("Format SQL", systemImage: "text.alignleft")
                    }
                    .disabled(queryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isExecuting)
                    .keyboardShortcut("f", modifiers: [.command, .shift])

                    Divider()

                    Button {
                        createTab()
                    } label: {
                        Label("New Query Tab", systemImage: "plus.square.on.square")
                    }
                    .disabled(isExecuting)
                    .keyboardShortcut("t", modifiers: .command)

                    Button {
                        requestCloseCurrentTab()
                    } label: {
                        Label("Close Query Tab", systemImage: "xmark.square")
                    }
                    .disabled(tabs.count == 1 || isExecuting)
                    .keyboardShortcut("w", modifiers: [.command, .shift])
                }
            }
        }
        .focusedSceneValue(
            \.databaseCommandActions,
            isWorkspaceActive ? commandActions : nil
        )
        .onAppear {
            if selectedTabID == nil {
                selectedTabID = tabs[0].id
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .glassdbOpenSQLDraft)) { notification in
            guard let request = notification.object as? SQLDraftRequest,
                  request.sessionID == sessionID else { return }
            createTab(with: request.sql)
        }
        .task(id: session?.currentDatabase) {
            await loadCompletionIdentifiers()
        }
        .fileImporter(
            isPresented: $showingSQLImporter,
            allowedContentTypes: Self.sqlDocumentTypes,
            allowsMultipleSelection: false
        ) { result in
            importSQLDocument(result)
        }
        .fileExporter(
            isPresented: $showingSQLExporter,
            document: SQLTextDocument(text: queryText),
            contentType: .plainText,
            defaultFilename: documentFilename
        ) { result in
            if case .failure(let error) = result {
                documentError = error.localizedDescription
            }
        }
        .sheet(isPresented: $showingHistory) {
            QueryHistoryView(
                connectionID: session?.connectionConfig.id,
                onSelect: { entry in
                    queryText = entry.sql
                    selectedRange = NSRange(location: (entry.sql as NSString).length, length: 0)
                    showingHistory = false
                }
            )
        }
        .sheet(isPresented: $showingSavedQueries) {
            SavedQueriesView(connectionID: session?.connectionConfig.id) { query in
                queryText = query.sql
                selectedRange = NSRange(location: (query.sql as NSString).length, length: 0)
                settingsManager.useSavedQuery(query.id)
                showingSavedQueries = false
            }
        }
        #if os(macOS)
        .sheet(isPresented: $showingSaveQuery) {
            saveQuerySheet
        }
        #else
        .alert("Save Query", isPresented: $showingSaveQuery) {
            TextField("Name", text: $savedQueryName)
            Button("Cancel", role: .cancel) {}
                .keyboardShortcut(.cancelAction)
            Button("Save") { saveCurrentQuery() }
                .keyboardShortcut(.defaultAction)
                .disabled(!canSaveCurrentQuery)
        } message: {
            Text("Saved queries remain available after the app restarts.")
        }
        #endif
        .alert("Review SQL Before Executing", isPresented: $showingExecutionConfirmation) {
            Button("Cancel", role: .cancel) {
                statementsAwaitingConfirmation = []
            }
            .keyboardShortcut(.cancelAction)
            Button("Execute", role: .destructive) {
                let statements = statementsAwaitingConfirmation
                statementsAwaitingConfirmation = []
                Task { await execute(statements) }
            }
            .help("Execute the reviewed SQL against the connected database")
        } message: {
            let classifications = Set(statementsAwaitingConfirmation.map(\.safety.displayName)).sorted()
            Text("This script contains SQL classified as \(classifications.joined(separator: ", ")). Review it carefully before continuing.")
        }
        .alert("Close Query Tab?", isPresented: .init(
            get: { tabPendingClose != nil },
            set: { if !$0 { tabPendingClose = nil } }
        )) {
            Button("Cancel", role: .cancel) { tabPendingClose = nil }
                .keyboardShortcut(.cancelAction)
            Button("Close", role: .destructive) {
                if let tabPendingClose {
                    closeTab(tabPendingClose)
                }
                tabPendingClose = nil
            }
        } message: {
            Text("This tab contains SQL that is only stored in the current workspace session.")
        }
        .alert("SQL Document Error", isPresented: .init(
            get: { documentError != nil },
            set: { if !$0 { documentError = nil } }
        )) {
            Button("OK", role: .cancel) { documentError = nil }
                .keyboardShortcut(.defaultAction)
        } message: {
            Text(documentError ?? "")
        }
    }

    #if os(macOS)
    private var saveQuerySheet: some View {
        NavigationStack {
            Form {
                Section("Saved Query") {
                    TextField("Name", text: $savedQueryName)
                        .focused($savedQueryNameFocused)
                        .onSubmit { saveCurrentQuery() }
                        .accessibilityLabel("Saved query name")
                        .help("Enter a name used to find this query later")
                    if normalizedSavedQueryName.isEmpty {
                        Label("Enter a name before saving.", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                Section("SQL Preview") {
                    Text(queryText)
                        .font(.system(.callout, design: .monospaced))
                        .lineLimit(6)
                        .textSelection(.enabled)
                }
                Section {
                    Text("Saved queries remain available after the app restarts.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Save Query")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showingSaveQuery = false }
                        .keyboardShortcut(.cancelAction)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveCurrentQuery() }
                        .keyboardShortcut(.defaultAction)
                        .disabled(!canSaveCurrentQuery)
                }
            }
        }
        .frame(width: 520, height: 400)
        .onAppear { savedQueryNameFocused = true }
    }
    #endif

    private func saveCurrentQuery() {
        guard canSaveCurrentQuery else { return }
        settingsManager.addSavedQuery(SavedQuery(
            name: normalizedSavedQueryName,
            sql: queryText,
            connectionID: session?.connectionConfig.id
        ))
        showingSaveQuery = false
    }

    private var commandActions: DatabaseCommandActions {
        let hasQuery = !queryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return DatabaseCommandActions(
            canExecute: hasQuery && !isExecuting,
            canCancel: isExecuting && session?.connection?.capabilities.contains(.cancellation) == true,
            canSave: !queryText.isEmpty,
            canCloseTab: tabs.count > 1 && !isExecuting,
            executeStatement: prepareCurrentStatementExecution,
            executeScript: prepareScriptExecution,
            explainPlan: prepareExplainExecution,
            cancel: { Task { await cancelExecution() } },
            openDocument: { showingSQLImporter = true },
            saveDocument: { showingSQLExporter = true },
            showHistory: { showingHistory = true },
            showSavedQueries: { showingSavedQueries = true },
            formatSQL: {
                let formatted = SQLHighlighter.formatted(queryText)
                queryText = formatted
                selectedRange = NSRange(location: (formatted as NSString).length, length: 0)
                saveActiveTab()
            },
            newTab: { createTab() },
            closeTab: requestCloseCurrentTab
        )
    }

    // MARK: - Editor

    private var editorArea: some View {
        VStack(alignment: .leading, spacing: 0) {
            queryTabBar

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
                fontSize: CGFloat(settingsManager.editorFontSize),
                showLineNumbers: settingsManager.showLineNumbers,
                selection: $selectedRange,
                isActive: isWorkspaceActive
            )
            .frame(minHeight: 200)
            .accessibilityLabel("SQL query editor")

            completionBar
        }
    }

    @ViewBuilder
    private var completionBar: some View {
        let suggestions = SQLHighlighter.completions(
            in: queryText,
            selectedRange: selectedRange,
            schemaIdentifiers: schemaCompletionIdentifiers
        )
        if !suggestions.isEmpty {
            ScrollView(.horizontal) {
                HStack(spacing: 6) {
                    Text("Complete")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ForEach(suggestions, id: \.self) { suggestion in
                        Button(suggestion) {
                            applyCompletion(suggestion)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
            }
            .scrollIndicators(.hidden)
        } else if let completionLoadError {
            Label(completionLoadError, systemImage: "exclamationmark.triangle")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .accessibilityLabel("Schema completion unavailable. \(completionLoadError)")
        }
    }

    private var queryTabBar: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 6) {
                ForEach(tabs) { tab in
                    let isSelected = tab.id == selectedTabID
                    HStack(spacing: 2) {
                        Button {
                            switchToTab(tab.id)
                        } label: {
                            HStack(spacing: 6) {
                            Image(systemName: "text.page")
                            Text(isSelected ? activeTabTitle : tab.title)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .frame(maxWidth: 200)
                            }
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                        }
                        .buttonStyle(.plain)
                        .databaseWorkspaceTabControlTarget()
                        .disabled(isExecuting)
                        .accessibilityLabel("Query tab \(isSelected ? activeTabTitle : tab.title)")
                        .accessibilityAddTraits(isSelected ? .isSelected : [])

                        if tabs.count > 1 {
                            Button {
                                requestCloseTab(tab.id)
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.borderless)
                            .databaseWorkspaceTabControlTarget()
                            .disabled(isExecuting)
                            .accessibilityLabel("Close \(isSelected ? activeTabTitle : tab.title)")
                        }
                    }
                    .padding(.horizontal, 4)
                    .background(
                        isSelected ? AnyShapeStyle(.regularMaterial) : AnyShapeStyle(Color.clear),
                        in: Capsule()
                    )
                }

                Button {
                    createTab()
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
                .databaseWorkspaceTabControlTarget()
                .disabled(isExecuting)
                .accessibilityLabel("New query tab")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .scrollIndicators(.hidden)
        .databaseLookScrollEnabled()
    }

    private var activeTabTitle: String {
        QueryDocumentTab(text: queryText).title
    }

    private static var sqlDocumentTypes: [UTType] {
        if let sql = UTType(filenameExtension: "sql") {
            return [sql, .plainText]
        }
        return [.plainText]
    }

    static let maximumSQLDocumentBytes = 10 * 1_024 * 1_024

    static func decodedSQLDocumentText(_ data: Data) throws -> String {
        // Recheck the bytes actually read: the file may grow after the metadata
        // preflight and before Data(contentsOf:) completes.
        guard data.count <= maximumSQLDocumentBytes else {
            throw CocoaError(.fileReadTooLarge)
        }
        guard let text = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadInapplicableStringEncoding)
        }
        return text
    }

    private var documentFilename: String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let sanitized = activeTabTitle.unicodeScalars.map { allowed.contains($0) ? Character(String($0)) : "-" }
        let basename = String(sanitized).trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return (basename.isEmpty ? "query" : basename) + ".sql"
    }

    private func importSQLDocument(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            let values = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
            guard values.isRegularFile == true,
                  let size = values.fileSize,
                  size <= Self.maximumSQLDocumentBytes else {
                throw CocoaError(.fileReadTooLarge)
            }
            let data = try Data(contentsOf: url, options: .mappedIfSafe)
            let text = try Self.decodedSQLDocumentText(data)
            createTab(with: text)
        } catch {
            documentError = error.localizedDescription
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
                ScrollView {
                    QueryErrorCard(
                        error: error,
                        query: result.query,
                        schemaContext: aiErrorSchemaContext ?? SchemaContext(
                            databaseName: session?.currentDatabase ?? "Current database",
                            tables: []
                        ),
                        aiAssistant: session?.aiAssistant,
                        onUseSuggestedSQL: { suggestedSQL in
                            queryText = suggestedSQL
                            selectedRange = NSRange(
                                location: (suggestedSQL as NSString).length,
                                length: 0
                            )
                            currentResult = nil
                            saveActiveTab()
                        },
                        onDismiss: {
                            currentResult = nil
                            saveActiveTab()
                        }
                    )
                }
                .frame(maxWidth: .infinity, minHeight: 200)
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
                if result.isTruncated, let limit = result.appliedRowLimit {
                    Text("more rows available — limited to \(limit)")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
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
                            ForEach(Array(result.rows.enumerated()), id: \.offset) { rowIndex, row in
                                HStack(spacing: 0) {
                                    ForEach(Array(row.enumerated()), id: \.offset) { colIndex, value in
                                        Text(value.displayString)
                                            .font(.system(size: settingsManager.dataGridFontSize, design: .monospaced))
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
                                .background(
                                    rowIndex.isMultiple(of: 2)
                                        ? Color.clear
                                        : Color.primary.opacity(
                                            DatabaseGlassAppearance(
                                                opacity: settingsManager.windowOpacity,
                                                blur: 0
                                            ).surfaceAlpha(strength: 0.02)
                                        )
                                )
                            }
                        } header: {
                            HStack(spacing: 0) {
                                ForEach(Array(result.columns.enumerated()), id: \.offset) { colIndex, col in
                                    Text(col.name)
                                        .font(.system(size: settingsManager.dataGridFontSize, weight: .bold, design: .monospaced))
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
                            .databaseCanvasSurface(opacity: settingsManager.windowOpacity)
                        }
                    }
                }
                .scrollIndicators(.visible)
                .databaseLookScrollEnabled()
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
            let charWidth = settingsManager.dataGridFontSize * 0.65
            let computed = max(headerLen, maxDataLen) * charWidth + 24
            return max(80, min(computed, 400))
        }
    }

    // MARK: - Execution

    private func prepareCurrentStatementExecution() {
        prepareExecution(SQLHighlighter.statementsToExecute(in: queryText, selectedRange: selectedRange))
    }

    private func prepareScriptExecution() {
        prepareExecution(SQLHighlighter.statements(in: queryText))
    }

    private func prepareExplainExecution() {
        guard let statement = SQLHighlighter.statementsToExecute(
            in: queryText,
            selectedRange: selectedRange
        ).first else { return }
        Task { await explain(statement.text) }
    }

    private func prepareExecution(_ statements: [SQLStatement]) {
        guard !statements.isEmpty else { return }
        if statements.contains(where: { $0.safety.requiresConfirmation }) {
            statementsAwaitingConfirmation = statements
            showingExecutionConfirmation = true
        } else {
            Task { await execute(statements) }
        }
    }

    private func execute(_ statements: [SQLStatement]) async {
        isExecuting = true
        defer { isExecuting = false }

        do {
            for statement in statements {
                currentResult = try await sessionManager.executeQuery(
                    statement.text,
                    sessionID: sessionID,
                    editorRowLimit: settingsManager.resultRowLimit
                )
            }
        } catch {
            currentResult = QueryResult(
                query: statements.last?.text ?? "",
                executionTime: 0,
                error: error.localizedDescription
            )
        }
        saveActiveTab()
    }

    private func explain(_ statement: String) async {
        isExecuting = true
        defer { isExecuting = false }
        do {
            currentResult = try await sessionManager.explainQuery(statement, sessionID: sessionID)
        } catch {
            currentResult = QueryResult(
                query: statement,
                executionTime: 0,
                error: error.localizedDescription
            )
        }
        saveActiveTab()
    }

    private func cancelExecution() async {
        do {
            try await sessionManager.cancelQuery(sessionID: sessionID)
        } catch {
            currentResult = QueryResult(
                query: queryText,
                executionTime: 0,
                error: error.localizedDescription
            )
        }
    }

    // MARK: - Completion

    private func loadCompletionIdentifiers() async {
        guard let connection = session?.connection else { return }
        do {
            var identifiers = Set(try await connection.databases())
            if let database = session?.currentDatabase, !database.isEmpty {
                let tables = try await connection.tables(in: database)
                identifiers.formUnion(tables)
                var tableInfos: [SchemaContext.TableInfo] = []
                await withTaskGroup(of: SchemaContext.TableInfo?.self) { group in
                    for table in tables.prefix(50) {
                        group.addTask {
                            guard let columns = try? await connection.columns(
                                in: table,
                                database: database
                            ) else { return nil }
                            return SchemaContext.TableInfo(
                                name: table,
                                columns: columns.map {
                                    SchemaContext.ColumnInfo(name: $0.name, type: $0.type)
                                }
                            )
                        }
                    }
                    for await tableInfo in group {
                        guard let tableInfo else { continue }
                        tableInfos.append(tableInfo)
                        identifiers.formUnion(tableInfo.columns.flatMap { column in
                            [column.name, "\(tableInfo.name).\(column.name)"]
                        })
                    }
                }
                aiErrorSchemaContext = SchemaContext(
                    databaseName: database,
                    tables: tableInfos.sorted {
                        $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                    }
                )
            } else {
                aiErrorSchemaContext = SchemaContext(
                    databaseName: "Current database",
                    tables: []
                )
            }
            schemaCompletionIdentifiers = identifiers.sorted {
                $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
            }
            completionLoadError = nil
        } catch {
            schemaCompletionIdentifiers = []
            aiErrorSchemaContext = SchemaContext(
                databaseName: session?.currentDatabase ?? "Current database",
                tables: []
            )
            completionLoadError = error.localizedDescription
        }
    }

    private func applyCompletion(_ suggestion: String) {
        let applied = SQLHighlighter.applyingCompletion(
            suggestion,
            to: queryText,
            selectedRange: selectedRange
        )
        queryText = applied.sql
        selectedRange = applied.selection
        saveActiveTab()
    }

    // MARK: - Query Tabs

    private func saveActiveTab() {
        guard let selectedTabID,
              let index = tabs.firstIndex(where: { $0.id == selectedTabID }) else { return }
        tabs[index].text = queryText
        tabs[index].selectedRange = selectedRange
        tabs[index].result = currentResult
    }

    private func switchToTab(_ id: UUID) {
        guard !isExecuting, id != selectedTabID else { return }
        saveActiveTab()
        guard let tab = tabs.first(where: { $0.id == id }) else { return }
        selectedTabID = id
        queryText = tab.text
        selectedRange = tab.selectedRange
        currentResult = tab.result
    }

    private func createTab(with text: String = "") {
        guard !isExecuting else { return }
        saveActiveTab()
        let tab = QueryDocumentTab(
            text: text,
            selectedRange: NSRange(location: (text as NSString).length, length: 0)
        )
        tabs.append(tab)
        selectedTabID = tab.id
        queryText = text
        selectedRange = tab.selectedRange
        currentResult = nil
    }

    private func requestCloseCurrentTab() {
        guard let selectedTabID else { return }
        requestCloseTab(selectedTabID)
    }

    private func requestCloseTab(_ id: UUID) {
        guard tabs.count > 1, !isExecuting else { return }
        if id == selectedTabID {
            saveActiveTab()
        }
        guard let tab = tabs.first(where: { $0.id == id }) else { return }
        if tab.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            closeTab(id)
        } else {
            tabPendingClose = id
        }
    }

    private func closeTab(_ id: UUID) {
        guard tabs.count > 1,
              let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        let wasSelected = id == selectedTabID
        tabs.remove(at: index)
        guard wasSelected else { return }
        let nextIndex = min(index, tabs.count - 1)
        let nextTab = tabs[nextIndex]
        selectedTabID = nextTab.id
        queryText = nextTab.text
        selectedRange = nextTab.selectedRange
        currentResult = nextTab.result
    }
}

// MARK: - Durable History

private struct QueryHistoryView: View {
    let connectionID: UUID?
    let onSelect: (QueryHistoryEntry) -> Void

    @Environment(DatabaseSessionManager.self) private var sessionManager
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var status: QueryHistoryStatus = .all
    @State private var confirmingDeleteAll = false

    private var entries: [QueryHistoryEntry] {
        sessionManager.queryHistory(
            matching: searchText,
            connectionID: connectionID,
            status: status
        )
    }

    var body: some View {
        NavigationStack {
            Group {
                if entries.isEmpty {
                    ContentUnavailableView(
                        searchText.isEmpty ? "No Query History" : "No Matches",
                        systemImage: "clock.arrow.circlepath",
                        description: Text(searchText.isEmpty
                            ? "Executed queries appear here and persist across launches."
                            : "Try a different query or status filter.")
                    )
                } else {
                    List(entries) { entry in
                        Button {
                            onSelect(entry)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(entry.sql)
                                    .font(.system(.body, design: .monospaced))
                                    .lineLimit(3)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                HStack(spacing: 10) {
                                    Text(entry.timestamp, format: .dateTime.month().day().hour().minute().second())
                                    if let database = entry.database { Text(database) }
                                    Text("\(entry.duration, format: .number.precision(.fractionLength(3)))s")
                                    if let rowCount = entry.rowCount { Text("\(rowCount) rows") }
                                    if let affectedRows = entry.affectedRows { Text("\(affectedRows) affected") }
                                    if entry.error != nil {
                                        Label("Failed", systemImage: "xmark.circle.fill")
                                            .foregroundStyle(.red)
                                    }
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                        .swipeActions {
                            Button("Delete", role: .destructive) {
                                sessionManager.deleteQueryHistory(id: entry.id)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Query History")
            .searchable(text: $searchText, prompt: "SQL, database, or error")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .keyboardShortcut(.cancelAction)
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Picker("Status", selection: $status) {
                            ForEach(QueryHistoryStatus.allCases) { option in
                                Text(option.displayName).tag(option)
                            }
                        }
                        Divider()
                        Button("Clear This Connection", role: .destructive) {
                            confirmingDeleteAll = true
                        }
                        .disabled(connectionID == nil || entries.isEmpty)
                    } label: {
                        Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                    }
                    .help("Filter history by execution status or clear this connection's history")
                }
            }
        }
        #if os(macOS)
        .frame(width: 760, height: 560)
        #else
        .frame(minWidth: 720, minHeight: 520)
        #endif
        .alert("Clear Query History?", isPresented: $confirmingDeleteAll) {
            Button("Cancel", role: .cancel) {}
                .keyboardShortcut(.cancelAction)
            Button("Clear", role: .destructive) {
                sessionManager.deleteAllQueryHistory(connectionID: connectionID)
            }
        } message: {
            Text("This permanently removes saved history for this connection.")
        }
    }
}

private struct SavedQueriesView: View {
    let connectionID: UUID?
    let onSelect: (SavedQuery) -> Void

    @Environment(SettingsManager.self) private var settingsManager
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var queries: [SavedQuery] {
        settingsManager.savedQueries
            .filter { query in
                (query.connectionID == nil || query.connectionID == connectionID)
                    && (searchText.isEmpty
                        || query.name.localizedCaseInsensitiveContains(searchText)
                        || query.sql.localizedCaseInsensitiveContains(searchText))
            }
            .sorted {
                ($0.lastUsed ?? $0.createdAt) > ($1.lastUsed ?? $1.createdAt)
            }
    }

    var body: some View {
        NavigationStack {
            Group {
                if queries.isEmpty {
                    ContentUnavailableView(
                        searchText.isEmpty ? "No Saved Queries" : "No Matches",
                        systemImage: "bookmark",
                        description: Text(searchText.isEmpty
                            ? "Use Save Current Query from the editor toolbar to add one."
                            : "Try a different name or SQL search.")
                    )
                } else {
                    List(queries) { query in
                        Button {
                            onSelect(query)
                        } label: {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(query.name)
                                    .font(.headline)
                                Text(query.sql)
                                    .font(.system(.caption, design: .monospaced))
                                    .lineLimit(3)
                                HStack {
                                    Text("Used \(query.useCount) times")
                                    Text(query.lastUsed ?? query.createdAt, style: .relative)
                                }
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        .swipeActions {
                            Button("Delete", role: .destructive) {
                                settingsManager.deleteSavedQuery(query)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Saved Queries")
            .searchable(text: $searchText, prompt: "Name or SQL")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .keyboardShortcut(.cancelAction)
                }
            }
        }
        #if os(macOS)
        .frame(width: 760, height: 560)
        #else
        .frame(minWidth: 720, minHeight: 520)
        #endif
    }
}
