//
//  DatabaseDetailView.swift
//  glassdb
//
//  Live connection and database overview surfaces.
//  Shows server details, storage summaries, charts, and quick actions.
//

import SwiftUI
import GlassDBKit
import Charts

struct ConnectionOverviewView: View {
    let sessionID: UUID
    var isWorkspaceActive = true
    var refreshTrigger = 0
    var onOpenDatabase: ((String) -> Void)?
    var onOpenSQLEditor: (() -> Void)?

    @Environment(DatabaseSessionManager.self) private var sessionManager

    @State private var serverVersion: String?
    @State private var databaseSummaries: [ConnectionDatabaseSummary] = []
    @State private var isLoading = false
    @State private var loadedNamespaceCount = 0
    @State private var namespaceCount = 0
    @State private var unavailableNamespaceCount = 0
    @State private var errorMessage: String?

    private var session: DatabaseSession? {
        sessionManager.session(for: sessionID)
    }

    private var config: DatabaseConnectionConfig? {
        session?.connectionConfig
    }

    private var namespaceLabel: String {
        session?.connection?.dialect == .postgresql ? "Schemas" : "Databases"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerSection
                actionsSection

                if isLoading {
                    loadingSection
                }

                if let errorMessage {
                    ContentUnavailableView(
                        "Overview Unavailable",
                        systemImage: "exclamationmark.triangle",
                        description: Text(errorMessage)
                    )
                } else {
                    metricsSection
                    connectionDetailsSection
                    partialResultsNotice
                    chartsSection
                    databasesSection
                }
            }
            .padding(28)
        }
        .databaseLookScrollEnabled()
        #if os(macOS)
        .toolbar {
            if isWorkspaceActive {
                ToolbarSpacer(.flexible, placement: databaseToolbarPlacement)
                DatabasePersistentToolbar {
                    onOpenSQLEditor?()
                }
                ToolbarItem(placement: databaseToolbarPlacement) {
                    Button {
                        Task { await loadOverview() }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .help("Reload server details and database statistics")
                    .accessibilityLabel("Reload Connection Overview")
                    .accessibilityHint("Refreshes the server version, connection details, and database statistics")
                    .disabled(isLoading)
                }
            }
        }
        #endif
        .task(id: isWorkspaceActive) {
            guard isWorkspaceActive else { return }
            await loadOverview()
        }
        .onChange(of: refreshTrigger) {
            guard isWorkspaceActive else { return }
            Task { await loadOverview() }
        }
        .onChange(of: session?.state) {
            guard isWorkspaceActive, session?.state.isConnected == true else { return }
            Task { await loadOverview() }
        }
    }

    private var headerSection: some View {
        HStack(spacing: 16) {
            Image(systemName: config?.engine.iconName ?? "externaldrive.connected.to.line.below")
                .font(.system(size: 34))
                .foregroundStyle(.tint)
                .frame(width: 54, height: 54)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))

            VStack(alignment: .leading, spacing: 4) {
                Text(config?.name ?? "Connection")
                    .font(.title.bold())
                HStack(spacing: 8) {
                    Text(config?.engine.displayName ?? session?.connection?.engineName ?? "Database")
                        .foregroundStyle(.secondary)
                    Label("Connected", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
                .font(.callout)
            }
            Spacer(minLength: 0)
        }
    }

    private var actionsSection: some View {
        HStack(spacing: 12) {
            Button {
                onOpenSQLEditor?()
            } label: {
                Label("SQL Editor", systemImage: "text.page")
            }
            .buttonStyle(.borderedProminent)

            if let database = session?.currentDatabase,
               !database.isEmpty {
                Button {
                    onOpenDatabase?(database)
                } label: {
                    Label("Open \(database)", systemImage: "cylinder")
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var loadingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if namespaceCount > 0 {
                ProgressView(
                    "Inspecting \(namespaceLabel.lowercased())…",
                    value: Double(loadedNamespaceCount),
                    total: Double(namespaceCount)
                )
                Text("\(loadedNamespaceCount.formatted()) of \(namespaceCount.formatted())")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ProgressView("Reading server details…")
            }
        }
        .padding(.vertical, 4)
    }

    private var metricsSection: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 12)], spacing: 12) {
            OverviewMetricCard(
                value: serverVersion ?? (isLoading ? "Loading…" : "Unavailable"),
                label: "Server version",
                systemImage: "server.rack"
            )
            OverviewMetricCard(
                value: databaseSummaries.count.formatted(),
                label: namespaceLabel,
                systemImage: "cylinder.split.1x2"
            )
            OverviewMetricCard(
                value: availableTableCount.map { $0.formatted() } ?? "Unavailable",
                label: "Tables",
                systemImage: "tablecells"
            )
            OverviewMetricCard(
                value: availableStorageBytes.map {
                    ByteCountFormatter.string(fromByteCount: Int64($0), countStyle: .file)
                } ?? "Unavailable",
                label: "Table storage",
                systemImage: "internaldrive"
            )
        }
    }

    private var availableTableCount: Int? {
        let counts = databaseSummaries.compactMap(\.tableCount)
        return counts.isEmpty ? nil : counts.reduce(0, +)
    }

    private var availableStorageBytes: Int? {
        let sizes = databaseSummaries.compactMap(\.storageBytes)
        return sizes.isEmpty ? nil : sizes.reduce(0, +)
    }

    private var connectionDetailsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Connection Details")
                .font(.headline)

            Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 12) {
                connectionDetailRow("Endpoint", value: endpointDescription, systemImage: "network")
                if config?.engine.supportsCredentials == true {
                    connectionDetailRow("User", value: config?.username ?? "—", systemImage: "person")
                }
                connectionDetailRow("Transport", value: transportDescription, systemImage: "lock.shield")
                connectionDetailRow(
                    "Active \(session?.connection?.dialect == .postgresql ? "schema" : "database")",
                    value: session?.currentDatabase ?? "Not selected",
                    systemImage: "cylinder"
                )
                if let config, config.useSSHTunnel {
                    connectionDetailRow("SSH route", value: sshRouteDescription(for: config), systemImage: "point.3.connected.trianglepath.dotted")
                }
            }
        }
        .padding(18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
    }

    private func connectionDetailRow(
        _ label: String,
        value: String,
        systemImage: String
    ) -> some View {
        GridRow {
            Label(label, systemImage: systemImage)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.body.monospaced())
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var partialResultsNotice: some View {
        if unavailableNamespaceCount > 0 {
            Label {
                Text("Statistics were unavailable for \(unavailableNamespaceCount.formatted()) \(unavailableNamespaceCount == 1 ? namespaceLabel.dropLast().lowercased() : namespaceLabel.lowercased()). You can still open them and use the SQL editor.")
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill")
            }
            .font(.callout)
            .foregroundStyle(.orange)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
        }
    }

    @ViewBuilder
    private var chartsSection: some View {
        let rowLeaders = Array(databaseSummaries.compactMap { summary -> ConnectionDatabaseChartValue? in
            guard let rows = summary.estimatedRows, rows > 0 else { return nil }
            return ConnectionDatabaseChartValue(name: summary.name, value: rows)
        }.sorted { $0.value > $1.value }.prefix(8))
        let storageLeaders = Array(databaseSummaries.compactMap { summary -> ConnectionDatabaseChartValue? in
            guard let bytes = summary.storageBytes, bytes > 0 else { return nil }
            return ConnectionDatabaseChartValue(name: summary.name, value: bytes)
        }.sorted { $0.value > $1.value }.prefix(8))

        if !rowLeaders.isEmpty || !storageLeaders.isEmpty {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 360), spacing: 16)], spacing: 16) {
                if !rowLeaders.isEmpty {
                    OverviewChartCard(
                        title: "Largest by Rows",
                        subtitle: "Top \(namespaceLabel.lowercased()) by server-reported row estimate"
                    ) {
                        Chart(rowLeaders) { item in
                            BarMark(
                                x: .value("Rows", item.value),
                                y: .value(namespaceLabel, item.name)
                            )
                            .foregroundStyle(.tint)
                            .cornerRadius(3)
                        }
                        .chartXAxis { AxisMarks(position: .bottom) }
                    }
                }

                if !storageLeaders.isEmpty {
                    OverviewChartCard(
                        title: "Storage Distribution",
                        subtitle: "Top \(namespaceLabel.lowercased()) by server-reported bytes"
                    ) {
                        Chart(storageLeaders) { item in
                            BarMark(
                                x: .value("Bytes", item.value),
                                y: .value(namespaceLabel, item.name)
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

    private var databasesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(namespaceLabel).font(.headline)
                Spacer()
                Text("Select one for table-level details")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if databaseSummaries.isEmpty, !isLoading {
                ContentUnavailableView(
                    "No \(namespaceLabel)",
                    systemImage: "cylinder",
                    description: Text("This account did not return any accessible \(namespaceLabel.lowercased()).")
                )
            } else {
                LazyVStack(spacing: 2) {
                    ForEach(databaseSummaries) { summary in
                        Button {
                            onOpenDatabase?(summary.name)
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: "cylinder")
                                    .foregroundStyle(.tint)
                                    .frame(width: 24)
                                Text(summary.name)
                                    .font(.system(.body, design: .monospaced, weight: .medium))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                overviewValue(summary.tableCount, suffix: "tables")
                                overviewValue(summary.estimatedRows, suffix: "rows")
                                Text(summary.storageDescription)
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
                        .help("Open \(summary.name) overview")
                    }
                }
                .padding(10)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    private func overviewValue(_ value: Int?, suffix: String) -> some View {
        Text(value.map { "\($0.formatted()) \(suffix)" } ?? "Unavailable")
            .foregroundStyle(value == nil ? .secondary : .primary)
            .monospacedDigit()
            .frame(width: 120, alignment: .trailing)
    }

    private var endpointDescription: String {
        guard let config else { return "Unavailable" }
        if config.engine == .sqlite {
            return config.host
        }
        return "\(config.host):\(config.port)"
    }

    private var transportDescription: String {
        guard let config else { return "Unavailable" }
        if config.engine == .sqlite { return "Local file" }
        return switch (config.useSSHTunnel, config.useTLS) {
        case (true, true): "SSH tunnel + required TLS"
        case (true, false): "SSH tunnel"
        case (false, true): "Required TLS"
        case (false, false): "Direct"
        }
    }

    private func sshRouteDescription(for config: DatabaseConnectionConfig) -> String {
        let host = config.sshHost ?? "Unavailable"
        let port = config.sshPort ?? 22
        let username = config.sshUsername.flatMap { $0.isEmpty ? nil : "\($0)@" } ?? ""
        return "\(username)\(host):\(port)"
    }

    @MainActor
    private func loadOverview() async {
        guard !isLoading else { return }
        guard let connection = session?.connection else {
            errorMessage = "The database session is no longer available."
            return
        }

        isLoading = true
        loadedNamespaceCount = 0
        namespaceCount = 0
        unavailableNamespaceCount = 0
        errorMessage = nil

        if connection.capabilities.contains(.serverVersion) {
            serverVersion = try? await connection.serverVersion()
        } else {
            serverVersion = nil
        }

        do {
            let databases = try await connection.databases()
            namespaceCount = databases.count
            databaseSummaries = []
            var summaries: [ConnectionDatabaseSummary] = []
            var unavailableCount = 0

            for database in databases {
                try Task.checkCancellation()
                let summary: ConnectionDatabaseSummary

                if connection.capabilities.contains(.tableStatistics) {
                    do {
                        let statuses = try await connection.tableStatus(in: database)
                        summary = ConnectionDatabaseSummary(name: database, statuses: statuses)
                    } catch {
                        if await connection.isConnected == false { throw error }
                        unavailableCount += 1
                        summary = ConnectionDatabaseSummary(name: database)
                    }
                } else if connection.capabilities.contains(.metadata) {
                    do {
                        let tables = try await connection.tables(in: database)
                        summary = ConnectionDatabaseSummary(name: database, tableCount: tables.count)
                    } catch {
                        if await connection.isConnected == false { throw error }
                        unavailableCount += 1
                        summary = ConnectionDatabaseSummary(name: database)
                    }
                } else {
                    summary = ConnectionDatabaseSummary(name: database)
                }

                summaries.append(summary)
                loadedNamespaceCount = summaries.count
                databaseSummaries = summaries.sorted {
                    $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                }
            }

            unavailableNamespaceCount = unavailableCount
        } catch is CancellationError {
            isLoading = false
            return
        } catch {
            await sessionManager.handleConnectionFailure(error, sessionID: sessionID)
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

struct ConnectionDatabaseSummary: Identifiable, Sendable {
    let name: String
    let tableCount: Int?
    let estimatedRows: Int?
    let storageBytes: Int?

    var id: String { name }

    init(name: String, tableCount: Int? = nil) {
        self.name = name
        self.tableCount = tableCount
        estimatedRows = nil
        storageBytes = nil
    }

    init(name: String, statuses: [TableStatus]) {
        self.name = name
        tableCount = statuses.count
        estimatedRows = statuses.reduce(0) { $0 + $1.rowCount }
        storageBytes = statuses.reduce(0) { $0 + $1.dataLength }
    }

    var storageDescription: String {
        guard let storageBytes else { return "Unavailable" }
        return ByteCountFormatter.string(fromByteCount: Int64(storageBytes), countStyle: .file)
    }
}

private struct ConnectionDatabaseChartValue: Identifiable {
    let name: String
    let value: Int
    var id: String { name }
}

struct DatabaseDetailView: View {
    let sessionID: UUID
    let database: String
    var isWorkspaceActive = true
    var refreshTrigger = 0
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
        #if os(macOS)
        .toolbar {
            if isWorkspaceActive {
                ToolbarSpacer(.flexible, placement: databaseToolbarPlacement)
                DatabasePersistentToolbar {
                    onOpenSQLEditor?()
                }
                ToolbarItem(placement: databaseToolbarPlacement) {
                    Button {
                        Task { await loadStatus() }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .help("Reload database statistics")
                    .accessibilityLabel("Reload Database Statistics")
                    .accessibilityHint("Refreshes table counts, storage totals, and charts")
                }
            }
        }
        #endif
        .task(id: isWorkspaceActive) {
            guard isWorkspaceActive else { return }
            await setActiveAndLoad()
        }
        .onChange(of: refreshTrigger) {
            guard isWorkspaceActive else { return }
            Task { await loadStatus() }
        }
        .onChange(of: session?.state) {
            guard isWorkspaceActive, session?.state.isConnected == true else { return }
            Task { await setActiveAndLoad() }
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
            OverviewMetricCard(value: tableStatuses.count.formatted(), label: "Tables", systemImage: "tablecells")
            OverviewMetricCard(value: totalRows, label: "Estimated rows", systemImage: "number")
            OverviewMetricCard(value: totalSize, label: "Table storage", systemImage: "internaldrive")
            OverviewMetricCard(value: engineSummary, label: "Storage engines", systemImage: "gearshape.2")
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
                    OverviewChartCard(title: "Largest by Rows", subtitle: "Top tables by server-reported row estimate") {
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
                    OverviewChartCard(title: "Storage Distribution", subtitle: "Top tables by server-reported bytes") {
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
        guard !isLoading else { return }
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
            await sessionManager.handleConnectionFailure(error, sessionID: sessionID)
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

private struct OverviewMetricCard: View {
    let value: String
    let label: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.title3.bold())
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)
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
}

private struct OverviewChartCard<Content: View>: View {
    let title: String
    let subtitle: String
    let content: Content

    init(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            content
                .frame(minHeight: 220)
        }
        .padding(18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
    }
}
