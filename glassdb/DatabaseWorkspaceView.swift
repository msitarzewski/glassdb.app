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
            ToolbarItemGroup(placement: .primaryAction) {
                if case .query = selection {
                    // Query-mode toolbar items are provided by QueryEditorView
                } else {
                    Button {
                        selection = .query
                    } label: {
                        Label("SQL Editor", systemImage: "text.page")
                    }
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
