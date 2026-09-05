//
//  ConnectionManagerView.swift
//  glassdb
//
//  Main hub — saved database connections
//  Pattern adapted from glas.sh ConnectionManagerView
//

import SwiftUI
import os
import GlasSecretStore
import GlassDBKit
#if os(iOS)
import UIKit
#endif

private struct PendingHostTrustAttempt {
    let connection: DatabaseConnectionConfig
    let password: String
    let sshPassword: String?
    let challenge: SSHHostKeyChallenge
}

private enum DatabaseConnectionCompactDestination: Hashable {
    case results
    case detail
}

struct ConnectionManagerView: View {
    @Environment(ConnectionManager.self) private var connectionManager
    @Environment(DatabaseSessionManager.self) private var sessionManager
    @Environment(SettingsManager.self) private var settingsManager
    @Environment(\.openWindow) private var openWindow
    #if os(macOS)
    @Environment(\.openSettings) private var openSettings
    #endif
    #if os(iOS)
    @Environment(IOSAppRouter.self) private var iOSRouter
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

    @State private var selectedConnectionID: UUID?
    @State private var selectedScope: DatabaseConnectionLibraryScope = .allConnections
    @State private var selectedMode: DatabaseConnectionLibraryMode = .all
    @State private var searchText = ""
    @State private var connectingConnectionID: UUID?
    @State private var connectionError: String?
    @State private var showingAddConnection = false
    @State private var editingConnection: DatabaseConnectionConfig?
    @State private var connectionPendingDeletion: DatabaseConnectionConfig?
    @State private var pendingHostTrustAttempt: PendingHostTrustAttempt?
    @FocusState private var searchFieldFocused: Bool
    #if os(iOS)
    @State private var compactNavigationPath: [DatabaseConnectionCompactDestination] = []
    #endif

