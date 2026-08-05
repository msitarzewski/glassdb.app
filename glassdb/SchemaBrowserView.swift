//
//  SchemaBrowserView.swift
//  glassdb
//
//  Tree navigation: databases -> tables
//  Selection drives the workspace detail surface
//

import SwiftUI
import GlassDBKit
import os

private struct SchemaMutationTarget: Identifiable {
    let database: String
    let table: String
    var id: String { "\(database.utf8.count):\(database)\(table)" }
}

private enum SchemaMutationOperation: String {
    case truncate
    case drop
}

private struct SchemaMutationFailure: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

#if os(iOS)
private struct CompactSchemaDatabaseDestination: Hashable {
    let name: String
}
#endif

struct SchemaBrowserView: View {
    let sessionID: UUID
    let selection: WorkspaceSelection
    var onSelectionChanged: ((WorkspaceSelection) -> Void)?

    @Environment(DatabaseSessionManager.self) private var sessionManager
    @Environment(\.openWindow) private var openWindow
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

    @State private var databases: [String] = []
    @State private var expandedDatabases: Set<String> = []
    @State private var tablesCache: [String: [String]] = [:]
    @State private var rowCountCache: [String: Int] = [:]
    @State private var loadErrors: [String: String] = [:]
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var filterText = ""
    @State private var confirmingTruncate: SchemaMutationTarget?
    @State private var confirmingDrop: SchemaMutationTarget?
    @State private var destructiveOperation: String?
    @State private var operationError: String?

    private var session: DatabaseSession? {
        sessionManager.session(for: sessionID)
    }

    private var schemaSelection: Binding<WorkspaceSelection?> {
        Binding(
            get: { selection },
            set: { newSelection in
                guard let newSelection else { return }
                onSelectionChanged?(newSelection)
            }
        )
    }

    var body: some View {
        Group {
            if session != nil {
                VStack(spacing: 0) {
                    if isLoading && databases.isEmpty {
                        ProgressView("Loading schema...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if let error = errorMessage {
                        ContentUnavailableView(
                            "Error",
                            systemImage: "exclamationmark.triangle",
                            description: Text(error)
                        )
                    } else {
                        platformSchemaTree
                    }
                }
            } else {
                ContentUnavailableView(
                    "Session Disconnected",
                    systemImage: "cable.connector.slash",
                    description: Text("This database session is no longer active.")
                )
            }
        }
        .navigationTitle(session?.connection?.dialect == .postgresql ? "Schemas" : "Databases")
        .schemaSearchable(text: $filterText)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await loadDatabases() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .help("Reload databases and tables")
            }
        }
        .task {
            await loadDatabases()
        }
        .onChange(of: session?.state) {
            guard session?.state.isConnected == true else { return }
            tablesCache.removeAll()
            rowCountCache.removeAll()
            loadErrors.removeAll()
            Task { await loadDatabases() }
        }
        .overlay {
            if let destructiveOperation {
                ProgressView(destructiveOperation)
                    .padding(20)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
        }
        .alert("Truncate Table?", isPresented: .init(
            get: { confirmingTruncate != nil },
            set: { if !$0 { confirmingTruncate = nil } }
        )) {
            Button("Truncate", role: .destructive) {
                if let target = confirmingTruncate {
                    Task { await executeSchemaMutation(.truncate, target: target) }
                }
                confirmingTruncate = nil
            }
            Button("Cancel", role: .cancel) { confirmingTruncate = nil }
        } message: {
            Text(schemaMutationPreview(operation: "TRUNCATE", target: confirmingTruncate))
        }
        .alert("Drop Table?", isPresented: .init(
            get: { confirmingDrop != nil },
            set: { if !$0 { confirmingDrop = nil } }
        )) {
            Button("Drop", role: .destructive) {
                if let target = confirmingDrop {
                    Task { await executeSchemaMutation(.drop, target: target) }
                }
                confirmingDrop = nil
            }
            Button("Cancel", role: .cancel) { confirmingDrop = nil }
        } message: {
            Text(schemaMutationPreview(operation: "DROP TABLE", target: confirmingDrop))
        }
        .alert("Database Operation Failed", isPresented: .init(
            get: { operationError != nil },
            set: { if !$0 { operationError = nil } }
        )) {
            Button("OK", role: .cancel) { operationError = nil }
        } message: {
            Text(operationError ?? "")
        }
    }

