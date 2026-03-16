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
    @State private var confirmingTruncate: String?
    @State private var confirmingDrop: String?

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
        .navigationTitle("Databases")
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
        .alert("Truncate Table?", isPresented: .init(
            get: { confirmingTruncate != nil },
            set: { if !$0 { confirmingTruncate = nil } }
        )) {
            Button("Truncate", role: .destructive) {
                if let key = confirmingTruncate {
                    let parts = key.split(separator: ".", maxSplits: 1)
                    if parts.count == 2 {
                        Task {
                            try? await session?.connection?.execute(
                                "TRUNCATE TABLE `\(parts[0])`.`\(parts[1])`"
                            )
                        }
                    }
                }
                confirmingTruncate = nil
            }
            Button("Cancel", role: .cancel) { confirmingTruncate = nil }
        } message: {
            Text("This will permanently delete all rows. This cannot be undone.")
        }
        .alert("Drop Table?", isPresented: .init(
            get: { confirmingDrop != nil },
            set: { if !$0 { confirmingDrop = nil } }
        )) {
            Button("Drop", role: .destructive) {
                if let key = confirmingDrop {
                    let parts = key.split(separator: ".", maxSplits: 1)
                    if parts.count == 2 {
                        Task {
                            try? await session?.connection?.execute(
                                "DROP TABLE `\(parts[0])`.`\(parts[1])`"
                            )
                            tablesCache.removeValue(forKey: String(parts[0]))
                            await loadTables(for: String(parts[0]))
                        }
                    }
                }
                confirmingDrop = nil
            }
            Button("Cancel", role: .cancel) { confirmingDrop = nil }
        } message: {
            Text("This will permanently delete the table and all its data. This cannot be undone.")
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
                        Button {
                            Task {
                                try? await sessionManager.executeQuery(
                                    "USE `\(database)`", sessionID: sessionID
                                )
                            }
                        } label: {
                            Label("Set as Active Database", systemImage: "checkmark.circle")
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
                    UIPasteboard.general.string = "`\(database)`.`\(table)`"
                } label: {
                    Label("Copy Table Name", systemImage: "doc.on.doc")
                }
                Button {
                    UIPasteboard.general.string = "SELECT * FROM `\(database)`.`\(table)` LIMIT 100;"
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
                Button(role: .destructive) {
                    confirmingTruncate = cacheKey
                } label: {
                    Label("Truncate Table...", systemImage: "trash")
                }
                Button(role: .destructive) {
                    confirmingDrop = cacheKey
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
