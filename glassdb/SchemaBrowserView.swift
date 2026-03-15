//
//  SchemaBrowserView.swift
//  glassdb
//
//  Tree navigation: databases -> tables -> columns -> indexes
//

import SwiftUI
import GlassDBKit
import os

struct SchemaBrowserView: View {
    let sessionID: UUID

    @Environment(DatabaseSessionManager.self) private var sessionManager

    @State private var databases: [String] = []
    @State private var expandedDatabases: Set<String> = []
    @State private var tablesCache: [String: [String]] = [:]
    @State private var columnsCache: [String: [ColumnInfo]] = [:]
    @State private var loadErrors: [String: String] = [:]
    @State private var isLoading = false
    @State private var errorMessage: String?

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
        .navigationTitle("Schema")
        .toolbar {
            ToolbarItemGroup(placement: .bottomOrnament) {
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
    }

    private var schemaTree: some View {
        List {
            ForEach(databases, id: \.self) { database in
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
                    if let tables = tablesCache[database] {
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
                    Label(database, systemImage: "cylinder")
                        .font(.headline)
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
            Label(table, systemImage: "tablecells")
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
}
