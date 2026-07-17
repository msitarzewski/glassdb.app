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
}

// MARK: - Workspace View

struct DatabaseWorkspaceView: View {
    let sessionID: UUID

    @Environment(DatabaseSessionManager.self) private var sessionManager
    @Environment(SettingsManager.self) private var settingsManager
    @Environment(\.openWindow) private var openWindow
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic
    @State private var selection: WorkspaceSelection? = .query
    @State private var databases: [String] = []

    private var session: DatabaseSession? {
        sessionManager.session(for: sessionID)
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SchemaBrowserView(sessionID: sessionID) { newSelection in
                selection = newSelection
            }
        } detail: {
            detailSurface
        }
        // Match glas.sh's terminal-window composition: paint and blur are
        // independent, and zero for both leaves the plain scene unbacked.
        .background {
            Rectangle()
                .fill(Color.black)
                .opacity(settingsManager.windowOpacity)
                .allowsHitTesting(false)
        }
        .modifier(DatabaseWorkspaceBackground(
            material: .ultraThinMaterial,
            blurAmount: settingsManager.blurBackground
        ))
        .navigationTitle(detailTitle)
        .toolbar(removing: .sidebarToggle)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
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
            ToolbarItemGroup(placement: .bottomOrnament) {
                Button {
                    selection = .query
                } label: {
                    Label("SQL Editor", systemImage: "text.page")
                }

                Button {
                    openWindow(id: "settings")
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }
            }
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

    @ViewBuilder
    private var detailSurface: some View {
        switch selection {
        case .table(let database, let table):
            TableDetailView(sessionID: sessionID, database: database, table: table)
        case .database(let database):
            DatabaseDetailView(sessionID: sessionID, database: database) {
                selection = .query
            }
        case .query, .none:
            QueryEditorView(sessionID: sessionID)
        }
    }

    private var detailTitle: String {
        switch selection {
        case .table(_, let table):
            return table
        case .database(let database):
            return database
        case .query, .none:
            return session?.connectionConfig.name ?? "Database"
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

/// Composites passthrough blur behind the workspace independently from its
/// opaque fill. A zero blur amount emits no material backing.
private struct DatabaseWorkspaceBackground: ViewModifier {
    let material: Material
    let blurAmount: Double

    func body(content: Content) -> some View {
        content.background {
            if blurAmount > 0 {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(material)
                    .opacity(blurAmount)
                    .allowsHitTesting(false)
            }
        }
    }
}
