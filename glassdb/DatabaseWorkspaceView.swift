//
//  DatabaseWorkspaceView.swift
//  glassdb
//
//  Unified workspace: schema sidebar + context-sensitive detail surface
//  Selection in sidebar drives the detail view (DBeaver-style model)
//

import SwiftUI
import GlassDBKit

// MARK: - Selection Model

enum WorkspaceSelection: Hashable {
    case database(String)
    case table(database: String, table: String)
    case query

    var title: String {
        switch self {
        case .database(let database): database
        case .table(_, let table): table
        case .query: "SQL"
        }
    }

    var systemImage: String {
        switch self {
        case .database: "cylinder"
        case .table: "tablecells"
        case .query: "text.page"
        }
    }

    var helpText: String {
        switch self {
        case .database(let database): "Database inspector for \(database)"
        case .table(let database, let table): "Table editor for \(database).\(table)"
        case .query: "SQL editor"
        }
    }

    var isClosable: Bool { self != .query }
}

struct WorkspaceTabState: Equatable {
    private(set) var tabs: [WorkspaceSelection] = [.query]
    private(set) var selected: WorkspaceSelection = .query

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
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic
    @State private var tabState = WorkspaceTabState()
    @State private var databases: [String] = []

    private var session: DatabaseSession? {
        sessionManager.session(for: sessionID)
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SchemaBrowserView(sessionID: sessionID) { newSelection in
                tabState.open(newSelection)
            }
            .databaseSidebarColumnWidth()
            .databaseWorkspaceSidebarMaterial()
        } detail: {
            detailSurface
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .databaseWorkspaceWindowBackground()
        .databaseWorkspaceWindowChrome()
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
                    tabState.open(.query)
                } label: {
                    Label("SQL Editor", systemImage: "text.page")
                }
                .help("Show the SQL editor")

                Button {
                    openWindow(id: "settings")
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }
                .help("Open Settings")
            }
            #endif
        }
        .task {
            await loadDatabases()
        }
        .onAppear {
            if !settingsManager.showSidebarByDefault {
                columnVisibility = .detailOnly
            }
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
            // Keep Apple-provided titlebar, tab, and sidebar materials intact.
            // Only the live database canvas responds to opacity and blur.
            .modifier(DatabaseWorkspaceBackground(
                material: .ultraThinMaterial,
                fillOpacity: settingsManager.windowOpacity,
                blurAmount: settingsManager.blurBackground
            ))
        }
    }

    private var workspaceTabBar: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 6) {
                ForEach(tabState.tabs, id: \.self) { destination in
                    let isSelected = destination == tabState.selected
                    HStack(spacing: 2) {
                        Button {
                            tabState.open(destination)
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
        case .table(let database, let table):
            TableDetailView(
                sessionID: sessionID,
                database: database,
                table: table,
                isWorkspaceActive: isActive,
                onOpenSQLEditor: { tabState.open(.query) }
            )
        case .database(let database):
            DatabaseDetailView(
                sessionID: sessionID,
                database: database,
                isWorkspaceActive: isActive
            ) {
                tabState.open(.query)
            }
        case .query:
            QueryEditorView(
                sessionID: sessionID,
                isWorkspaceActive: isActive,
                onOpenSQLEditor: { tabState.open(.query) }
            )
        }
    }

    private var detailTitle: String {
        switch tabState.selected {
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
            _ = tabState.close(destination)
        }
    }

    private func loadDatabases() async {
        guard let connection = session?.connection else { return }
        do {
            databases = try await connection.databases()
        } catch {
            // Non-critical — sidebar also loads databases independently
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
        content.background(alignment: .center) {
            // Keep the layers in one background hierarchy. Separate chained
            // backgrounds can be reordered by NavigationSplitView's AppKit
            // compositor in light appearance, leaving only the pale material.
            // Blur is always behind paint, matching glas.sh's terminal canvas.
            ZStack {
                if blurAmount > 0 {
                    Rectangle()
                        .fill(material)
                        .opacity(blurAmount)
                }

                Rectangle()
                    .fill(Color.black)
                    .opacity(fillOpacity)
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .ignoresSafeArea()
        }
    }
}
