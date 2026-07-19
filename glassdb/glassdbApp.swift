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
    #if os(macOS)
    static let settingsWindowSize = CGSize(width: 620, height: 540)
    #endif

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
        #if os(macOS)
        .commands {
            SidebarCommands()
            ToolbarCommands()
            DatabaseCommands()
        }
        #endif

        // Database workspace (schema sidebar + query editor + results)
        WindowGroup(id: "query-editor", for: UUID.self) { $sessionID in
            if let sessionID {
                DatabaseWorkspaceView(sessionID: sessionID)
                    .environment(sessionManager)
                    .environment(settingsManager)
            }
        }
        #if os(macOS)
        // Use native Mac window chrome so the Liquid Glass toolbar remains in
        // AppKit's titlebar hit-test region instead of covering SwiftUI content.
        // The workspace canvas remains clear through containerBackground.
        .windowToolbarStyle(.unifiedCompact)
        #else
        .windowStyle(.plain)
        #endif
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
        .defaultSize(width: 1000, height: 600)
        .restorationBehavior(.disabled)
        .defaultLaunchBehavior(.suppressed)

        // Settings use the platform-native scene on Mac (including Command-,)
        // and the established spatial window on Vision Pro.
        #if os(macOS)
        Settings {
            SettingsView()
                .environment(settingsManager)
                // The native Settings scene derives its window constraints from
                // the root view. Keep the scrolling Form inside a finite proposal
                // so AppKit does not enter a content-size constraint update loop.
                .frame(
                    width: Self.settingsWindowSize.width,
                    height: Self.settingsWindowSize.height
                )
        }
        .windowResizability(.contentSize)
        #else
        Window("Settings", id: "settings") {
            SettingsView()
                .environment(settingsManager)
        }
        .defaultSize(width: 700, height: 600)
        .defaultLaunchBehavior(.suppressed)
        #endif
    }
}

// MARK: - Bootstrap View

struct MainBootstrapView: View {
    @Environment(ConnectionManager.self) private var connectionManager
    @Environment(DatabaseSessionManager.self) private var sessionManager
    @Environment(SettingsManager.self) private var settingsManager
    #if os(macOS)
    @Environment(\.openSettings) private var openSettings
    #endif

    var body: some View {
        ConnectionManagerView()
            .task {
                connectionManager.loadIfNeeded()
                sessionManager.loadIfNeeded()
                settingsManager.loadIfNeeded()
                #if os(macOS)
                if ProcessInfo.processInfo.environment["GLASSDB_TEST_OPEN_SETTINGS"] == "1" {
                    openSettings()
                }
                #endif
            }
    }
}
