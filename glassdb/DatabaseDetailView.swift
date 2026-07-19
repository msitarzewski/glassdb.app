//
//  DatabaseDetailView.swift
//  glassdb
//
//  Context-sensitive detail surface for a selected database.
//  Shows properties, table summary, and quick actions.
//

import SwiftUI
import GlassDBKit
import Charts

struct DatabaseDetailView: View {
    let sessionID: UUID
    let database: String
    var isWorkspaceActive = true
    var onOpenTable: ((String) -> Void)?
    var onOpenSQLEditor: (() -> Void)?

    @Environment(DatabaseSessionManager.self) private var sessionManager

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
            VStack(alignment: .leading, spacing: 24) {
                headerSection
                actionsSection
                if isLoading {
                    ProgressView("Loading table status...")
                        .padding(32)
                } else if let error = errorMessage {
                    ContentUnavailableView("Error", systemImage: "exclamationmark.triangle", description: Text(error))
                } else if !tableStatuses.isEmpty {
                    overviewSection
                    chartsSection
                    tablesSummarySection
                } else if session?.connection?.capabilities.contains(.tableStatistics) == false {
                    ContentUnavailableView(
                        "Statistics Unavailable",
                        systemImage: "chart.bar.xaxis",
                        description: Text("\(session?.connection?.engineName ?? "This engine") does not expose table-size statistics through glassdb yet. Tables and row counts remain available in the schema browser.")
                    )
                }
            }
            .padding(28)
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
        HStack(spacing: 16) {
            Image(systemName: "cylinder.split.1x2")
                .font(.system(size: 34))
                .foregroundStyle(.tint)
                .frame(width: 54, height: 54)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 4) {
                Text(database)
                    .font(.title.bold())
                HStack(spacing: 8) {
                    Text(session?.connection?.engineName ?? "Database")
                        .foregroundStyle(.secondary)
                    if isActiveDatabase {
                        Label("Active", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }
                .font(.callout)
            }
            Spacer()
        }
    }

    private func metricCard(_ value: String, label: String, systemImage: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
            Text(value)
                    .font(.title3.bold())
                    .contentTransition(.numericText())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 82, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var totalRows: String {
        let total = tableStatuses.reduce(0) { $0 + $1.rowCount }
        return total.formatted()
    }

    private var totalSize: String {
        let total = tableStatuses.reduce(0) { $0 + $1.dataLength }
        return ByteCountFormatter.string(fromByteCount: Int64(total), countStyle: .file)
    }

    private var overviewSection: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 12)], spacing: 12) {
            metricCard(tableStatuses.count.formatted(), label: "Tables", systemImage: "tablecells")
            metricCard(totalRows, label: "Estimated rows", systemImage: "number")
            metricCard(totalSize, label: "Table storage", systemImage: "internaldrive")
            metricCard(engineSummary, label: "Storage engines", systemImage: "gearshape.2")
        }
    }

    private var engineSummary: String {
        let engines = Set(tableStatuses.compactMap(\.engine).filter { !$0.isEmpty })
        return engines.isEmpty ? "Unknown" : engines.sorted().joined(separator: ", ")
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

    // MARK: - Charts

    @ViewBuilder
    private var chartsSection: some View {
        let rowLeaders = Array(tableStatuses.filter { $0.rowCount > 0 }.sorted { $0.rowCount > $1.rowCount }.prefix(8))
        let storageLeaders = Array(tableStatuses.filter { $0.dataLength > 0 }.sorted { $0.dataLength > $1.dataLength }.prefix(8))

        if !rowLeaders.isEmpty || !storageLeaders.isEmpty {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 360), spacing: 16)], spacing: 16) {
                if !rowLeaders.isEmpty {
                    chartCard(title: "Largest by Rows", subtitle: "Top tables by server-reported row estimate") {
                        Chart(rowLeaders) { status in
                            BarMark(
                                x: .value("Rows", status.rowCount),
                                y: .value("Table", status.name)
                            )
                            .foregroundStyle(.tint)
                            .cornerRadius(3)
                        }
                        .chartXAxis { AxisMarks(position: .bottom) }
                    }
                }
                if !storageLeaders.isEmpty {
                    chartCard(title: "Storage Distribution", subtitle: "Top tables by server-reported bytes") {
                        Chart(storageLeaders) { status in
                            BarMark(
                                x: .value("Bytes", status.dataLength),
                                y: .value("Table", status.name)
                            )
                            .foregroundStyle(.purple.gradient)
                            .cornerRadius(3)
                        }
                        .chartXAxis {
                            AxisMarks(position: .bottom) { value in
                                AxisGridLine()
                                AxisTick()
                                AxisValueLabel {
                                    if let bytes = value.as(Int.self) {
                                        Text(ByteCountFormatter.string(
                                            fromByteCount: Int64(bytes),
                                            countStyle: .file
                                        ))
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func chartCard<Content: View>(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            content()
                .frame(minHeight: 220)
        }
        .padding(18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
    }

    // MARK: - Tables Summary

    private var tablesSummarySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Tables").font(.headline)
                Spacer()
                Text("Select a table to browse its data")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            LazyVStack(spacing: 2) {
                ForEach(tableStatuses.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }) { status in
                    Button {
                        onOpenTable?(status.name)
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "tablecells")
                                .foregroundStyle(.tint)
                                .frame(width: 24)
                            Text(status.name)
                                .font(.system(.body, design: .monospaced, weight: .medium))
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(status.engine ?? "—")
                                .frame(width: 110, alignment: .leading)
                            Text(status.rowCount.formatted())
                                .monospacedDigit()
                                .frame(width: 100, alignment: .trailing)
                            Text(ByteCountFormatter.string(fromByteCount: Int64(status.dataLength), countStyle: .file))
                                .monospacedDigit()
                                .frame(width: 100, alignment: .trailing)
                            Image(systemName: "chevron.forward")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 10))
                    .help("Open \(status.name) in the Data tool")
                }
            }
            .padding(10)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
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
