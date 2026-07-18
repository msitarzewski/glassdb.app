//
//  DatabaseDetailView.swift
//  glassdb
//
//  Context-sensitive detail surface for a selected database.
//  Shows properties, table summary, and quick actions.
//

import SwiftUI
import GlassDBKit

struct DatabaseDetailView: View {
    let sessionID: UUID
    let database: String
    var isWorkspaceActive = true
    var onOpenSQLEditor: (() -> Void)?

    @Environment(DatabaseSessionManager.self) private var sessionManager
    @Environment(SettingsManager.self) private var settingsManager

    @State private var tableStatuses: [TableStatus] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var session: DatabaseSession? {
        sessionManager.session(for: sessionID)
    }

    private var isActiveDatabase: Bool {
        session?.currentDatabase == database
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection
                actionsSection
                if isLoading {
                    ProgressView("Loading table status...")
                        .padding(32)
                } else if let error = errorMessage {
                    ContentUnavailableView("Error", systemImage: "exclamationmark.triangle", description: Text(error))
                } else if !tableStatuses.isEmpty {
                    tablesSummarySection
                } else if session?.connection?.capabilities.contains(.tableStatistics) == false {
                    ContentUnavailableView(
                        "Statistics Unavailable",
                        systemImage: "chart.bar.xaxis",
                        description: Text("\(session?.connection?.engineName ?? "This engine") does not expose table-size statistics through glassdb yet. Tables and row counts remain available in the schema browser.")
                    )
                }
            }
            .padding(32)
        }
        .databaseLookScrollEnabled()
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
                        Task { await loadStatus() }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                }
            }
        }
        .task(id: isWorkspaceActive) {
            guard isWorkspaceActive else { return }
            await setActiveAndLoad()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "cylinder")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text(database)
                .font(.title)
            if isActiveDatabase {
                Label("Active Database", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.callout)
            }
            if !tableStatuses.isEmpty {
                HStack(spacing: 24) {
                    statBadge("\(tableStatuses.count)", label: "Tables")
                    statBadge(totalRows, label: "Rows")
                    statBadge(totalSize, label: "Size")
                }
                .padding(.top, 8)
            }
        }
    }

    private func statBadge(_ value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2.bold())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var totalRows: String {
        let total = tableStatuses.reduce(0) { $0 + $1.rowCount }
        return total.formatted()
    }

    private var totalSize: String {
        let total = tableStatuses.reduce(0) { $0 + $1.dataLength }
        return ByteCountFormatter.string(fromByteCount: Int64(total), countStyle: .file)
    }

    // MARK: - Actions

    private var actionsSection: some View {
        HStack(spacing: 16) {
            if !isActiveDatabase {
                Button {
                    Task { await setActiveAndLoad() }
                } label: {
                    Label("Set as Active", systemImage: "checkmark.circle")
                }
                .buttonStyle(.borderedProminent)
            }
            Button {
                onOpenSQLEditor?()
            } label: {
                Label("SQL Editor", systemImage: "text.page")
            }
        }
    }

    // MARK: - Tables Summary

    private var tablesSummarySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tables")
                .font(.headline)
                .padding(.horizontal, 4)

            ScrollView(.vertical) {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: .sectionHeaders) {
                    Section {
                        ForEach(tableStatuses) { ts in
                            HStack(spacing: 0) {
                                dataCell(ts.name, monospaced: true)
                                dataCell(ts.engine ?? "-")
                                dataCell(ts.rowCount.formatted())
                                dataCell(ByteCountFormatter.string(fromByteCount: Int64(ts.dataLength), countStyle: .file))
                                dataCell(ts.collation ?? "-")
                                Spacer(minLength: 0)
                            }
                        }
                    } header: {
                        HStack(spacing: 0) {
                            headerCell("Table")
                            headerCell("Engine")
                            headerCell("Rows")
                            headerCell("Size")
                            headerCell("Collation")
                            Spacer(minLength: 0)
                        }
                        .background(.ultraThinMaterial)
                    }
                }
            }
            .scrollIndicators(.visible)
        }
    }

    private func headerCell(_ text: String) -> some View {
        Text(text)
            .font(.system(size: settingsManager.dataGridFontSize, weight: .bold, design: .monospaced))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(minWidth: 100, alignment: .leading)
            .background(.ultraThinMaterial)
            .accessibilityAddTraits(.isHeader)
    }

    private func dataCell(_ text: String, monospaced: Bool = false) -> some View {
        Text(text)
            .font(.system(size: settingsManager.dataGridFontSize, design: monospaced ? .monospaced : .default))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .frame(minWidth: 100, alignment: .leading)
    }

    // MARK: - Loading

    private func setActiveAndLoad() async {
        if !isActiveDatabase {
            guard let connection = session?.connection else {
                errorMessage = "The database session is no longer available."
                return
            }
            if connection.dialect == .mysql {
                do {
                    _ = try await sessionManager.executeQuery(
                        "USE \(connection.quotedIdentifier(database))",
                        sessionID: sessionID
                    )
                } catch {
                    errorMessage = "Could not activate \(database): \(error.localizedDescription)"
                    return
                }
            } else {
                session?.currentDatabase = database
            }
        }
        await loadStatus()
    }

    private func loadStatus() async {
        guard let connection = session?.connection else { return }
        guard connection.capabilities.contains(.tableStatistics) else {
            tableStatuses = []
            errorMessage = nil
            return
        }
        isLoading = true
        errorMessage = nil
        do {
            tableStatuses = try await connection.tableStatus(in: database)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