    var body: some View {
        let connectionLibrary = DatabaseConnectionLibraryProjection(
            connections: connectionManager.connections
        )
        platformNavigation(connectionLibrary: connectionLibrary)
        .sheet(isPresented: $showingAddConnection) {
            ConnectionFormView(mode: .add) { connection, password, sshPassword in
                let credentialReceipt = try saveCredentials(
                    password: password,
                    sshPassword: sshPassword,
                    for: connection,
                    replacing: nil
                )
                do {
                    try connectionManager.add(connection)
                    searchText = ""
                    selectedMode = .all
                    selectedScope = .allConnections
                    selectedConnectionID = connection.id
                    #if os(iOS)
                    if horizontalSizeClass == .compact {
                        compactNavigationPath = [.results, .detail]
                    }
                    #endif
                } catch {
                    try restoreCredentials(credentialReceipt, after: error)
                }
            }
            .environment(sessionManager)
            .environment(settingsManager)
        }
        .sheet(item: $editingConnection) { connection in
            ConnectionFormView(mode: .edit(connection)) { updated, password, sshPassword in
                let credentialReceipt = try saveCredentials(
                    password: password,
                    sshPassword: sshPassword,
                    for: updated,
                    replacing: connection
                )
                do {
                    try connectionManager.update(updated)
                } catch {
                    try restoreCredentials(credentialReceipt, after: error)
                }
            }
            .environment(sessionManager)
            .environment(settingsManager)
        }
        .alert("Connection Error", isPresented: .init(
            get: { connectionError != nil || connectionManager.credentialError != nil },
            set: {
                if !$0 {
                    connectionError = nil
                    connectionManager.credentialError = nil
                }
            }
        )) {
            Button("OK") { connectionError = nil }
        } message: {
            Text(connectionError ?? connectionManager.credentialError ?? "")
        }
        .alert(
            pendingHostTrustAttempt?.challenge.reason == .changed ? "SSH Host Key Changed" : "Verify SSH Host",
            isPresented: .init(
                get: { pendingHostTrustAttempt != nil },
                set: { if !$0 { pendingHostTrustAttempt = nil } }
            )
        ) {
            Button("Trust & Retry", role: pendingHostTrustAttempt?.challenge.reason == .changed ? .destructive : nil) {
                trustPendingHostAndRetry()
            }
            Button("Cancel", role: .cancel) { pendingHostTrustAttempt = nil }
        } message: {
            if let challenge = pendingHostTrustAttempt?.challenge {
                Text("Host: \(challenge.host):\(challenge.port)\nAlgorithm: \(challenge.algorithm)\nFingerprint: \(challenge.fingerprintSHA256)\n\n\(challenge.reason == .changed ? "The saved host identity no longer matches. Confirm the server’s new fingerprint through a trusted channel before continuing." : "Confirm this fingerprint through a trusted channel before saving it.")")
            }
        }
        .alert(
            "Delete Connection?",
            isPresented: .init(
                get: { connectionPendingDeletion != nil },
                set: { if !$0 { connectionPendingDeletion = nil } }
            ),
            presenting: connectionPendingDeletion
        ) { connection in
            Button("Delete \(connection.name)", role: .destructive) {
                deleteConnection(connection)
            }
            Button("Cancel", role: .cancel) {
                connectionPendingDeletion = nil
            }
        } message: { connection in
            Text(deletionConfirmationMessage(for: connection))
        }
        .onAppear {
            if selectedConnectionID == nil {
                selectedConnectionID = connectionLibrary.connections.first?.id
            }
        }
        .onChange(of: connectionManager.connections.map(\.id)) { _, ids in
            if let selectedConnectionID, !ids.contains(selectedConnectionID) {
                self.selectedConnectionID = nil
            } else if selectedConnectionID == nil {
                selectedConnectionID = connectionLibrary.connections(
                    in: selectedScope,
                    searchQuery: searchText
                ).first?.id
            }
        }
        .onChange(of: connectionLibrary.connections(
            in: selectedScope,
            searchQuery: searchText
        ).map(\.id)) { _, _ in
            selectedConnectionID = connectionLibrary.resolvedSelection(
                preferredConnectionID: selectedConnectionID,
                in: selectedScope,
                searchQuery: searchText
            )
        }
        .onChange(of: connectionLibrary.collections.map(\.id)) { _, collectionIDs in
            guard selectedMode == .collections else { return }
            if case .collection(let selectedCollectionID) = selectedScope,
               collectionIDs.contains(selectedCollectionID) {
                return
            }
            selectedConnectionID = nil
            if let firstCollectionID = collectionIDs.first {
                selectedScope = .collection(firstCollectionID)
            } else {
                selectedMode = .all
                selectedScope = .allConnections
            }
        }
        #if os(iOS)
        .onChange(of: selectedConnectionID) { _, connectionID in
            updateCompactDetailPath(hasSelection: connectionID != nil)
        }
        .onChange(of: compactNavigationPath) { _, path in
            if path.last != .detail {
                selectedConnectionID = nil
            }
        }
        #endif
    }

    // MARK: - Connection Library Shells

    @ViewBuilder
    private func platformNavigation(
        connectionLibrary: DatabaseConnectionLibraryProjection
    ) -> some View {
        #if os(macOS)
        regularNavigation(connectionLibrary: connectionLibrary)
        #elseif os(visionOS)
        visionNavigation(connectionLibrary: connectionLibrary)
        #elseif os(iOS)
        if horizontalSizeClass == .compact {
            compactNavigation(connectionLibrary: connectionLibrary)
        } else {
            regularNavigation(connectionLibrary: connectionLibrary)
        }
        #else
        regularNavigation(connectionLibrary: connectionLibrary)
        #endif
    }