    // MARK: - Filtered Data

    private var filteredDatabases: [String] {
        guard !filterText.isEmpty else { return databases }
        return databases.filter { db in
            if db.localizedCaseInsensitiveContains(filterText) { return true }
            if let tables = tablesCache[db] {
                return tables.contains { $0.localizedCaseInsensitiveContains(filterText) }
            }
            return false
        }
    }

    private func filteredTables(for database: String) -> [String]? {
        guard let tables = tablesCache[database] else { return nil }
        guard !filterText.isEmpty else { return tables }
        return tables.filter { $0.localizedCaseInsensitiveContains(filterText) }
    }

    // MARK: - Schema Tree

    @ViewBuilder
    private var platformSchemaTree: some View {
        #if os(iOS)
        if horizontalSizeClass == .compact {
            compactDatabaseList
        } else {
            schemaTree
        }
        #else
        schemaTree
        #endif
    }

    #if os(iOS)
    private var compactDatabaseList: some View {
        List(filteredDatabases, id: \.self) { database in
            NavigationLink(value: CompactSchemaDatabaseDestination(name: database)) {
                Label(database, systemImage: "cylinder")
            }
            .contextMenu {
                Button("Open Database Overview", systemImage: "info.circle") {
                    onSelectionChanged?(.database(database))
                }
                Button("Open SQL Editor", systemImage: "text.page") {
                    onSelectionChanged?(.query)
                }
                Button("Refresh Tables", systemImage: "arrow.clockwise") {
                    tablesCache.removeValue(forKey: database)
                    Task { await loadTables(for: database) }
                }
            }
        }
        .navigationDestination(for: CompactSchemaDatabaseDestination.self) { destination in
            compactTableList(for: destination.name)
        }
    }

