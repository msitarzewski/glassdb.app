//
//  SchemaBrowserView.swift
//  glassdb
//
//  Tree navigation: databases -> tables -> columns -> indexes
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

struct SchemaBrowserView: View {
    let sessionID: UUID
    var onSelectionChanged: ((WorkspaceSelection) -> Void)?

    @Environment(DatabaseSessionManager.self) private var sessionManager

    @State private var databases: [String] = []
    @State private var expandedDatabases: Set<String> = []
    @State private var tablesCache: [String: [String]] = [:]
    @State private var columnsCache: [String: [ColumnInfo]] = [:]
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
                        schemaTree
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
        .searchable(text: $filterText, placement: .sidebar, prompt: "Filter")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await loadDatabases() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }
        }
        .task {
            await loadDatabases()
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

    private var schemaTree: some View {
        List {
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
                    Button {
                        onSelectionChanged?(.database(database))
                    } label: {
                        Label(database, systemImage: "cylinder")
                            .font(.headline)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        if session?.connection?.dialect == .mysql {
                            Button {
                                Task {
                                    do {
                                        guard let connection = session?.connection else { return }
                                        let result = try await sessionManager.executeQuery(
                                            "USE \(connection.quotedIdentifier(database))", sessionID: sessionID
                                        )
                                        if let serverError = result.error { operationError = serverError }
                                    } catch {
                                        operationError = "Could not select ‘\(database)’: \(error.localizedDescription)"
                                    }
                                }
                            } label: {
                                Label("Set as Active Database", systemImage: "checkmark.circle")
                            }
                        }
                        Button {
                            onSelectionChanged?(.query)
                        } label: {
                            Label("Open SQL Editor", systemImage: "text.page")
                        }
                        Divider()
                        Button {
                            tablesCache.removeValue(forKey: database)
                            Task { await loadTables(for: database) }
                        } label: {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                    }
                }
            }
        }
        .scrollInputBehavior(.enabled, for: .look)
    }

    private func columnAccessibilityLabel(_ col: ColumnInfo) -> String {
        var parts = [col.name, col.type]
        if col.isPrimaryKey { parts.append("primary key") }
        if !col.isNullable { parts.append("not null") }
        return parts.joined(separator: ", ")
    }

    private func tableRow(_ table: String, database: String) -> some View {
        let cacheKey = "\(database).\(table)"
        return DisclosureGroup {
            if let columns = columnsCache[cacheKey] {
                ForEach(columns) { col in
                    HStack(spacing: 8) {
                        Image(systemName: col.isPrimaryKey ? "key.fill" : "minus")
                            .font(.caption2)
                            .foregroundStyle(col.isPrimaryKey ? AnyShapeStyle(.yellow) : AnyShapeStyle(.tertiary))
                            .frame(width: 16)

                        Text(col.name)
                            .font(.system(.caption, design: .monospaced))

                        Spacer()

                        Text(col.type)
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        if !col.isNullable {
                            Text("NOT NULL")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(columnAccessibilityLabel(col))
                }
            } else if let error = loadErrors[cacheKey] {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.red)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .task {
                        await loadColumns(for: table, database: database)
                    }
            }
        } label: {
            Button {
                onSelectionChanged?(.table(database: database, table: table))
            } label: {
                HStack {
                    Label(table, systemImage: "tablecells")
                    Spacer()
                    if let count = rowCountCache[cacheKey] {
                        Text(count.formatted())
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .buttonStyle(.plain)
            .contextMenu {
                Button {
                    onSelectionChanged?(.table(database: database, table: table))
                } label: {
                    Label("Browse Data", systemImage: "tablecells")
                }
                Button {
                    guard let connection = session?.connection else { return }
                    UIPasteboard.general.string = "\(connection.quotedIdentifier(database)).\(connection.quotedIdentifier(table))"
                } label: {
                    Label("Copy Table Name", systemImage: "doc.on.doc")
                }
                Button {
                    guard let connection = session?.connection else { return }
                    let object = "\(connection.quotedIdentifier(database)).\(connection.quotedIdentifier(table))"
                    UIPasteboard.general.string = "SELECT * FROM \(object) LIMIT 100;"
                } label: {
                    Label("Copy SELECT Statement", systemImage: "text.page")
                }
                Divider()
                Button {
                    tablesCache.removeValue(forKey: database)
                    Task { await loadTables(for: database) }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                Divider()
                if session?.connection?.capabilities.contains(.truncateTable) == true {
                    Button(role: .destructive) {
                        confirmingTruncate = SchemaMutationTarget(database: database, table: table)
                    } label: {
                        Label("Truncate Table...", systemImage: "trash")
                    }
                }
                Button(role: .destructive) {
                    confirmingDrop = SchemaMutationTarget(database: database, table: table)
                } label: {
                    Label("Drop Table...", systemImage: "xmark.bin")
                }
            }
            .task {
                await loadRowCount(for: table, database: database)
            }
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
                columnsCache.removeValue(forKey: "\(target.database).\(target.table)")
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
            loadErrors[database] = error.localizedDescription
            Logger.database.error("Failed to load tables for \(database): \(error)")
        }
    }

    private func loadColumns(for table: String, database: String) async {
        guard let connection = session?.connection else { return }
        let cacheKey = "\(database).\(table)"
        guard columnsCache[cacheKey] == nil else { return }
        loadErrors.removeValue(forKey: cacheKey)
        do {
            columnsCache[cacheKey] = try await connection.columns(in: table, database: database)
        } catch {
            loadErrors[cacheKey] = error.localizedDescription
            Logger.database.error("Failed to load columns for \(database).\(table): \(error)")
        }
    }

    private func loadRowCount(for table: String, database: String) async {
        guard let connection = session?.connection else { return }
        let cacheKey = "\(database).\(table)"
        guard rowCountCache[cacheKey] == nil else { return }
        do {
            rowCountCache[cacheKey] = try await connection.rowCount(table: table, database: database)
        } catch {
            Logger.database.error("Failed to load row count for \(database).\(table): \(error)")
        }
    }
}
