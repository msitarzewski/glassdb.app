//
//  DatabaseWorkspaceView.swift
//  glassdb
//
//  Unified workspace: schema sidebar + context-sensitive detail surface
//  Selection in sidebar drives the detail view (DBeaver-style model)
//

import SwiftUI
import GlassDBKit
#if os(iOS)
import UIKit
#endif

// MARK: - Selection Model

enum WorkspaceSelection: Hashable, Codable {
    case connection
    case database(String)
    case table(database: String, table: String)
    case query

    var title: String {
        switch self {
        case .connection: "Overview"
        case .database(let database): database
        case .table(_, let table): table
        case .query: "SQL"
        }
    }

    var systemImage: String {
        switch self {
        case .connection: "externaldrive.connected.to.line.below"
        case .database: "cylinder"
        case .table: "tablecells"
        case .query: "text.page"
        }
    }

    var helpText: String {
        switch self {
        case .connection: "Connection overview"
        case .database(let database): "Database inspector for \(database)"
        case .table(let database, let table): "Table editor for \(database).\(table)"
        case .query: "SQL editor"
        }
    }

    var isClosable: Bool {
        switch self {
        case .connection, .query: false
        case .database, .table: true
        }
    }

    var usesOverviewRefreshAction: Bool {
        switch self {
        case .connection, .database: true
        case .table, .query: false
        }
    }
}

/// Scene value for a database workspace. The session identifies the shared
/// live connection while `id` identifies one independent window over it.
struct DatabaseWorkspaceWindowRequest: Hashable, Codable, Identifiable {
    let id: UUID
    let sessionID: UUID
    let initialSelection: WorkspaceSelection

    static func primary(sessionID: UUID) -> Self {
        Self(id: sessionID, sessionID: sessionID, initialSelection: .connection)
    }

    static func additional(
        sessionID: UUID,
        initialSelection: WorkspaceSelection = .connection,
        id: UUID = UUID()
    ) -> Self {
        Self(id: id, sessionID: sessionID, initialSelection: initialSelection)
    }
}

struct WorkspaceTabState: Equatable {
    private(set) var tabs: [WorkspaceSelection]
    private(set) var selected: WorkspaceSelection

    init(initialSelection: WorkspaceSelection = .connection) {
        let permanentTabs: [WorkspaceSelection] = [.connection, .query]
        tabs = permanentTabs.contains(initialSelection)
            ? permanentTabs
            : permanentTabs + [initialSelection]
        selected = initialSelection
    }

    mutating func open(_ destination: WorkspaceSelection) {
        if case .database = destination {
            tabs.removeAll { existing in
                if case .database = existing { return true }
                return false
            }
        }
        if !tabs.contains(destination) {
            tabs.append(destination)
        }
        selected = destination
    }

    @discardableResult
    mutating func close(_ destination: WorkspaceSelection) -> Bool {
        guard destination.isClosable,
              let index = tabs.firstIndex(of: destination) else { return false }
        let wasSelected = selected == destination
        tabs.remove(at: index)
        if wasSelected {
            selected = tabs[min(index, tabs.count - 1)]
        }
        return true
    }
}

// MARK: - Workspace View

struct DatabaseWorkspaceView: View {
    let sessionID: UUID

    @Environment(DatabaseSessionManager.self) private var sessionManager
    @Environment(SettingsManager.self) private var settingsManager
    @Environment(\.openWindow) private var openWindow
    @Environment(\.scenePhase) private var scenePhase
    #if os(iOS)
    @Environment(IOSAppRouter.self) private var iOSRouter
    #endif
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic
    @State private var tabState: WorkspaceTabState
    @State private var databases: [String] = []
    @State private var overviewRefreshTrigger = 0

    private var session: DatabaseSession? {
        sessionManager.session(for: sessionID)
    }