    private func compactTableList(for database: String) -> some View {
        Group {
            if let error = loadErrors[database] {
                ContentUnavailableView(
                    "Tables Unavailable",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error)
                )
            } else if let tables = filteredTables(for: database) {
                List(tables, id: \.self) { table in
                    compactTableRow(table, database: database)
                }
            } else {
                ProgressView("Loading tables…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle(database)
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadTables(for: database) }
        .toolbar {
            ToolbarItemGroup(placement: .secondaryAction) {
                Button("Database Overview", systemImage: "info.circle") {
                    onSelectionChanged?(.database(database))
                }
                Button("Refresh Tables", systemImage: "arrow.clockwise") {
                    tablesCache.removeValue(forKey: database)
                    Task { await loadTables(for: database) }
                }
            }
        }
    }

    private func compactTableRow(_ table: String, database: String) -> some View {
        let cacheKey = "\(database).\(table)"
        return HStack(spacing: 8) {
            Button {
                onSelectionChanged?(.table(database: database, table: table))
            } label: {
                HStack {
                    Label(table, systemImage: "tablecells")
                    Spacer()
                    if let count = rowCountCache[cacheKey] {
                        Text(count.formatted())
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Menu("Table Actions", systemImage: "ellipsis.circle") {
                tableActionMenu(table, database: database)
            }
            .labelStyle(.iconOnly)
        }
        .task { await loadRowCount(for: table, database: database) }
        .accessibilityElement(children: .contain)
    }
    #endif

    private var schemaTree: some View {
        List(selection: schemaSelection) {
            ForEach(filteredDatabases, id: \.self) { database in
                DisclosureGroup(
                    isExpanded: Binding(
                        get: { expandedDatabases.contains(database) },
                        set: { expanded in
                            if expanded {
                                expandedDatabases.insert(database)
                                Task { await loadTables(for: database) }
                            } else {
                                expandedDatabases.remove(database)
                            }
                        }
                    )
                ) {
                    if let tables = filteredTables(for: database) {
                        ForEach(tables, id: \.self) { table in
                            tableRow(table, database: database)
                        }
                    } else if let error = loadErrors[database] {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.red)
                    } else {
                        ProgressView()
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                } label: {
                    HStack {
                        Label(database, systemImage: "cylinder")
                            .font(.headline)
                        Spacer(minLength: 8)
                    }
                    .contentShape(Rectangle())
                    .contextMenu {
                        databaseActionMenu(database)
                    }
                }
                .tag(WorkspaceSelection.database(database))
            }
        }
        .databaseLookScrollEnabled()
    }

    private func tableRow(_ table: String, database: String) -> some View {
        let cacheKey = "\(database).\(table)"
        return HStack {
            Label(table, systemImage: "tablecells")
            Spacer()
            if let count = rowCountCache[cacheKey] {
                Text(count.formatted())
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .contentShape(Rectangle())
        .tag(WorkspaceSelection.table(database: database, table: table))
        .contextMenu {
            tableActionMenu(table, database: database)
        }
        .task {
            await loadRowCount(for: table, database: database)
        }
    }

    @ViewBuilder
    private func databaseActionMenu(_ database: String) -> some View {
        if session?.connection?.dialect == .mysql {
            Button("Set as Active Database", systemImage: "checkmark.circle") {
                Task {
                    do {
                        guard let connection = session?.connection else { return }
                        let result = try await sessionManager.executeQuery(
                            "USE \(connection.quotedIdentifier(database))",
                            sessionID: sessionID
                        )
                        if let serverError = result.error {
                            operationError = serverError
                        }
                    } catch {
                        operationError = "Could not select ‘\(database)’: \(error.localizedDescription)"
                    }
                }
            }
        }
        Button("Open SQL Editor", systemImage: "text.page") {
            onSelectionChanged?(.query)
        }
        Button("Open in New Window", systemImage: "macwindow.badge.plus") {
            let request = DatabaseWorkspaceWindowRequest.additional(
                sessionID: sessionID,
                initialSelection: .database(database)
            )
            openWindow(
                id: "query-editor",
                value: sessionManager.registerWorkspace(request)
            )
        }
        .help("Open \(database) in another window on this connection")
        Divider()
        Button("Refresh", systemImage: "arrow.clockwise") {
            tablesCache.removeValue(forKey: database)
            Task { await loadTables(for: database) }
        }
    }

    @ViewBuilder
    private func tableActionMenu(_ table: String, database: String) -> some View {
        Button("Browse Data", systemImage: "tablecells") {
            onSelectionChanged?(.table(database: database, table: table))
        }
        Button("Copy Table Name", systemImage: "doc.on.doc") {
            guard let connection = session?.connection else { return }
            PlatformClipboard.copy(
                "\(connection.quotedIdentifier(database)).\(connection.quotedIdentifier(table))"
            )
        }
        Button("Copy SELECT Statement", systemImage: "text.page") {
            guard let connection = session?.connection else { return }
            let object = "\(connection.quotedIdentifier(database)).\(connection.quotedIdentifier(table))"
            PlatformClipboard.copy("SELECT * FROM \(object) LIMIT 100;")
        }
        Divider()
        Button("Refresh", systemImage: "arrow.clockwise") {
            tablesCache.removeValue(forKey: database)
            Task { await loadTables(for: database) }
        }
        Divider()
        if session?.connection?.capabilities.contains(.truncateTable) == true {
            Button("Truncate Table…", systemImage: "trash", role: .destructive) {
                confirmingTruncate = SchemaMutationTarget(database: database, table: table)
            }
        }
        Button("Drop Table…", systemImage: "xmark.bin", role: .destructive) {
            confirmingDrop = SchemaMutationTarget(database: database, table: table)
        }
    }

    // MARK: - Data Loading

    private func schemaMutationPreview(operation: String, target: SchemaMutationTarget?) -> String {
        guard let target else { return "" }
        let connection = session?.connectionConfig
        let transactionWarning = connection?.engine == .mysql
            ? "MySQL DDL may commit implicitly and cannot be rolled back"
            : "DDL transaction behavior follows the connected engine"
        return "Connection: \(connection?.name ?? "Disconnected")\nEnvironment tag: \(connection?.colorTag.displayName ?? "None")\nDatabase: \(target.database)\nTable: \(target.table)\nOperation: \(operation)\nEstimated scope: the entire table\nTransaction: \(transactionWarning)\n\nThis action is permanent."
    }

    private func executeSchemaMutation(_ operation: SchemaMutationOperation, target: SchemaMutationTarget) async {
        guard let connection = session?.connection, let config = session?.connectionConfig else { return }
        if operation == .truncate, !connection.capabilities.contains(.truncateTable) {
            operationError = "\(connection.engineName) does not support TRUNCATE TABLE."
            return
        }
        destructiveOperation = operation == .truncate ? "Truncating table…" : "Dropping table…"
        defer { destructiveOperation = nil }

        let object = "\(connection.quotedIdentifier(target.database)).\(connection.quotedIdentifier(target.table))"
        let sql = operation == .truncate ? "TRUNCATE TABLE \(object)" : "DROP TABLE \(object)"
        do {
            let result = try await connection.execute(sql, parameters: [])
            if let serverError = result.error { throw SchemaMutationFailure(message: serverError) }
            MutationAuditStore.append(MutationAuditRecord(
                connectionID: config.id,
                database: target.database,
                object: target.table,
                normalizedOperation: operation.rawValue,
                source: "schema-browser",
                outcome: .committed,
                affectedRows: result.affectedRows
            ))
            if operation == .drop {
                tablesCache.removeValue(forKey: target.database)
                await loadTables(for: target.database)
            } else {
                rowCountCache["\(target.database).\(target.table)"] = 0
            }
        } catch {
            MutationAuditStore.append(MutationAuditRecord(
                connectionID: config.id,
                database: target.database,
                object: target.table,
                normalizedOperation: operation.rawValue,
                source: "schema-browser",
                outcome: .serverStateUnknown,
                affectedRows: nil
            ))
            operationError = "\(operation == .truncate ? "Truncate" : "Drop") failed. Verify the table state before retrying. \(error.localizedDescription)"
        }
    }

    private func loadDatabases() async {
        guard let connection = session?.connection else { return }
        isLoading = true
        errorMessage = nil
        do {
            databases = try await connection.databases()
        } catch {
            await sessionManager.handleConnectionFailure(error, sessionID: sessionID)
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func loadTables(for database: String) async {
        guard let connection = session?.connection else { return }
        guard tablesCache[database] == nil else { return }
        loadErrors.removeValue(forKey: database)
        do {
            tablesCache[database] = try await connection.tables(in: database)
        } catch {
            await sessionManager.handleConnectionFailure(error, sessionID: sessionID)
            loadErrors[database] = error.localizedDescription
            Logger.database.error("Failed to load tables for \(database): \(error)")
        }
    }

    private func loadRowCount(for table: String, database: String) async {
        guard let connection = session?.connection else { return }
        let cacheKey = "\(database).\(table)"
        guard rowCountCache[cacheKey] == nil else { return }
        do {
            rowCountCache[cacheKey] = try await connection.rowCount(table: table, database: database)
        } catch {
            await sessionManager.handleConnectionFailure(error, sessionID: sessionID)
            Logger.database.error("Failed to load row count for \(database).\(table): \(error)")
        }
    }
}

private extension View {
    @ViewBuilder
    func schemaSearchable(text: Binding<String>) -> some View {
        #if os(iOS)
        searchable(text: text, placement: .automatic, prompt: "Filter databases and tables")
        #else
        searchable(text: text, placement: .sidebar, prompt: "Filter")
        #endif
    }
}
