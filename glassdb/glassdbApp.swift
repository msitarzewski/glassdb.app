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
    #if os(iOS)
    @State private var iOSRouter = IOSAppRouter()
    #endif

    var body: some Scene {
        // Connection manager — PRIMARY WINDOW
        #if os(iOS)
        WindowGroup("Connections", id: "main") {
            IOSAppRoot()
                .environment(iOSRouter)
                .environment(connectionManager)
                .environment(sessionManager)
                .environment(settingsManager)
        }
        #else
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
            // DatabaseCommands replaces the system-generated File > New item
            // for this primary WindowGroup: ⌘N creates a SQL document in the
            // focused workspace and ⌘⇧N opens a Connections window.
            DatabaseCommands()
        }
        #endif
        #endif

        // Database workspace (schema sidebar + query editor + results)
        WindowGroup(id: "query-editor", for: UUID.self) { $workspaceID in
            if let workspaceID {
                let request = sessionManager.workspaceRequest(for: workspaceID)
                DatabaseWorkspaceView(
                    sessionID: request.sessionID,
                    initialSelection: request.initialSelection
                )
                    #if os(iOS)
                    .environment(iOSRouter)
                    #endif
                    .environment(sessionManager)
                    .environment(settingsManager)
                    .onDisappear {
                        sessionManager.releaseWorkspace(workspaceID)
                    }
            }
        }
        #if os(macOS)
        // Use native Mac window chrome so the Liquid Glass toolbar remains in
        // AppKit's titlebar hit-test region instead of covering SwiftUI content.
        // The workspace canvas remains clear through containerBackground.
        .windowToolbarStyle(.unifiedCompact)
        #elseif os(visionOS)
        .windowStyle(.plain)
        #endif
        #if !os(iOS)
        .defaultSize(width: 1400, height: 900)
        .restorationBehavior(.disabled)
        .defaultLaunchBehavior(.suppressed)
        #endif

        // Results grid windows (detachable — pin results in space)
        WindowGroup(id: "results", for: UUID.self) { $resultSetID in
            if let resultSetID {
                ResultsGridView(resultSetID: resultSetID)
                    .environment(sessionManager)
                    .environment(settingsManager)
            }
        }
        #if !os(iOS)
        .defaultSize(width: 1000, height: 600)
        .restorationBehavior(.disabled)
        .defaultLaunchBehavior(.suppressed)
        #endif

        // Settings use a sheet in the single-window iPhone route, a native
        // multiwindow scene on iPad, the platform Settings scene on Mac, and
        // the established spatial window on Vision Pro.
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
        #elseif os(iOS)
        WindowGroup("Settings", id: "settings") {
            IOSSettingsScene()
                .environment(settingsManager)
        }
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

#if os(iOS)
/// Routes iPhone database work inside the primary scene while leaving iPad's
/// `openWindow` path available for native multiwindow workspaces.
@MainActor
@Observable
final class IOSAppRouter {
    var workspaceRequest: DatabaseWorkspaceWindowRequest?
    var showsSettings = false

    func showWorkspace(_ request: DatabaseWorkspaceWindowRequest) {
        workspaceRequest = request
    }

    func showConnections() {
        workspaceRequest = nil
    }

    func showSettings() {
        showsSettings = true
    }
}

private struct IOSAppRoot: View {
    @Environment(ConnectionManager.self) private var connectionManager
    @Environment(DatabaseSessionManager.self) private var sessionManager
    @Environment(SettingsManager.self) private var settingsManager
    @Environment(IOSAppRouter.self) private var router

    var body: some View {
        @Bindable var router = router

        Group {
            if let request = router.workspaceRequest,
               sessionManager.session(for: request.sessionID) != nil {
                DatabaseWorkspaceView(
                    sessionID: request.sessionID,
                    initialSelection: request.initialSelection
                )
                .id(request.id)
            } else {
                MainBootstrapView()
            }
        }
        .environment(router)
        .environment(connectionManager)
        .environment(sessionManager)
        .environment(settingsManager)
        .sheet(isPresented: $router.showsSettings) {
            NavigationStack {
                SettingsView()
                    .environment(settingsManager)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                router.showsSettings = false
                            }
                        }
                    }
            }
        }
    }
}

/// iPad presents Settings in its own native scene. The system does not always
/// expose window chrome in full-screen or compact multitasking, so keep a
/// standard confirmation action inside the navigation bar as well.
private struct IOSSettingsScene: View {
    @Environment(\.dismissWindow) private var dismissWindow

    var body: some View {
        NavigationStack {
            SettingsView()
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            dismissWindow(id: "settings")
                        }
                    }
                }
        }
    }
}
#endif

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
