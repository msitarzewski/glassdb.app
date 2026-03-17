//
//  glassdbApp.swift
//  glassdb
//
//  App entry point with multi-window scene architecture
//  Pattern adapted from glas.sh glas_shApp.swift
//

import SwiftUI

@main
struct glassdbApp: App {
    @State private var connectionManager = ConnectionManager(loadImmediately: false)
    @State private var sessionManager = DatabaseSessionManager(loadImmediately: false)
    @State private var settingsManager = SettingsManager(loadImmediately: false)

    var body: some Scene {
        // Connection manager — PRIMARY WINDOW
        WindowGroup("Connections", id: "main") {
            MainBootstrapView()
                .environment(connectionManager)
                .environment(sessionManager)
                .environment(settingsManager)
        }
        .defaultSize(width: 1320, height: 760)
        .defaultLaunchBehavior(.presented)

        // Database workspace (schema sidebar + query editor + results)
        WindowGroup(id: "query-editor", for: UUID.self) { $sessionID in
            if let sessionID {
                DatabaseWorkspaceView(sessionID: sessionID)
                    .environment(sessionManager)
                    .environment(settingsManager)
            }
        }
        .windowStyle(.plain)
        .defaultSize(width: 1400, height: 900)
        .restorationBehavior(.disabled)
        .defaultLaunchBehavior(.suppressed)

        // Results grid windows (detachable — pin results in space)
        WindowGroup(id: "results", for: UUID.self) { $resultSetID in
            if let resultSetID {
                ResultsGridView(resultSetID: resultSetID)
                    .environment(sessionManager)
                    .environment(settingsManager)
            }
        }
        .windowStyle(.plain)
        .defaultSize(width: 1000, height: 600)
        .restorationBehavior(.disabled)
        .defaultLaunchBehavior(.suppressed)

        // Settings
        Window("Settings", id: "settings") {
            SettingsView()
                .environment(settingsManager)
        }
        .windowStyle(.plain)
        .defaultSize(width: 700, height: 600)
        .defaultLaunchBehavior(.suppressed)
    }
}

// MARK: - Bootstrap View

struct MainBootstrapView: View {
    @Environment(ConnectionManager.self) private var connectionManager
    @Environment(DatabaseSessionManager.self) private var sessionManager
    @Environment(SettingsManager.self) private var settingsManager

    var body: some View {
        ConnectionManagerView()
            .task {
                connectionManager.loadIfNeeded()
                sessionManager.loadIfNeeded()
                settingsManager.loadIfNeeded()
            }
    }
}