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
    @State private var windowRecoveryManager = WindowRecoveryManager()

    var body: some Scene {
        // Connection manager — PRIMARY WINDOW
        WindowGroup("Connections", id: "main") {
            MainBootstrapView()
                .environment(connectionManager)
                .environment(sessionManager)
                .environment(settingsManager)
                .trackWindowPresence(key: "main", recovery: windowRecoveryManager)
        }
        .defaultSize(width: 1320, height: 760)

        // Query editor windows (can open multiple — one per session)
        WindowGroup(id: "query-editor", for: UUID.self) { $sessionID in
            if let sessionID {
                QueryEditorView(sessionID: sessionID)
                    .environment(sessionManager)
                    .environment(settingsManager)
                    .trackWindowPresence(key: "query-\(sessionID)", recovery: windowRecoveryManager)
            }
        }
        .windowStyle(.plain)
        .defaultSize(width: 1200, height: 800)

        // Results grid windows (detachable — pin results in space)
        WindowGroup(id: "results", for: UUID.self) { $resultSetID in
            if let resultSetID {
                ResultsGridView(resultSetID: resultSetID)
                    .environment(sessionManager)
                    .trackWindowPresence(key: "results-\(resultSetID)", recovery: windowRecoveryManager)
            }
        }
        .windowStyle(.plain)
        .defaultSize(width: 1000, height: 600)

        // Schema browser
        WindowGroup(id: "schema", for: UUID.self) { $sessionID in
            if let sessionID {
                SchemaBrowserView(sessionID: sessionID)
                    .environment(sessionManager)
                    .trackWindowPresence(key: "schema-\(sessionID)", recovery: windowRecoveryManager)
            }
        }
        .windowStyle(.plain)
        .defaultSize(width: 400, height: 700)

        // Settings
        WindowGroup("Settings", id: "settings") {
            SettingsView()
                .environment(settingsManager)
                .trackWindowPresence(key: "settings", recovery: windowRecoveryManager)
        }
        .windowStyle(.plain)
        .defaultSize(width: 700, height: 600)
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

// MARK: - Window Presence Tracking

struct WindowPresenceTrackingModifier: ViewModifier {
    let key: String
    let recovery: WindowRecoveryManager

    func body(content: Content) -> some View {
        content
            .onAppear { recovery.markWindowVisible(key) }
            .onDisappear { recovery.markWindowHidden(key) }
    }
}

extension View {
    func trackWindowPresence(key: String, recovery: WindowRecoveryManager) -> some View {
        modifier(WindowPresenceTrackingModifier(key: key, recovery: recovery))
    }
}