    init(sessionID: UUID, initialSelection: WorkspaceSelection = .connection) {
        self.sessionID = sessionID
        _tabState = State(initialValue: WorkspaceTabState(initialSelection: initialSelection))
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SchemaBrowserView(
                sessionID: sessionID,
                selection: tabState.selected
            ) { newSelection in
                openWorkspace(newSelection)
            }
            .databaseSidebarColumnWidth()
            .databaseWorkspaceSidebarMaterial()
        } detail: {
            detailSurface
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .databaseWorkspaceWindowBackground()
        .databaseWorkspaceWindowChrome()
        .overlay {
            connectionRecoveryOverlay
        }
        .navigationTitle(detailTitle)
        #if os(macOS)
        .toolbar(removing: .title)
        #endif
        .databaseSidebarChrome()
        .focusedSceneValue(\.databaseWorkspaceCommandActions, workspaceCommandActions)
        .toolbar {
            #if !os(macOS)
            ToolbarItem(placement: databaseSidebarToolbarPlacement) {
                Button {
                    withAnimation {
                        columnVisibility = columnVisibility == .detailOnly
                            ? .automatic : .detailOnly
                    }
                } label: {
                    Label("Toggle Sidebar",
                          systemImage: columnVisibility == .detailOnly
                              ? "sidebar.left" : "sidebar.leading")
                }
            }
            #endif
            #if os(macOS)
            ToolbarItem {
                Text(detailTitle)
                    .font(.headline)
                    .lineLimit(1)
                    .help("Current workspace: \(detailTitle)")
                    .accessibilityLabel("Current workspace: \(detailTitle)")
            }
            .sharedBackgroundVisibility(.hidden)
            #endif
            #if !os(macOS)
            ToolbarItemGroup(placement: databaseToolbarPlacement) {
                Button {
                    openWorkspace(.query)
                } label: {
                    Label("SQL Editor", systemImage: "chevron.left.forwardslash.chevron.right")
                }
                .help("Show the SQL editor")
                .accessibilityLabel("SQL Editor")
                .accessibilityHint("Opens the connected SQL query editor")

                if tabState.selected.usesOverviewRefreshAction {
                    Button {
                        overviewRefreshTrigger &+= 1
                    } label: {
                        Label("Refresh Overview", systemImage: "arrow.clockwise")
                    }
                    .help("Reload the active overview")
                    .accessibilityLabel("Refresh Overview")
                    .accessibilityHint("Reloads the active connection or database overview")
                }

                Button {
                    #if os(iOS)
                    if UIDevice.current.userInterfaceIdiom == .phone {
                        iOSRouter.showSettings()
                    } else {
                        openWindow(id: "settings")
                    }
                    #else
                    openWindow(id: "settings")
                    #endif
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }
                .help("Open Settings")
                .accessibilityLabel("Settings")
                .accessibilityHint("Opens glassdb settings")
            }
            #endif
        }
        .task(id: sessionID) {
            await monitorConnectionState()
        }
        .onAppear {
            if !settingsManager.showSidebarByDefault {
                columnVisibility = .detailOnly
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task {
                    _ = await sessionManager.validateSessionAfterForeground(
                        sessionID: sessionID
                    )
                }
            } else {
                sessionManager.noteSessionSuspended(sessionID: sessionID)
            }
        }
    }

    // MARK: - Connection Recovery