    private func regularNavigation(
        connectionLibrary: DatabaseConnectionLibraryProjection
    ) -> some View {
        NavigationSplitView {
            libraryNavigation(connectionLibrary: connectionLibrary)
                .connectionLibraryNavigationColumnWidth()
        } content: {
            connectionResults(connectionLibrary: connectionLibrary)
                .connectionLibraryResultsColumnWidth()
                .connectionLibraryColumnAutosave()
        } detail: {
            detailView(connectionLibrary: connectionLibrary)
        }
        #if os(macOS)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                addConnectionButton
            }
            ToolbarItem(placement: .confirmationAction) {
                // The Mac Settings scene is the platform `Settings` scene and
                // carries no window id, so `openWindow(id:)` silently does
                // nothing. `SettingsLink` is the supported route and matches
                // the workspace toolbar (`Constants.swift`).
                SettingsLink {
                    Label("Settings", systemImage: "gearshape")
                }
                .accessibilityIdentifier("database-connection-library-settings")
                .help("Open glassdb settings")
            }
        }
        #endif
    }

    #if os(visionOS)
    private func visionNavigation(
        connectionLibrary: DatabaseConnectionLibraryProjection
    ) -> some View {
        TabView(selection: visionModeSelection(in: connectionLibrary)) {
            ForEach(DatabaseConnectionLibraryMode.allCases) { mode in
                visionLibrary(mode: mode, connectionLibrary: connectionLibrary)
                    .tabItem {
                        Label(mode.title, systemImage: modeSystemImage(mode))
                            .accessibilityIdentifier(
                                "database-connection-library-mode-\(mode.rawValue)"
                            )
                    }
                    .tag(mode)
            }
        }
        .toolbar {
            ToolbarItem(placement: .bottomOrnament) {
                HStack {
                    addConnectionButton

                    Button("Settings", systemImage: "gearshape") {
                        showSettings()
                    }
                    .accessibilityIdentifier("database-connection-library-settings")
                }
            }
        }
    }

    @ViewBuilder
    private func visionLibrary(
        mode: DatabaseConnectionLibraryMode,
        connectionLibrary: DatabaseConnectionLibraryProjection
    ) -> some View {
        if mode == .collections {
            NavigationSplitView {
                collectionNavigation(connectionLibrary: connectionLibrary)
            } content: {
                connectionResults(connectionLibrary: connectionLibrary)
            } detail: {
                detailView(connectionLibrary: connectionLibrary)
            }
        } else {
            NavigationSplitView {
                connectionResults(connectionLibrary: connectionLibrary)
            } detail: {
                detailView(connectionLibrary: connectionLibrary)
            }
        }
    }

    private func visionModeSelection(
        in connectionLibrary: DatabaseConnectionLibraryProjection
    ) -> Binding<DatabaseConnectionLibraryMode> {
        Binding(
            get: { selectedMode },
            set: { selectMode($0, in: connectionLibrary) }
        )
    }
    #endif

    #if os(iOS)
    private func compactNavigation(
        connectionLibrary: DatabaseConnectionLibraryProjection
    ) -> some View {
        NavigationStack(path: $compactNavigationPath) {
            libraryNavigation(connectionLibrary: connectionLibrary)
                .navigationDestination(
                    for: DatabaseConnectionCompactDestination.self
                ) { destination in
                    switch destination {
                    case .results:
                        connectionResults(connectionLibrary: connectionLibrary)
                    case .detail:
                        detailView(connectionLibrary: connectionLibrary)
                    }
                }
        }
    }

    private func updateCompactDetailPath(hasSelection: Bool) {
        if hasSelection {
            guard compactNavigationPath.last == .results else { return }
            compactNavigationPath.append(.detail)
        } else if compactNavigationPath.last == .detail {
            compactNavigationPath.removeLast()
        }
    }
    #endif

    private func libraryNavigation(
        connectionLibrary: DatabaseConnectionLibraryProjection
    ) -> some View {
        List {
            Section("Library") {
                scopeNavigationButton(
                    mode: .all,
                    scope: .allConnections,
                    title: "All Connections",
                    count: connectionLibrary.itemCount(in: .allConnections)
                )
                scopeNavigationButton(
                    mode: .favorites,
                    scope: .favorites,
                    title: "Favorites",
                    count: connectionLibrary.itemCount(in: .favorites)
                )
                scopeNavigationButton(
                    mode: .recent,
                    scope: .recent,
                    title: "Recent",
                    count: connectionLibrary.itemCount(in: .recent)
                )
            }

            if !connectionLibrary.collections.isEmpty {
                Section("Collections") {
                    ForEach(connectionLibrary.collections) { collection in
                        scopeNavigationButton(
                            mode: .collections,
                            scope: .collection(collection.id),
                            title: collection.name,
                            count: collection.count
                        )
                    }
                }
            }
        }
        .accessibilityIdentifier("database-connection-library-navigation")
        .listStyle(.sidebar)
        .navigationTitle("Connections")
        .toolbar {
            #if os(iOS)
            ToolbarItem(placement: .primaryAction) {
                if horizontalSizeClass == .compact {
                    addConnectionButton
                }
            }
            #endif
            #if !os(macOS)
            ToolbarItem(placement: .secondaryAction) {
                Button("Settings", systemImage: "gearshape") {
                    showSettings()
                }
                .accessibilityIdentifier("database-connection-library-settings")
                .help("Open glassdb settings")
            }
            #endif
        }
    }

    private var addConnectionButton: some View {
        Button("Add Connection", systemImage: "plus") {
            showingAddConnection = true
        }
        .managerNewConnectionShortcut()
        .accessibilityIdentifier("database-connection-library-add")
        .help("Add a database connection")
    }

    private func collectionNavigation(
        connectionLibrary: DatabaseConnectionLibraryProjection
    ) -> some View {
        List {
            if connectionLibrary.collections.isEmpty {
                ContentUnavailableView(
                    "No Collections",
                    systemImage: "folder",
                    description: Text(
                        "Add a collection to a saved connection to organize it here."
                    )
                )
            } else {
                ForEach(connectionLibrary.collections) { collection in
                    scopeNavigationButton(
                        mode: .collections,
                        scope: .collection(collection.id),
                        title: collection.name,
                        count: collection.count
                    )
                }
            }
        }
        .accessibilityIdentifier("database-connection-library-collections")
        .listStyle(.sidebar)
        .navigationTitle("Collections")
    }

    private func scopeNavigationButton(
        mode: DatabaseConnectionLibraryMode,
        scope: DatabaseConnectionLibraryScope,
        title: String,
        count: Int
    ) -> some View {
        Button {
            selectedMode = mode
            selectedScope = scope
            selectedConnectionID = nil
            #if os(iOS)
            if horizontalSizeClass == .compact {
                compactNavigationPath = [.results]
            }
            #endif
        } label: {
            HStack {
                Label(title, systemImage: modeSystemImage(mode))
                Spacer()
                Text(count, format: .number)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(
            "database-connection-library-scope-\(scope.id)"
        )
        .listRowBackground(
            selectedScope == scope
                ? Color.accentColor.opacity(0.16)
                : Color.clear
        )
        .accessibilityAddTraits(selectedScope == scope ? .isSelected : [])
    }

    private func connectionResults(
        connectionLibrary: DatabaseConnectionLibraryProjection
    ) -> some View {
        let connections = connectionLibrary.connections(
            in: selectedScope,
            searchQuery: searchText
        )
        return List(selection: $selectedConnectionID) {
            if connections.isEmpty {
                if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    ContentUnavailableView {
                        Label(emptyResultsTitle, systemImage: modeSystemImage(selectedMode))
                    } description: {
                        Text(emptyResultsDescription)
                    } actions: {
                        if connectionManager.connections.isEmpty {
                            Button("Add Connection", systemImage: "plus") {
                                showingAddConnection = true
                            }
                        }
                    }
                    .accessibilityIdentifier(
                        "database-connection-library-empty-results"
                    )
                } else {
                    ContentUnavailableView.search(text: searchText)
                }
            } else {
                ForEach(connections) { connection in
                    connectionRow(connection)
                        .accessibilityIdentifier(
                            "database-connection-library-connection-\(connection.id.uuidString.lowercased())"
                        )
                }
            }
        }
        .accessibilityIdentifier("database-connection-library-results")
        .searchable(text: $searchText, prompt: "Search connections...")
        .searchFocused($searchFieldFocused)
        .databaseLookScrollEnabled()
        .navigationTitle(scopeTitle(in: connectionLibrary))
        #if os(iOS)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                addConnectionButton
            }
        }
        #endif
    }

    private func selectMode(
        _ mode: DatabaseConnectionLibraryMode,
        in connectionLibrary: DatabaseConnectionLibraryProjection
    ) {
        selectedMode = mode
        selectedConnectionID = nil
        switch mode {
        case .all:
            selectedScope = .allConnections
        case .favorites:
            selectedScope = .favorites
        case .recent:
            selectedScope = .recent
        case .collections:
            selectedScope = .collection(
                connectionLibrary.collections.first?.id ?? ""
            )
        }
    }

    private func modeSystemImage(
        _ mode: DatabaseConnectionLibraryMode
    ) -> String {
        switch mode {
        case .all: return "cylinder.split.1x2"
        case .favorites: return "star"
        case .recent: return "clock"
        case .collections: return "folder"
        }
    }

    private func scopeTitle(
        in connectionLibrary: DatabaseConnectionLibraryProjection
    ) -> String {
        switch selectedScope {
        case .allConnections: return "All Connections"
        case .favorites: return "Favorites"
        case .recent: return "Recent"
        case .collection(let collectionID):
            return connectionLibrary.collections
                .first { $0.id == collectionID }?.name ?? "Collections"
        }
    }

    private var emptyResultsTitle: String {
        switch selectedScope {
        case .allConnections: return "No Connections"
        case .favorites: return "No Favorites"
        case .recent: return "No Recent Connections"
        case .collection: return "No Connections"
        }
    }

    private var emptyResultsDescription: String {
        switch selectedScope {
        case .allConnections:
            return "Add a MySQL, PostgreSQL, or SQLite connection to begin."
        case .favorites:
            return "Mark a connection as a favorite to keep it in this scope."
        case .recent:
            return "Connections appear here after you use them."
        case .collection:
            return "Edit a connection to add it to this collection."
        }
    }

    // MARK: - Connection Row

    private func connectionRow(_ connection: DatabaseConnectionConfig) -> some View {
        #if os(iOS)
        connectionRowLabel(connection)
            .contentShape(Rectangle())
            .tag(connection.id)
            .onTapGesture {
                selectedConnectionID = connection.id
            }
            .contextMenu {
                connectionActions(for: connection)
            }
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                Button {
                    connectionManager.toggleFavorite(connection)
                } label: {
                    Label(
                        connection.isFavorite ? "Unfavorite" : "Favorite",
                        systemImage: connection.isFavorite ? "star.slash" : "star"
                    )
                }
                .tint(.yellow)
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button {
                    editingConnection = connection
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                .tint(.blue)

                Button(role: .destructive) {
                    connectionPendingDeletion = connection
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .disabled(activeSessionID(for: connection) != nil)
            }
            .accessibilityHint(
                "Opens connection details. Swipe for favorite, edit, and delete actions."
            )
        #elseif os(macOS)
        connectionRowLabel(connection)
            .contentShape(Rectangle())
            .tag(connection.id)
            .onTapGesture {
                selectedConnectionID = connection.id
            }
            .simultaneousGesture(
                TapGesture(count: 2).onEnded {
                    selectedConnectionID = connection.id
                    if let sessionID = activeSessionID(for: connection) {
                        openPrimaryWorkspace(sessionID: sessionID)
                    } else {
                        initiateConnection(connection)
                    }
                }
            )
            .contextMenu {
                connectionActions(for: connection)
            }
            .help("Select \(connection.name); double-click to connect or open its workspace")
        #else
        connectionRowLabel(connection)
            .contentShape(Rectangle())
            .tag(connection.id)
            .onTapGesture {
                selectedConnectionID = connection.id
            }
            .contextMenu {
                connectionActions(for: connection)
            }
        #endif
    }

    private func connectionRowLabel(_ connection: DatabaseConnectionConfig) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(connection.colorTag.color)
                .frame(width: 8, height: 8)
                .accessibilityLabel(connection.colorTag == .none ? "" : "\(connection.colorTag.displayName) tag")
                .accessibilityHidden(connection.colorTag == .none)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(connection.name)
                        .font(.headline)
                        .lineLimit(1)

                    if connection.isFavorite {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                            .font(.caption)
                            .accessibilityLabel("Favorite")
                    }
                }
                Text(connection.displaySubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            if activeSessionID(for: connection) != nil {
                Image(systemName: "bolt.fill")
                    .foregroundStyle(.green)
                    .font(.caption)
                    .accessibilityLabel("Active connection")
            } else {
                Image(systemName: connection.engine.iconName)
                    .foregroundStyle(.secondary)
                    .font(.caption)
                    .accessibilityLabel(connection.engine.displayName)
            }

            relativeLastConnectedLabel(for: connection)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }

    private func relativeLastConnectedLabel(
        for connection: DatabaseConnectionConfig
    ) -> Text {
        guard let lastConnected = connection.lastConnected else {
            return Text("Never")
        }

        let formatter = RelativeDateTimeFormatter()
        formatter.dateTimeStyle = .named
        formatter.unitsStyle = .abbreviated
        return Text(formatter.localizedString(for: lastConnected, relativeTo: Date()))
    }

    @ViewBuilder
    private func connectionActions(for connection: DatabaseConnectionConfig) -> some View {
        if let sessionID = activeSessionID(for: connection) {
            Button("Open Workspace", systemImage: "rectangle.split.2x1") {
                openPrimaryWorkspace(sessionID: sessionID)
            }
            #if os(iOS)
            if UIDevice.current.userInterfaceIdiom == .pad {
                Button("Open New Workspace Window", systemImage: "macwindow.badge.plus") {
                    openAdditionalWorkspace(sessionID: sessionID)
                }
            }
            #else
            Button("Open New Workspace Window", systemImage: "macwindow.badge.plus") {
                openAdditionalWorkspace(sessionID: sessionID)
            }
            #endif
            Button("Disconnect", systemImage: "xmark.circle") {
                Task { await sessionManager.disconnect(sessionID: sessionID) }
            }
        } else {
            Button("Connect", systemImage: "bolt") {
                initiateConnection(connection)
            }
            .disabled(connectingConnectionID != nil)
        }
        Divider()
        Button(connection.isFavorite ? "Remove from Favorites" : "Add to Favorites",
               systemImage: connection.isFavorite ? "star.slash" : "star") {
            connectionManager.toggleFavorite(connection)
        }
        Button("Edit Connection…", systemImage: "pencil") {
            editingConnection = connection
        }
        Divider()
        Button("Delete Connection…", systemImage: "trash", role: .destructive) {
            connectionPendingDeletion = connection
        }
        .disabled(activeSessionID(for: connection) != nil)
        .help(activeSessionID(for: connection) == nil
              ? "Delete this saved connection"
              : "Disconnect this connection before deleting it")
    }

    // MARK: - Detail View

    @ViewBuilder
    private func detailView(
        connectionLibrary: DatabaseConnectionLibraryProjection
    ) -> some View {
        if let id = selectedConnectionID,
           let connection = connectionManager.connection(for: id) {
            connectionDetail(connection)
        } else if connectionLibrary.connections.isEmpty {
            ContentUnavailableView {
                Label("No Connections", systemImage: "cylinder.split.1x2")
            } description: {
                Text("Add a MySQL, PostgreSQL, or SQLite connection to begin.")
            } actions: {
                Button("Add Connection", systemImage: "plus") {
                    showingAddConnection = true
                }
                .buttonStyle(.borderedProminent)
            }
        } else {
            ContentUnavailableView(
                "Select a Connection",
                systemImage: "cylinder",
                description: Text("Choose a database connection from the sidebar or add a new one.")
            )
        }
    }

    private func connectionDetail(
        _ connection: DatabaseConnectionConfig
    ) -> some View {
        VStack(spacing: 0) {
            Form {
                Section("Connection") {
                    LabeledContent("Engine", value: connection.engine.displayName)
                    if connection.engine == .sqlite {
                        LabeledContent(
                            "Database File",
                            value: URL(fileURLWithPath: connection.host).lastPathComponent
                        )
                    } else {
                        LabeledContent("Host", value: "\(connection.host):\(connection.port)")
                        LabeledContent("User", value: connection.username)
                        if let database = connection.defaultDatabase, !database.isEmpty {
                            LabeledContent("Database", value: database)
                        }
                    }
                }

                if connection.engine.supportsCredentials {
                    Section("Security") {
                        LabeledContent(
                            "Protection",
                            value: securitySummary(for: connection)
                        )
                    }
                }

                Section("Activity") {
                    LabeledContent("Status") {
                        if activeSessionID(for: connection) == nil {
                            Label("Disconnected", systemImage: "bolt.slash")
                                .foregroundStyle(.secondary)
                        } else {
                            Label("Connected", systemImage: "bolt.fill")
                                .foregroundStyle(.green)
                        }
                    }
                    LabeledContent("Last Connected") {
                        relativeLastConnectedLabel(for: connection)
                    }
                }

                if !connection.tags.isEmpty || connection.colorTag != .none {
                    Section("Organization") {
                        if !connection.tags.isEmpty {
                            LabeledContent(
                                "Collections",
                                value: connection.tags.joined(separator: ", ")
                            )
                        }
                        if connection.colorTag != .none {
                            LabeledContent(
                                "Color Tag",
                                value: connection.colorTag.displayName
                            )
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .databaseLookScrollEnabled()
            .accessibilityIdentifier(
                "database-connection-library-detail-\(connection.id.uuidString.lowercased())"
            )

            connectionDetailActions(connection)
                .padding()
                .background(.bar)
        }
        .navigationTitle(connection.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .secondaryAction) {
                Menu("Connection Actions", systemImage: "ellipsis.circle") {
                    connectionActions(for: connection)
                }
            }
        }
        #endif
    }

    private func connectionDetailActions(_ connection: DatabaseConnectionConfig) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                connectionDetailSecondaryActions(connection)
                Spacer()
                connectionDetailPrimaryAction(connection)
            }
            VStack(spacing: 12) {
                connectionDetailPrimaryAction(connection)
                HStack(spacing: 12) {
                    connectionDetailSecondaryActions(connection)
                }
            }
        }
    }

    @ViewBuilder
    private func connectionDetailPrimaryAction(_ connection: DatabaseConnectionConfig) -> some View {
        if let sessionID = activeSessionID(for: connection) {
            Button {
                openPrimaryWorkspace(sessionID: sessionID)
            } label: {
                Label("Open Workspace", systemImage: "rectangle.split.2x1")
            }
            .buttonStyle(.borderedProminent)
            .help("Open the SQL editor for this active connection")
        } else {
            Button {
                initiateConnection(connection)
            } label: {
                if connectingConnectionID == connection.id {
                    Label("Connecting…", systemImage: "bolt.horizontal.circle")
                } else {
                    Label("Connect", systemImage: "bolt")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(connectingConnectionID != nil)
            .help("Connect and open the SQL workspace")
        }
    }

    @ViewBuilder
    private func connectionDetailSecondaryActions(_ connection: DatabaseConnectionConfig) -> some View {
        Button {
            editingConnection = connection
        } label: {
            Label("Edit", systemImage: "pencil")
        }
        .disabled(connectingConnectionID == connection.id)
        .help("Edit connection, authentication, TLS, and SSH settings")

        if let sessionID = activeSessionID(for: connection) {
            Button(role: .destructive) {
                Task { await sessionManager.disconnect(sessionID: sessionID) }
            } label: {
                Label("Disconnect", systemImage: "xmark.circle")
            }
            .help("Close this database session")
        }
    }

    private func securitySummary(
        for connection: DatabaseConnectionConfig
    ) -> String {
        var parts = [connection.databaseCredentialPolicy.displayName]
        if connection.engine.supportsTLS {
            parts.append(connection.useTLS ? "TLS required" : "TLS off")
        }
        parts.append(connection.useSSHTunnel ? "SSH tunnel" : "Direct")
        return parts.joined(separator: " · ")
    }

    private func deletionConfirmationMessage(for connection: DatabaseConnectionConfig) -> String {
        if connection.engine == .sqlite {
            return "This removes the saved connection, its credentials, and its managed SQLite working copy. The original imported file is not changed. This action cannot be undone."
        }
        return "This removes the saved connection and its database and SSH credentials. The database server is not changed. This action cannot be undone."
    }

    private func deleteConnection(_ connection: DatabaseConnectionConfig) {
        connectionPendingDeletion = nil
        do {
            try connectionManager.delete(connection)
            if selectedConnectionID == connection.id {
                selectedConnectionID = nil
            }
        } catch {
            connectionError = "The connection was not deleted safely. \(error.localizedDescription)"
        }
    }

    // MARK: - Connection Logic

    private func initiateConnection(_ connection: DatabaseConnectionConfig) {
        guard connectingConnectionID == nil else { return }
        do {
            let dbPassword: String
            if connection.engine.supportsCredentials {
                do {
                    dbPassword = try KeychainManager.retrievePassword(for: connection)
                } catch SecretStoreError.notFound {
                    dbPassword = ""
                }
            } else {
                dbPassword = ""
            }
            let usesSSHKey = connection.sshAuthMethod == .sshKey
            var sshPassword: String?
            if connection.useSSHTunnel && !usesSSHKey {
                do {
                    sshPassword = try KeychainManager.retrieveSSHPassword(for: connection)
                } catch SecretStoreError.notFound {
                    sshPassword = ""
                }
            }
            Task { await connectWith(connection, password: dbPassword, sshPassword: sshPassword) }
        } catch {
            connectionError = "Saved credentials are unavailable. Edit this connection and save its credentials again. \(error.localizedDescription)"
        }
    }

    private func connectWith(_ connection: DatabaseConnectionConfig, password: String, sshPassword: String? = nil) async {
        connectingConnectionID = connection.id
        do {
            let sessionID = try await sessionManager.connect(
                config: connection,
                password: password,
                sshPassword: sshPassword
            )
            connectionManager.updateLastConnected(connection.id)
            openPrimaryWorkspace(sessionID: sessionID)
        } catch let trustError as SSHHostKeyTrustRequiredError {
            pendingHostTrustAttempt = PendingHostTrustAttempt(
                connection: connection,
                password: password,
                sshPassword: sshPassword,
                challenge: trustError.challenge
            )
        } catch {
            connectionError = error.localizedDescription
        }
        connectingConnectionID = nil
    }

    private func openPrimaryWorkspace(sessionID: UUID) {
        let request = DatabaseWorkspaceWindowRequest.primary(sessionID: sessionID)
        #if os(iOS)
        if UIDevice.current.userInterfaceIdiom == .phone {
            iOSRouter.showWorkspace(request)
            return
        }
        #endif
        openWindow(
            id: "query-editor",
            value: sessionManager.registerWorkspace(request)
        )
    }

    private func openAdditionalWorkspace(sessionID: UUID) {
        let request = DatabaseWorkspaceWindowRequest.additional(sessionID: sessionID)
        openWindow(
            id: "query-editor",
            value: sessionManager.registerWorkspace(request)
        )
    }

    private func showSettings() {
        #if os(iOS)
        if UIDevice.current.userInterfaceIdiom == .phone {
            iOSRouter.showSettings()
            return
        }
        openWindow(id: "settings")
        #elseif os(macOS)
        // No id'd Settings scene exists on Mac; see the toolbar note above.
        openSettings()
        #else
        openWindow(id: "settings")
        #endif
    }

    private func trustPendingHostAndRetry() {
        guard let attempt = pendingHostTrustAttempt else { return }
        do {
            try KeychainManager.saveHostKey(attempt.challenge)
            pendingHostTrustAttempt = nil
            Task {
                await connectWith(
                    attempt.connection,
                    password: attempt.password,
                    sshPassword: attempt.sshPassword
                )
            }
        } catch {
            pendingHostTrustAttempt = nil
            connectionError = "The SSH host key was not trusted because it could not be saved securely. \(error.localizedDescription)"
        }
    }

    private func activeSessionID(for connection: DatabaseConnectionConfig) -> UUID? {
        sessionManager.sessions.first { _, session in
            session.connectionConfig.id == connection.id && session.state.isConnected
        }?.key
    }

    // MARK: - Credential Persistence

    private func saveCredentials(
        password: String,
        sshPassword: String?,
        for connection: DatabaseConnectionConfig,
        replacing previousConnection: DatabaseConnectionConfig?
    ) throws -> KeychainManager.CredentialDeletionReceipt {
        let report = try KeychainManager.saveCredentials(
            databasePassword: password,
            sshPassword: sshPassword,
            for: connection,
            replacing: previousConnection
        )
        if !password.isEmpty {
            Logger.connections.info("Saved database password for connection \(connection.id, privacy: .public)")
        }
        if let sshPassword, !sshPassword.isEmpty {
            Logger.connections.info("Saved SSH password for connection \(connection.id, privacy: .public)")
        }
        if !report.cleanupWarnings.isEmpty {
            connectionManager.credentialError = report.cleanupWarnings.joined(separator: " ")
        }
        return report.rollbackReceipt
    }

    private func restoreCredentials(
        _ receipt: KeychainManager.CredentialDeletionReceipt,
        after persistenceError: Error
    ) throws -> Never {
        do {
            try KeychainManager.restoreCredentials(receipt)
        } catch {
            throw KeychainManager.CredentialPolicyError.mutationRollbackFailed
        }
        throw persistenceError
    }

}

private extension View {
    @ViewBuilder
    func managerNewConnectionShortcut() -> some View {
        #if os(macOS)
        self.keyboardShortcut("n", modifiers: [.command])
        #else
        self
        #endif
    }
}