    @ViewBuilder
    private var connectionRecoveryOverlay: some View {
        if let session, !session.state.isConnected {
            ZStack {
                Rectangle()
                    .fill(.black.opacity(0.22))
                    .background(.ultraThinMaterial)
                    .ignoresSafeArea()

                connectionRecoveryCard(for: session)
                    .padding(24)
            }
            .transition(.opacity)
            .zIndex(100)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Database connection unavailable")
        } else if session == nil {
            ZStack {
                Rectangle()
                    .fill(.black.opacity(0.22))
                    .background(.ultraThinMaterial)
                    .ignoresSafeArea()

                VStack(spacing: 16) {
                    Image(systemName: "cable.connector.slash")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text("Connection Closed")
                        .font(.title2.bold())
                    Text("This workspace's database session has ended.")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Show Connections") {
                        openWindow(id: "main")
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(28)
                .frame(maxWidth: 440)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.18), radius: 30, y: 12)
                .padding(24)
            }
            .transition(.opacity)
            .zIndex(100)
        }
    }

    private func connectionRecoveryCard(for session: DatabaseSession) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: recoveryIcon(for: session.state))
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(recoveryTint(for: session.state))
                    .symbolEffect(.pulse, isActive: session.state.isConnecting)
                    .frame(width: 34)

                VStack(alignment: .leading, spacing: 5) {
                    Text(recoveryTitle(for: session.state))
                        .font(.title2.bold())
                    Text(recoveryMessage(for: session.state))
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if let detail = session.lastConnectionError,
               !detail.isEmpty {
                Divider()
                Text(detail)
                    .font(.callout.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 10) {
                if session.state.isConnecting {
                    ProgressView()
                        .controlSize(.small)
                    Text("Restoring the saved connection…")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    Button {
                        Task {
                            try? await sessionManager.reconnect(sessionID: sessionID)
                        }
                    } label: {
                        Label("Reconnect", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .help("Reconnect with the credentials already saved for this connection")

                    Button("Show Connections") {
                        openWindow(id: "main")
                    }
                    .buttonStyle(.bordered)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(26)
        .frame(maxWidth: 520, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(recoveryTint(for: session.state).opacity(0.38), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.22), radius: 32, y: 14)
    }

    private func recoveryTitle(for state: SessionState) -> String {
        switch state {
        case .disconnected: "Disconnected"
        case .connecting: "Reconnecting…"
        case .error: "Couldn't Reconnect"
        case .connected: "Connected"
        }
    }

    private func recoveryMessage(for state: SessionState) -> String {
        switch state {
        case .disconnected:
            "The database connection timed out or was closed. Reconnect to continue without losing this workspace."
        case .connecting(let stage):
            stage.rawValue
        case .error:
            "glassdb couldn't restore the saved connection. Review the detail below, then try again."
        case .connected:
            "The database connection is ready."
        }
    }

    private func recoveryIcon(for state: SessionState) -> String {
        switch state {
        case .disconnected: "cable.connector.slash"
        case .connecting: "arrow.trianglehead.2.clockwise.rotate.90"
        case .error: "exclamationmark.triangle.fill"
        case .connected: "checkmark.circle.fill"
        }
    }

    private func recoveryTint(for state: SessionState) -> Color {
        switch state {
        case .disconnected: .orange
        case .connecting: .accentColor
        case .error: .red
        case .connected: .green
        }
    }

    private func monitorConnectionState() async {
        var wasConnected = false
        var isInitialCheck = true
        while !Task.isCancelled {
            if scenePhase == .active {
                let validation = await sessionManager.validateSessionAfterForeground(
                    sessionID: sessionID
                )
                let isConnected = validation == .connected
                if isConnected && !wasConnected {
                    await loadDatabases()
                    if !isInitialCheck {
                        NotificationCenter.default.post(
                            name: .glassdbRefreshData,
                            object: sessionID
                        )
                    }
                }
                wasConnected = isConnected
                isInitialCheck = false
            } else {
                sessionManager.noteSessionSuspended(sessionID: sessionID)
            }
            try? await Task.sleep(for: .seconds(5))
        }
    }

    // MARK: - Detail Surface

    private var detailSurface: some View {
        VStack(spacing: 0) {
            if tabState.tabs.count > 1 {
                workspaceTabBar
                    .overlay(alignment: .bottom) {
                        Divider()
                    }
            }

            ZStack {
                ForEach(tabState.tabs, id: \.self) { destination in
                    let isActive = destination == tabState.selected
                    workspaceContent(for: destination, isActive: isActive)
                        .id(destination)
                        .opacity(isActive ? 1 : 0)
                        .allowsHitTesting(isActive)
                        .accessibilityHidden(!isActive)
                        .zIndex(isActive ? 1 : 0)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        // Keep Apple-provided titlebar and sidebar materials intact. The SQL
        // tab strip belongs to the live database canvas and follows the same
        // user-controlled opacity and blur as its editor and results grid.
        .modifier(DatabaseWorkspaceBackground(
            material: .ultraThinMaterial,
            fillOpacity: settingsManager.windowOpacity,
            blurAmount: settingsManager.blurBackground
        ))
    }

    private var workspaceTabBar: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 6) {
                ForEach(tabState.tabs, id: \.self) { destination in
                    let isSelected = destination == tabState.selected
                    HStack(spacing: 2) {
                        Button {
                            openWorkspace(destination)
                        } label: {
                            Label(destination.title, systemImage: destination.systemImage)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .frame(maxWidth: 200)
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                        }
                        .buttonStyle(.plain)
                        .databaseWorkspaceTabControlTarget()
                        .accessibilityLabel(destination.helpText)
                        .accessibilityAddTraits(isSelected ? .isSelected : [])

                        if destination.isClosable {
                            Button {
                                closeWorkspace(destination)
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.borderless)
                            .databaseWorkspaceTabControlTarget()
                            .accessibilityLabel("Close \(destination.helpText)")
                        }
                    }
                    .padding(.horizontal, 4)
                    .background(
                        isSelected ? AnyShapeStyle(.regularMaterial) : AnyShapeStyle(Color.clear),
                        in: Capsule()
                    )
                    .help(destination.helpText)
                    .contextMenu {
                        if destination.isClosable {
                            Button("Close Tab", systemImage: "xmark") {
                                closeWorkspace(destination)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .scrollIndicators(.hidden)
        .databaseLookScrollEnabled()
        .background(.regularMaterial)
        .accessibilityLabel("Open database workspaces")
    }

    @ViewBuilder
    private func workspaceContent(
        for destination: WorkspaceSelection,
        isActive: Bool
    ) -> some View {
        switch destination {
        case .connection:
            ConnectionOverviewView(
                sessionID: sessionID,
                isWorkspaceActive: isActive,
                refreshTrigger: overviewRefreshTrigger,
                onOpenDatabase: { database in
                    openWorkspace(.database(database))
                },
                onOpenSQLEditor: {
                    openWorkspace(.query)
                }
            )
        case .table(let database, let table):
            TableDetailView(
                sessionID: sessionID,
                database: database,
                table: table,
                isWorkspaceActive: isActive,
                onOpenSQLEditor: { openWorkspace(.query) }
            )
        case .database(let database):
            DatabaseDetailView(
                sessionID: sessionID,
                database: database,
                isWorkspaceActive: isActive,
                refreshTrigger: overviewRefreshTrigger,
                onOpenTable: { table in
                    openWorkspace(.table(database: database, table: table))
                }
            ) {
                openWorkspace(.query)
            }
        case .query:
            QueryEditorView(
                sessionID: sessionID,
                isWorkspaceActive: isActive,
                onOpenSQLEditor: { openWorkspace(.query) }
            )
        }
    }

    private var detailTitle: String {
        switch tabState.selected {
        case .connection:
            return session?.connectionConfig.name ?? "Overview"
        case .table(let database, let table):
            return "\(database) · \(table)"
        case .database(let database):
            return database
        case .query:
            return session?.connectionConfig.name ?? "Database"
        }
    }

    private var workspaceCommandActions: DatabaseWorkspaceCommandActions {
        DatabaseWorkspaceCommandActions(
            canCloseTab: tabState.selected.isClosable,
            closeTab: { closeWorkspace(tabState.selected) }
        )
    }

    private func closeWorkspace(_ destination: WorkspaceSelection) {
        withAnimation(.snappy) {
            var updatedState = tabState
            guard updatedState.close(destination) else { return }
            tabState = updatedState
        }
    }

    /// Assign a new state value instead of mutating a nested `@State` value in
    /// an escaping sidebar/menu callback. This gives every SwiftUI scene an
    /// explicit invalidation, including regular-width iPad workspaces.
    private func openWorkspace(_ destination: WorkspaceSelection) {
        var updatedState = tabState
        updatedState.open(destination)
        withAnimation(.snappy) {
            tabState = updatedState
        }
    }

    private func loadDatabases() async {
        guard let connection = session?.connection else { return }
        do {
            databases = try await connection.databases()
        } catch {
            await sessionManager.handleConnectionFailure(error, sessionID: sessionID)
        }
    }
}

// MARK: - Workspace Background

/// Composites passthrough blur behind the database canvas independently from
/// its opaque fill. A zero blur amount emits no material backing.
private struct DatabaseWorkspaceBackground: ViewModifier {
    let material: Material
    let fillOpacity: Double
    let blurAmount: Double

    func body(content: Content) -> some View {
        let appearance = DatabaseGlassAppearance(opacity: fillOpacity, blur: blurAmount)
        content.background(alignment: .center) {
            ZStack {
                if appearance.compositesBlur {
                    #if os(macOS)
                    MacDatabaseCanvasVisualEffect(amount: appearance.blur)
                    #else
                    Rectangle()
                        .fill(material)
                        .opacity(appearance.blur)
                    #endif
                }

                Rectangle()
                    .fill(DatabaseCanvasPalette.background)
                    .opacity(appearance.opacity)
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            #if !os(macOS)
            .ignoresSafeArea()
            #endif
        }
    }
}
