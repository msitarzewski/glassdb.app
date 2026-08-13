import Foundation
import Testing
import GlassDBKit
import GlassConnectionKit
import GlassEditorCore
import GlassEditorUI
import GlasSecretStore
import Security
@testable import glassdb
#if os(macOS)
import AppKit
import SwiftUI
#endif

private enum SSHMetadataTestError: Error, Equatable {
    case deletionFailed
}

private enum IntegrityTestError: Error, Equatable {
    case persistenceFailed
    case credentialSaveFailed
    case credentialDeleteFailed
}

private final class ConnectionPersistenceTestState {
    var data: Data?
    var failWrites = false
    var mutateBeforeFailure = false

    var store: ConnectionPersistenceStore {
        ConnectionPersistenceStore(
            load: { [self] in data },
            save: { [self] candidate in
                if mutateBeforeFailure {
                    data = candidate
                }
                guard !failWrites else { throw IntegrityTestError.persistenceFailed }
                data = candidate
            },
            restore: { [self] previous in
                data = previous
            }
        )
    }
}

private struct CredentialMutationTestKey: Hashable {
    let account: String
    let service: String
    let accessGroup: String?
}

private final class CredentialMutationTestState {
    var values: [CredentialMutationTestKey: String] = [:]
    var failNextSaveAccount: String?
    var failNextDeleteAccount: String?

    func key(
        account: String,
        descriptor: KeychainManager.CredentialStorageDescriptor
    ) -> CredentialMutationTestKey {
        CredentialMutationTestKey(
            account: account,
            service: descriptor.service,
            accessGroup: descriptor.config.accessGroup
        )
    }

    var store: KeychainManager.CredentialMutationStore {
        KeychainManager.CredentialMutationStore(
            retrieve: { [self] account, descriptor in
                values[key(account: account, descriptor: descriptor)]
            },
            save: { [self] value, account, descriptor in
                values[key(account: account, descriptor: descriptor)] = value
                if failNextSaveAccount == account {
                    failNextSaveAccount = nil
                    throw IntegrityTestError.credentialSaveFailed
                }
            },
            delete: { [self] account, descriptor in
                values.removeValue(forKey: key(account: account, descriptor: descriptor))
                if failNextDeleteAccount == account {
                    failNextDeleteAccount = nil
                    throw IntegrityTestError.credentialDeleteFailed
                }
            }
        )
    }
}

private final class SSHKeyLifecycleTestState {
    var materials: [UUID: SSHKeyMaterial] = [:]
    var failNextDeleteAfterRemoval = false

    var store: SSHKeyLifecycleStore {
        SSHKeyLifecycleStore(
            retrieve: { [self] keyID in materials[keyID] },
            save: { [self] keyID, material in materials[keyID] = material },
            delete: { [self] keyID in
                materials.removeValue(forKey: keyID)
                if failNextDeleteAfterRemoval {
                    failNextDeleteAfterRemoval = false
                    throw SSHMetadataTestError.deletionFailed
                }
            }
        )
    }
}

/// Minimal aggregate-capable connection. DatabaseSessionManager's aggregate
/// statistics path needs a deterministic grouped result plus a server
/// round-trip counter, and no shipping engine can provide that in-process
/// (SQLite intentionally lacks `.aggregateTableStatistics`).
private final class AggregateStatisticsTestConnection: DatabaseConnection, @unchecked Sendable {
    private let lock = NSLock()
    private var storedGroupedResult: [String: [TableStatus]]
    private var storedAggregateCallCount = 0

    init(groupedResult: [String: [TableStatus]]) {
        storedGroupedResult = groupedResult
    }

    var aggregateCallCount: Int {
        lock.withLock { storedAggregateCallCount }
    }

    var isConnected: Bool { get async { true } }
    var engineName: String { "AggregateTest" }
    var capabilities: Set<DatabaseCapability> {
        [.metadata, .tableStatistics, .aggregateTableStatistics]
    }

    /// NSLock's lock()/unlock() are unavailable from async contexts, so the
    /// async protocol methods delegate to synchronous locked accessors.
    private func recordAggregateCall() -> [String: [TableStatus]] {
        lock.withLock {
            storedAggregateCallCount += 1
            return storedGroupedResult
        }
    }

    private var groupedResult: [String: [TableStatus]] {
        lock.withLock { storedGroupedResult }
    }

    func tableStatusByNamespace() async throws -> [String: [TableStatus]] {
        recordAggregateCall()
    }

    func execute(_ query: String, parameters: [DatabaseValue]) async throws -> QueryResult {
        QueryResult(query: query, executionTime: 0)
    }

    func close() async throws {}

    func databases() async throws -> [String] {
        groupedResult.keys.sorted()
    }

    func tables(in database: String) async throws -> [String] { [] }
    func columns(in table: String, database: String) async throws -> [ColumnInfo] { [] }
    func showCreateTable(_ table: String, database: String) async throws -> String { "" }
    func indexes(in table: String, database: String) async throws -> [IndexInfo] { [] }
    func foreignKeys(in table: String, database: String) async throws -> [ForeignKeyInfo] { [] }

    func tableStatus(in database: String) async throws -> [TableStatus] {
        groupedResult[database] ?? []
    }

    func rowCount(table: String, database: String) async throws -> Int { 0 }
}

struct glassdbTests {
    @Test func databaseSidebarsShareOrderedMacLayoutPolicy() {
        #expect(DatabaseSidebarLayout.minimumWidth == 300)
        #expect(DatabaseSidebarLayout.idealWidth == 340)
        #expect(DatabaseSidebarLayout.maximumWidth == 440)
        #expect(DatabaseSidebarLayout.minimumWidth <= DatabaseSidebarLayout.idealWidth)
        #expect(DatabaseSidebarLayout.idealWidth <= DatabaseSidebarLayout.maximumWidth)
    }

    @Test func databaseGlassAppearancePreservesIndependentEndpoints() {
        let transparent = DatabaseGlassAppearance(opacity: 0, blur: 0)
        #expect(transparent.isFullyTransparent)
        #expect(!transparent.paintsCanvas)
        #expect(!transparent.compositesBlur)
        #expect(transparent.surfaceAlpha() == 0)
        #expect(transparent.pinnedSurfaceAlpha == 0)
        #expect(transparent.pinnedBlurAlpha == 0)

        let frosted = DatabaseGlassAppearance(opacity: 0, blur: 1)
        #expect(!frosted.paintsCanvas)
        #expect(frosted.compositesBlur)
        #expect(!frosted.isFullyTransparent)

        let painted = DatabaseGlassAppearance(opacity: 1, blur: 0)
        #expect(painted.paintsCanvas)
        #expect(!painted.compositesBlur)
        #expect(painted.surfaceAlpha() == 0.06)
        #expect(painted.pinnedSurfaceAlpha == 1)

        let combined = DatabaseGlassAppearance(opacity: 1, blur: 1)
        #expect(combined.paintsCanvas)
        #expect(combined.compositesBlur)
        #expect(combined.pinnedBlurAlpha == 1)

        let intermediate = DatabaseGlassAppearance(opacity: 0.25, blur: 0)
        #expect(intermediate.pinnedSurfaceAlpha == 0.5)
        #expect(intermediate.pinnedSurfaceAlpha > intermediate.opacity)

        let intermediateBlur = DatabaseGlassAppearance(opacity: 0, blur: 0.25)
        #expect(intermediateBlur.pinnedBlurAlpha == 0.5)
        #expect(intermediateBlur.pinnedBlurAlpha > intermediateBlur.blur)
    }

    @Test func databaseGlassAppearanceClampsInvalidInputs() {
        let appearance = DatabaseGlassAppearance(opacity: 2, blur: -Double.infinity)
        #expect(appearance.opacity == 1)
        #expect(appearance.blur == 0)
        #expect(appearance.surfaceAlpha(strength: 2) == 1)
    }

    @Test func workspaceTabsStartWithOnlyOverviewAndDeduplicateTables() {
        var state = WorkspaceTabState()
        let table = WorkspaceSelection.table(database: "analytics", table: "events")
        let query = WorkspaceSelection.query(id: UUID())

        #expect(state.tabs == [.connection])
        #expect(state.selected == .connection)

        state.open(table)
        state.open(query)
        state.open(table)

        #expect(state.tabs == [.connection, table, query])
        #expect(state.selected == table)
    }

    @Test func commandWTargetsTheSelectedTopLevelWorkspace() {
        var state = WorkspaceTabState()
        let table = WorkspaceSelection.table(database: "analytics", table: "events")
        let query = WorkspaceSelection.query(id: UUID())

        #expect(state.selected.commandWEditorTarget == .none)
        state.open(query)
        #expect(state.selected.commandWEditorTarget == .workspace)
        state.open(table)
        #expect(state.tabs.contains(query))
        #expect(state.selected.commandWEditorTarget == .workspace)
    }

    @Test func workspaceTabsKeepMultipleSQLDocumentsAtTheTopLevel() {
        var state = WorkspaceTabState()
        let first = WorkspaceSelection.query(id: UUID())
        let second = WorkspaceSelection.query(id: UUID())

        state.open(first)
        state.open(second)

        #expect(first != second)
        #expect(state.tabs.suffix(2) == [first, second])
        #expect(state.selected == second)
        let didCloseFirst = state.close(first)
        #expect(didCloseFirst)
        #expect(state.selected == second)
    }

    #if os(macOS)
    @Test @MainActor func commandWMenuRouterConsumesOnlyRegisteredWorkspaceWindows() {
        let workspaceWindow = NSWindow()
        let otherWindow = NSWindow()
        let router = MacDatabaseCommandWRouter()
        let workspaceID = UUID()
        var workspaceCloseCount = 0

        router.update(
            id: workspaceID,
            window: workspaceWindow,
            priority: DatabaseCommandWTargetPriority.workspace.rawValue,
            isEnabled: true
        ) {
            workspaceCloseCount += 1
        }

        #expect(router.routeClose(targetWindow: workspaceWindow))
        #expect(workspaceCloseCount == 1)
        #expect(!router.routeClose(targetWindow: otherWindow))

        router.update(
            id: workspaceID,
            window: workspaceWindow,
            priority: DatabaseCommandWTargetPriority.workspace.rawValue,
            isEnabled: false
        ) {
            workspaceCloseCount += 1
        }
        #expect(router.routeClose(targetWindow: workspaceWindow))
        #expect(workspaceCloseCount == 1)
    }

    @Test @MainActor func commandWMenuRouterInstallsOnTheNativeFileMenuItem() {
        let mainMenu = NSMenu()
        let fileItem = NSMenuItem(title: "File", action: nil, keyEquivalent: "")
        let fileMenu = NSMenu(title: "File")
        let closeItem = NSMenuItem(
            title: "Close",
            action: #selector(NSWindow.performClose(_:)),
            keyEquivalent: "w"
        )
        closeItem.keyEquivalentModifierMask = .command
        fileMenu.addItem(closeItem)
        fileItem.submenu = fileMenu
        mainMenu.addItem(fileItem)

        let router = MacDatabaseCommandWRouter()
        router.installCloseCommandInterceptor(in: mainMenu)

        #expect(closeItem.target === router)
        #expect(closeItem.action != #selector(NSWindow.performClose(_:)))
    }
    #endif

    @Test func queryTabsPromptOnlyWhenClosingWouldDiscardChanges() {
        var untitled = QueryDocumentTab()
        #expect(!untitled.hasUnsavedChanges)

        untitled.text = "SELECT * FROM events"
        #expect(untitled.hasUnsavedChanges)

        untitled.markSaved()
        #expect(!untitled.hasUnsavedChanges)

        untitled.text += " WHERE severity = 'critical'"
        #expect(untitled.hasUnsavedChanges)

        let imported = QueryDocumentTab(text: "SELECT 1", isSaved: true)
        #expect(!imported.hasUnsavedChanges)
    }

    @Test func workspaceWindowRequestsKeepPrimaryStableAndAdditionalWindowsUnique() throws {
        let sessionID = UUID()
        let primary = DatabaseWorkspaceWindowRequest.primary(sessionID: sessionID)
        let samePrimary = DatabaseWorkspaceWindowRequest.primary(sessionID: sessionID)
        let databaseWindow = DatabaseWorkspaceWindowRequest.additional(
            sessionID: sessionID,
            initialSelection: .database("analytics")
        )
        let secondDatabaseWindow = DatabaseWorkspaceWindowRequest.additional(
            sessionID: sessionID,
            initialSelection: .database("analytics")
        )
        let overviewWindow = DatabaseWorkspaceWindowRequest.additional(sessionID: sessionID)

        #expect(primary == samePrimary)
        #expect(primary.initialSelection == .connection)
        #expect(overviewWindow.initialSelection == .connection)
        #expect(primary.sessionID == databaseWindow.sessionID)
        #expect(databaseWindow != secondDatabaseWindow)

        let decoded = try JSONDecoder().decode(
            DatabaseWorkspaceWindowRequest.self,
            from: JSONEncoder().encode(databaseWindow)
        )
        #expect(decoded == databaseWindow)
    }

    @MainActor
    @Test func workspaceRegistryKeepsUUIDSceneValuesAndRichLaunchContext() {
        let manager = DatabaseSessionManager(loadImmediately: false)
        let sessionID = UUID()
        let request = DatabaseWorkspaceWindowRequest.additional(
            sessionID: sessionID,
            initialSelection: .database("analytics")
        )

        let sceneValue = manager.registerWorkspace(request)
        #expect(sceneValue == request.id)
        #expect(manager.workspaceRequest(for: sceneValue) == request)

        manager.releaseWorkspace(sceneValue)
        #expect(manager.workspaceRequests[sceneValue] == nil)

        let legacySessionID = UUID()
        let fallback = manager.workspaceRequest(for: legacySessionID)
        #expect(fallback.id == legacySessionID)
        #expect(fallback.sessionID == legacySessionID)
        #expect(fallback.initialSelection == .connection)
    }

    @Test func workspaceTabsStartAtRequestedSelectionBesideOnlyOverview() {
        let database = WorkspaceSelection.database("analytics")
        let databaseState = WorkspaceTabState(initialSelection: database)
        #expect(databaseState.tabs == [.connection, database])
        #expect(databaseState.selected == database)

        let restoredQuery = WorkspaceSelection.query(id: UUID())
        let queryState = WorkspaceTabState(initialSelection: restoredQuery)
        #expect(queryState.tabs == [.connection, restoredQuery])
        #expect(queryState.selected == restoredQuery)
    }

    @Test func overviewRefreshActionOnlyAppearsForOverviewDestinations() {
        #expect(WorkspaceSelection.connection.usesOverviewRefreshAction)
        #expect(WorkspaceSelection.database("analytics").usesOverviewRefreshAction)
        #expect(!WorkspaceSelection.table(database: "analytics", table: "events").usesOverviewRefreshAction)
        #expect(!WorkspaceSelection.query(id: UUID()).usesOverviewRefreshAction)
    }

    @Test func workspaceTabsUseFullDatabaseAndTableIdentity() {
        var state = WorkspaceTabState()
        let first = WorkspaceSelection.table(database: "ab", table: "c")
        let second = WorkspaceSelection.table(database: "a", table: "bc")
        let sameNameOtherDatabase = WorkspaceSelection.table(database: "archive", table: "c")

        state.open(first)
        state.open(second)
        state.open(sameNameOtherDatabase)

        #expect(first != second)
        #expect(state.tabs == [.connection, first, second, sameNameOtherDatabase])
        #expect(state.selected == sameNameOtherDatabase)
    }

    @Test func workspaceTabsKeepOneReplaceableDatabasePreview() {
        var state = WorkspaceTabState()
        let table = WorkspaceSelection.table(database: "analytics", table: "events")
        state.open(table)
        state.open(.database("analytics"))
        state.open(.database("archive"))

        #expect(state.tabs == [.connection, table, .database("archive")])
        #expect(state.selected == .database("archive"))
    }

    @Test func workspaceSingleClickPreviewsDoNotCreateOrSelectTabs() {
        var state = WorkspaceTabState()
        let query = WorkspaceSelection.query(id: UUID())
        let database = WorkspaceSelection.database("analytics")
        let table = WorkspaceSelection.table(database: "analytics", table: "events")

        state.open(query)
        state.preview(database)
        #expect(state.tabs == [.connection, query])
        #expect(state.selected == query)
        #expect(state.previewed == database)
        #expect(state.displayed == database)

        state.preview(table)
        #expect(state.tabs == [.connection, query])
        #expect(state.selected == query)
        #expect(state.previewed == table)
        #expect(state.displayed == table)
    }

    @Test func workspaceDoubleClickActivationPromotesPreviewToPersistentTab() {
        var state = WorkspaceTabState()
        let database = WorkspaceSelection.database("analytics")
        let table = WorkspaceSelection.table(database: "analytics", table: "events")

        state.preview(database)
        state.open(database)
        #expect(state.tabs == [.connection, database])
        #expect(state.selected == database)
        #expect(state.previewed == nil)

        state.preview(table)
        state.open(table)
        #expect(state.tabs == [.connection, database, table])
        #expect(state.selected == table)
        #expect(state.previewed == nil)
    }

    @Test func workspaceActivationWinsWhenSingleClickArrivesAfterDoubleClick() throws {
        var state = WorkspaceTabState()
        let database = WorkspaceSelection.database("analytics")
        let table = WorkspaceSelection.table(database: "analytics", table: "events")

        state.open(database)
        state.preview(database)
        #expect(state.selected == database)
        #expect(state.displayed == database)
        #expect(state.previewed == nil)

        state.open(table)
        state.preview(table)
        #expect(state.selected == table)
        #expect(state.displayed == table)
        #expect(state.previewed == nil)
    }

    @Test func workspaceTabsCloseSelectedUsingRightThenLeftThenOverviewFallback() {
        var state = WorkspaceTabState()
        let query = WorkspaceSelection.query(id: UUID())
        state.open(query)
        let first = WorkspaceSelection.table(database: "db", table: "first")
        let middle = WorkspaceSelection.table(database: "db", table: "middle")
        let last = WorkspaceSelection.table(database: "db", table: "last")
        state.open(first)
        state.open(middle)
        state.open(last)
        state.open(middle)

        let closedMiddle = state.close(middle)
        #expect(closedMiddle)
        #expect(state.tabs == [.connection, query, first, last])
        #expect(state.selected == last)

        let closedLast = state.close(last)
        #expect(closedLast)
        #expect(state.tabs == [.connection, query, first])
        #expect(state.selected == first)

        let closedFirst = state.close(first)
        #expect(closedFirst)
        #expect(state.tabs == [.connection, query])
        #expect(state.selected == query)

        let closedQuery = state.close(query)
        #expect(closedQuery)
        #expect(state.tabs == [.connection])
        #expect(state.selected == .connection)
    }

    @Test func workspaceTabsCloseInactiveWithoutChangingSelectionAndRejectInvalidCloses() {
        var state = WorkspaceTabState()
        let query = WorkspaceSelection.query(id: UUID())
        state.open(query)
        let first = WorkspaceSelection.table(database: "db", table: "first")
        let selected = WorkspaceSelection.table(database: "db", table: "selected")
        let missing = WorkspaceSelection.table(database: "db", table: "missing")
        state.open(first)
        state.open(selected)

        let closedInactive = state.close(first)
        #expect(closedInactive)
        #expect(state.tabs == [.connection, query, selected])
        #expect(state.selected == selected)

        let beforeRejectedCloses = state
        let closedOverview = state.close(.connection)
        let closedMissing = state.close(missing)
        #expect(!closedOverview)
        #expect(!closedMissing)
        #expect(state == beforeRejectedCloses)
    }

    @Test func connectionOverviewSummarizesOnlyLiveTableStatusValues() {
        let capturedAt = Date(timeIntervalSince1970: 1_775_000_000)
        let summary = ConnectionDatabaseSummary(
            name: "analytics",
            snapshot: DatabaseStatisticsSnapshot(
                database: "analytics",
                statuses: [
                    TableStatus(name: "events", engine: "InnoDB", rowCount: 120, dataLength: 2_048, collation: nil),
                    TableStatus(name: "users", engine: "InnoDB", rowCount: 30, dataLength: 1_024, collation: nil)
                ],
                capturedAt: capturedAt
            )
        )

        #expect(summary.name == "analytics")
        #expect(summary.tableCount == 2)
        #expect(summary.estimatedRows == 150)
        #expect(summary.storageBytes == 3_072)
        #expect(summary.statisticsCapturedAt == capturedAt)

        let unavailable = ConnectionDatabaseSummary(name: "restricted")
        #expect(unavailable.tableCount == nil)
        #expect(unavailable.estimatedRows == nil)
        #expect(unavailable.storageBytes == nil)
        #expect(unavailable.statisticsCapturedAt == nil)
    }

    @Test func databaseStatisticsSnapshotsEnforceTheirFreshnessBoundaryAndTableLookup() throws {
        let capturedAt = Date(timeIntervalSince1970: 1_775_000_000)
        let status = TableStatus(
            name: "events",
            engine: "PostgreSQL",
            rowCount: 120,
            dataLength: 2_048,
            collation: nil
        )
        let snapshot = DatabaseStatisticsSnapshot(
            database: "analytics",
            statuses: [status],
            capturedAt: capturedAt
        )

        #expect(snapshot.isFresh(at: capturedAt))
        #expect(snapshot.isFresh(at: capturedAt.addingTimeInterval(
            DatabaseStatisticsSnapshot.timeToLive - 1
        )))
        #expect(!snapshot.isFresh(at: capturedAt.addingTimeInterval(
            DatabaseStatisticsSnapshot.timeToLive
        )))
        #expect(snapshot.status(for: "events")?.rowCount == 120)
        #expect(snapshot.status(for: "missing") == nil)
    }

    #if os(macOS)
    @Test @MainActor func macDatabaseWorkspacePolicyPreservesInteractiveNativeChrome() throws {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 600),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.toolbar = NSToolbar(identifier: "app.glassdb.tests.workspace-toolbar")

        MacDatabaseWorkspaceWindowPolicy.apply(window)
        MacDatabaseWorkspaceWindowPolicy.apply(window)

        #expect(!window.isOpaque)
        #expect(window.backgroundColor.alphaComponent == 0)
        #expect(!window.titlebarAppearsTransparent)
        #expect(!window.styleMask.contains(.fullSizeContentView))
        #expect(!window.ignoresMouseEvents)
        #expect(!window.isMovableByWindowBackground)
        // AppKit may normalize NSToolbar.sizeMode asynchronously when tests run
        // concurrently; the window-level style is the durable contract.
        #expect(window.toolbarStyle == .unifiedCompact)

        let themeFrame = try #require(window.contentView?.superview)
        let titlebarMaterials = themeFrame.subviews.compactMap {
            $0 as? MacDatabaseWorkspaceTitlebarMaterialView
        }
        #expect(titlebarMaterials.count == 1)
        let titlebarMaterial = try #require(titlebarMaterials.first)
        #expect(titlebarMaterial.hitTest(.zero) == nil)
    }

    @Test @MainActor func macSettingsLayoutHasFiniteStableContentSize() throws {
        let settingsManager = SettingsManager(loadImmediately: false)
        let size = glassdbApp.settingsWindowSize
        let content = SettingsView()
            .environment(settingsManager)
            .frame(width: size.width, height: size.height)
        let hostingView = NSHostingView(rootView: content)
        hostingView.frame = NSRect(origin: .zero, size: size)

        for _ in 0..<10 {
            hostingView.needsLayout = true
            hostingView.layoutSubtreeIfNeeded()
        }

        let fittingSize = hostingView.fittingSize
        #expect(fittingSize.width.isFinite)
        #expect(fittingSize.height.isFinite)
        #expect(abs(fittingSize.width - size.width) < 1)
        #expect(abs(fittingSize.height - size.height) < 1)

        if let capturePath = ProcessInfo.processInfo.environment["GLASSDB_SETTINGS_CAPTURE_PATH"] {
            hostingView.displayIfNeeded()
            let bitmap = try #require(
                hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds)
            )
            hostingView.cacheDisplay(in: hostingView.bounds, to: bitmap)
            let png = try #require(bitmap.representation(using: .png, properties: [:]))
            try png.write(to: URL(fileURLWithPath: capturePath), options: .atomic)
        }
    }
    #endif

    @Test func recordEditorAddDraftsRequireExplicitValuesOnlyWhenNoDefaultExists() {
        let required = StagedEdit.initialValue(
            for: ColumnInfo(name: "count", type: "int", isNullable: false),
            columnIndex: 0
        )
        #expect(!required.useDefault)
        #expect(!required.isNull)
        #expect(required.validationError != nil)

        let nullable = StagedEdit.initialValue(
            for: ColumnInfo(name: "note", type: "text", isNullable: true),
            columnIndex: 1
        )
        #expect(!nullable.useDefault)
        #expect(nullable.isNull)
        #expect(nullable.validationError == nil)

        let defaulted = StagedEdit.initialValue(
            for: ColumnInfo(name: "created_at", type: "timestamp", isNullable: false, defaultValue: "CURRENT_TIMESTAMP"),
            columnIndex: 2
        )
        #expect(defaulted.useDefault)
        #expect(defaulted.validationError == nil)

        let generated = StagedEdit.initialValue(
            for: ColumnInfo(name: "id", type: "bigint", isNullable: false, isGenerated: true),
            columnIndex: 3
        )
        #expect(generated.useDefault)
        #expect(generated.validationError == nil)
    }

    @Test func recordAndFilterDraftValidationReuseTypedValueParsing() {
        var requiredValue = StagedEdit.initialValue(
            for: ColumnInfo(name: "quantity", type: "int", isNullable: false),
            columnIndex: 0
        )
        requiredValue.editText = "12"
        #expect(requiredValue.validationError == nil)
        requiredValue.editText = "twelve"
        #expect(requiredValue.validationError?.contains("integer") == true)
        requiredValue.isNull = true
        #expect(requiredValue.validationError?.contains("cannot be NULL") == true)

        let invalidNumericFilter = GridColumnFilter(
            columnName: "quantity",
            columnType: "int",
            operation: .greaterThan,
            value: "many"
        )
        #expect(invalidNumericFilter.validationError?.contains("integer") == true)

        let emptyTextFilter = GridColumnFilter(
            columnName: "note",
            columnType: "text",
            operation: .equals,
            value: ""
        )
        #expect(emptyTextFilter.validationError == nil)

        let nullFilter = GridColumnFilter(
            columnName: "quantity",
            columnType: "int",
            operation: .isNull,
            value: "ignored"
        )
        #expect(nullFilter.validationError == nil)
    }

    @Test func recordJSONFormattingIsHumanReadableButDatabaseValueIsCompact() throws {
        let source = #"{"message":"spaces and \\t stay","nested":{"enabled":true},"items":[1,2]}"#
        let formatted = try RecordJSONText.pretty(source)
        #expect(formatted.contains("\n"))
        #expect(formatted.contains(#""spaces and \\t stay""#))
        #expect(RecordJSONText.isEquivalent(source, formatted))

        let staged = StagedEdit(
            columnIndex: 0,
            columnName: "payload",
            columnType: "jsonb",
            isPrimaryKey: false,
            isNullable: false,
            isUnsigned: false,
            isGenerated: false,
            defaultValue: nil,
            originalValue: .json(source),
            editText: formatted,
            isNull: false,
            useDefault: false
        )
        #expect(!staged.isModified)
        #expect(try staged.boundValue() == .json(source))
    }

    @Test @MainActor func glassEditorModelMirrorsJSONStagingSemantics() throws {
        let source = #"{"message":"stays","items":[1,2]}"#
        let model = GlassEditorModel(
            snapshot: DocumentSnapshot(
                content: source,
                encoding: .utf8(hadBOM: false),
                lineEndings: .lf,
                origin: .ephemeral(id: UUID())
            ),
            configuration: GlassEditorConfiguration(showsLineNumbers: false),
            language: .json,
            surfaceCondition: .opaque
        )
        #expect(model.text == source)
        #expect(!model.isDirty)

        // Format-button push: an external rewrite lands verbatim and the
        // staging model's whitespace-aware equivalence still reads clean.
        let formatted = try RecordJSONText.pretty(source)
        try model.replaceAllContent(with: formatted)
        #expect(model.text == formatted)
        #expect(RecordJSONText.isEquivalent(model.text, source))

        // The echo guard in fieldBinding compares model text directly; a
        // same-content push must be detectable as a no-op.
        #expect(model.text == formatted)
    }

    @Test func recordJSONCompactionPreservesStringWhitespaceAndNumberLexemes() throws {
        let source = """
        {
          "message": "human spaces  stay",
          "escaped": "tab:\\t",
          "precise": 18446744073709551615
        }
        """
        #expect(
            try RecordJSONText.compact(source)
                == #"{"message":"human spaces  stay","escaped":"tab:\t","precise":18446744073709551615}"#
        )
    }

    @Test func connectionTestStatusKeepsServerErrorsOutOfTheCompactRow() {
        let serverMessage = "MySQL error: Access denied for user 'root'@'localhost'"
        let failure = ConnectionFormView.TestResult.failure(serverMessage)

        #expect(failure.statusTitle == "Failed")
        #expect(failure.errorMessage == serverMessage)
        #expect(!failure.statusTitle.contains("Access denied"))
        #expect(ConnectionFormView.TestResult.testing.statusTitle == "Testing…")
        #expect(ConnectionFormView.TestResult.success.statusTitle == "Passed")
        #expect(ConnectionFormView.TestResult.success.errorMessage == nil)
    }

    @Test @MainActor func connectionFormValidationGatesDatabaseSQLiteAndSSHTunnelInputs() {
        let valid = ConnectionFormView.ValidationInput(
            name: "Production",
            engine: .mysql,
            host: "db.example.com",
            port: "3306",
            username: "database-user",
            sqliteFileExists: false,
            useSSHTunnel: false,
            sshHost: "",
            sshPort: "22",
            sshUsername: "",
            sshAuthMethod: .password,
            sshKeyIsUsable: false
        )
        #expect(ConnectionFormView.validationIssues(for: valid).isEmpty)

        let invalidNetwork = ConnectionFormView.ValidationInput(
            name: " ",
            engine: .postgresql,
            host: "",
            port: "70000",
            username: "",
            sqliteFileExists: false,
            useSSHTunnel: true,
            sshHost: "",
            sshPort: "zero",
            sshUsername: "",
            sshAuthMethod: .sshKey,
            sshKeyIsUsable: false
        )
        let networkIssues = ConnectionFormView.validationIssues(for: invalidNetwork)
        #expect(Set(networkIssues.keys) == Set([
            .name, .host, .port, .username, .sshHost, .sshPort, .sshUsername, .sshKey
        ]))

        let missingSQLite = ConnectionFormView.ValidationInput(
            name: "Local",
            engine: .sqlite,
            host: "/missing/database.sqlite",
            port: "0",
            username: "",
            sqliteFileExists: false,
            useSSHTunnel: true,
            sshHost: "",
            sshPort: "invalid",
            sshUsername: "",
            sshAuthMethod: .sshKey,
            sshKeyIsUsable: false
        )
        #expect(Set(ConnectionFormView.validationIssues(for: missingSQLite).keys) == Set([.host]))
    }

    @Test @MainActor func connectionFormSubmissionOnlyAdvancesOrDismissesFocus() {
        let fields: [ConnectionFormView.FormField] = [
            .name, .host, .port, .username, .password
        ]

        #expect(ConnectionFormView.nextField(after: .name, in: fields) == .host)
        #expect(ConnectionFormView.nextField(after: .port, in: fields) == .username)
        #expect(ConnectionFormView.nextField(after: .password, in: fields) == nil)
        #expect(ConnectionFormView.nextField(after: .sshHost, in: fields) == nil)
    }

    @Test func connectionLibraryProjectsUniqueScopedSearchableConnections() throws {
        let baseline = Date(timeIntervalSince1970: 1_700_000_000)
        let productionID = UUID()
        let analyticsID = UUID()
        let archiveID = UUID()
        let production = DatabaseConnectionConfig(
            id: productionID,
            name: "Zulu Production",
            engine: .mysql,
            host: "db.example.com",
            port: 3306,
            username: "app",
            defaultDatabase: "orders",
            isFavorite: true,
            dateAdded: baseline,
            lastConnected: baseline.addingTimeInterval(30),
            tags: [" Production ", "production", "Client A"]
        )
        let analytics = DatabaseConnectionConfig(
            id: analyticsID,
            name: "Alpha Analytics",
            engine: .postgresql,
            host: "analytics.example.com",
            port: 5432,
            username: "analyst",
            defaultDatabase: "warehouse",
            isFavorite: true,
            dateAdded: baseline.addingTimeInterval(20),
            lastConnected: baseline.addingTimeInterval(10),
            tags: ["PRODUCTION", "Résumé"]
        )
        let archive = DatabaseConnectionConfig(
            id: archiveID,
            name: "Local Archive",
            engine: .sqlite,
            host: "/managed/archive.sqlite",
            port: 0,
            username: "",
            dateAdded: baseline.addingTimeInterval(40),
            tags: ["resume", " "]
        )
        var duplicateProduction = production
        duplicateProduction.name = "Duplicate Must Not Surface"

        let library = DatabaseConnectionLibraryProjection(
            connections: [production, analytics, archive, duplicateProduction]
        )

        #expect(library.connections.map(\.id) == [analyticsID, archiveID, productionID])
        #expect(library.favoriteConnectionIDs == [productionID, analyticsID])
        #expect(library.recentConnectionIDs == [productionID, analyticsID])
        #expect(
            library.collection(named: "production")?.connectionIDs
                == [analyticsID, productionID]
        )
        #expect(library.collection(named: "résumé")?.count == 2)
        #expect(library.collection(named: "client a")?.connectionIDs == [productionID])
        #expect(library.connections(in: .favorites).map(\.id) == [productionID, analyticsID])
        #expect(library.connections(in: .recent).map(\.id) == [productionID, analyticsID])
        #expect(library.connections(in: .allConnections, searchQuery: "postgresql").map(\.id) == [analyticsID])
        #expect(library.connections(in: .allConnections, searchQuery: "orders").map(\.id) == [productionID])
        #expect(library.connections(in: .allConnections, searchQuery: "client a").map(\.id) == [productionID])
        #expect(library.connections(in: .allConnections, searchQuery: "  archive  ").map(\.id) == [archiveID])
        #expect(
            library.resolvedSelection(
                preferredConnectionID: analyticsID,
                in: .favorites
            ) == analyticsID
        )
        #expect(
            library.resolvedSelection(
                preferredConnectionID: archiveID,
                in: .favorites
            ) == nil
        )
    }

    @Test func connectionLibraryNormalizesCollectionTagsForPersistence() {
        let tags = DatabaseConnectionLibraryProjection.normalizedTags([
            " Production ",
            "production",
            "CLIENT A",
            "client a",
            "Résumé",
            "resume",
            "",
            "   "
        ])
        let normalizedIDs = Set(
            tags.compactMap(DatabaseConnectionLibraryProjection.collectionID(for:))
        )

        #expect(tags.count == 3)
        #expect(normalizedIDs == Set(["production", "client a", "resume"]))
    }

    @Test func sqlParserPreservesQuotedAndCommentSemicolons() {
        let script = """
        -- semicolon ; in a comment
        SELECT 'one;two' AS value;
        UPDATE `odd;table` SET value = 42 WHERE id = 1;
        # another ; comment
        SELECT 3
        """

        let statements = SQLHighlighter.statements(in: script)

        #expect(statements.count == 3)
        #expect(statements[0].text.contains("one;two"))
        #expect(statements[1].safety == .mutation)
        #expect(statements[2].safety == .readOnly)
    }

    @Test func sqlParserPreservesConditionalRoutineBodies() {
        let script = """
        CREATE PROCEDURE example()
        BEGIN
            IF 1 = 1 THEN
                SELECT 'inside;value';
            END IF;
            SELECT 2;
        END;
        SELECT 3;
        """

        let statements = SQLHighlighter.statements(in: script)

        #expect(statements.count == 2)
        #expect(statements[0].text.contains("END IF"))
        #expect(statements[1].text == "SELECT 3")
    }

    @Test func sqlSelectionUsesSelectionOrStatementAtCaret() {
        let sql = "SELECT 1;\nDELETE FROM users;\nSELECT 2"
        let deleteRange = (sql as NSString).range(of: "DELETE FROM users")
        let selection = SQLHighlighter.statementsToExecute(in: sql, selectedRange: deleteRange)
        let caret = SQLHighlighter.statementsToExecute(
            in: sql,
            selectedRange: NSRange(location: deleteRange.location + 3, length: 0)
        )

        #expect(selection.count == 1)
        #expect(selection[0].safety == .destructive)
        #expect(caret.count == 1)
        #expect(caret[0].text == "DELETE FROM users")
    }

    @Test func sqlSafetyFailsClosedAndDoesNotTrustTextInsideLiterals() {
        #expect(SQLHighlighter.safetyClassification(of: "SELECT * FROM t") == .readOnly)
        #expect(SQLHighlighter.safetyClassification(of: "SELECT * FROM t FOR UPDATE") == .mutation)
        #expect(SQLHighlighter.safetyClassification(of: "SET GLOBAL max_connections = 10") == .mutation)
        #expect(SQLHighlighter.safetyClassification(of: "DROP TABLE users") == .destructive)
        #expect(SQLHighlighter.safetyClassification(of: "nonsense command") == .unknown)
        #expect(SQLHighlighter.safetyClassification(of: "SELECT 'DROP TABLE users'") == .readOnly)
        #expect(SQLSafetyClassification.readOnly.requiresConfirmation == false)
        #expect(SQLSafetyClassification.sessionControl.requiresConfirmation == false)
        #expect(SQLSafetyClassification.mutation.requiresConfirmation)
        #expect(SQLSafetyClassification.destructive.requiresConfirmation)
        #expect(SQLSafetyClassification.unknown.requiresConfirmation)
    }

    @Test func sqlSafetyCannotHideWritesBehindCTEsCommentsOrLiterals() {
        #expect(SQLHighlighter.safetyClassification(
            of: "WITH visible AS (SELECT 1) UPDATE accounts SET admin = 1"
        ) == .mutation)
        #expect(SQLHighlighter.safetyClassification(
            of: "WITH removed AS (DELETE FROM sessions RETURNING id) SELECT * FROM removed"
        ) == .destructive)
        #expect(SQLHighlighter.safetyClassification(
            of: "WITH visible AS (SELECT 'UPDATE accounts') SELECT * FROM visible"
        ) == .readOnly)
        #expect(SQLHighlighter.safetyClassification(
            of: "/* DELETE FROM accounts */ SELECT 1"
        ) == .readOnly)
        #expect(SQLHighlighter.safetyClassification(
            of: "SELECT * FROM audit INTO OUTFILE '/tmp/export'"
        ) == .destructive)
    }

    @Test func managedSQLiteFilesRejectMissingOutsideDirectoryAndSymlinkInputs() throws {
        let fileManager = FileManager.default
        let outside = fileManager.temporaryDirectory
            .appendingPathComponent("glassdb-security-\(UUID().uuidString).sqlite")
        try Data().write(to: outside)
        defer { try? fileManager.removeItem(at: outside) }

        let externalConfiguration = DatabaseConnectionConfig(
            name: "Legacy",
            engine: .sqlite,
            host: outside.path,
            port: 0,
            username: ""
        )
        #expect(throws: (any Error).self) {
            _ = try SQLiteFileImporter.validatedURL(forPath: externalConfiguration.host)
        }
        #expect(throws: (any Error).self) {
            _ = try SQLiteFileImporter.validatedURL(forPath: outside.path + ".missing")
        }
        #expect(throws: (any Error).self) {
            _ = try SQLiteFileImporter.importFile(at: outside.deletingLastPathComponent())
        }

        let imported = try SQLiteFileImporter.importFile(at: outside)
        defer { try? fileManager.removeItem(at: imported) }
        #expect(try SQLiteFileImporter.validatedURL(forPath: imported.path) == imported)

        let managedDirectory = try SQLiteFileImporter.managedDirectory(create: true)
        let symlink = managedDirectory.appendingPathComponent("escape-\(UUID().uuidString).sqlite")
        try fileManager.createSymbolicLink(at: symlink, withDestinationURL: outside)
        defer { try? fileManager.removeItem(at: symlink) }
        #expect(throws: (any Error).self) {
            _ = try SQLiteFileImporter.validatedURL(forPath: symlink.path)
        }
    }

    @Test func failedSQLiteSnapshotImportRemovesPartialManagedFile() throws {
        let fileManager = FileManager.default
        let source = fileManager.temporaryDirectory
            .appendingPathComponent("glassdb-invalid-\(UUID().uuidString).sqlite")
        try Data("not a sqlite database".utf8).write(to: source)
        defer { try? fileManager.removeItem(at: source) }

        let destinationID = UUID()
        let managedDirectory = try SQLiteFileImporter.managedDirectory(create: true)
        let destination = managedDirectory
            .appendingPathComponent(destinationID.uuidString)
            .appendingPathExtension("sqlite")
        defer { try? fileManager.removeItem(at: destination) }

        #expect(throws: (any Error).self) {
            _ = try SQLiteFileImporter.importFile(
                at: source,
                destinationID: destinationID
            )
        }
        #expect(!fileManager.fileExists(atPath: destination.path))
    }

    @Test @MainActor func connectionPersistenceFailureKeepsSQLiteMetadataAndFilesUnchanged() throws {
        let fileManager = FileManager.default
        let managedDirectory = try SQLiteFileImporter.managedDirectory(create: true)
        let originalURL = managedDirectory
            .appendingPathComponent("persistence-original-\(UUID().uuidString)")
            .appendingPathExtension("sqlite")
        let replacementURL = managedDirectory
            .appendingPathComponent("persistence-replacement-\(UUID().uuidString)")
            .appendingPathExtension("sqlite")
        try Data("original".utf8).write(to: originalURL)
        try Data("replacement".utf8).write(to: replacementURL)
        defer {
            try? fileManager.removeItem(at: originalURL)
            try? fileManager.removeItem(at: replacementURL)
        }

        let connectionID = UUID()
        let original = DatabaseConnectionConfig(
            id: connectionID,
            name: "Original SQLite",
            engine: .sqlite,
            host: originalURL.path,
            port: 0,
            username: ""
        )
        let replacement = DatabaseConnectionConfig(
            id: connectionID,
            name: "Replacement SQLite",
            engine: .sqlite,
            host: replacementURL.path,
            port: 0,
            username: ""
        )
        let persistence = ConnectionPersistenceTestState()
        let originalData = try JSONEncoder().encode([original])
        persistence.data = originalData
        let manager = ConnectionManager(
            loadImmediately: true,
            persistenceStore: persistence.store
        )
        persistence.failWrites = true
        persistence.mutateBeforeFailure = true

        #expect(throws: IntegrityTestError.persistenceFailed) {
            try manager.update(replacement)
        }
        #expect(manager.connections == [original])
        #expect(persistence.data == originalData)
        #expect(fileManager.fileExists(atPath: originalURL.path))
        #expect(fileManager.fileExists(atPath: replacementURL.path))

        #expect(throws: IntegrityTestError.persistenceFailed) {
            try manager.delete(original)
        }
        #expect(manager.connections == [original])
        #expect(persistence.data == originalData)
        #expect(fileManager.fileExists(atPath: originalURL.path))
    }

    @Test @MainActor func connectionLifecycleRemovesSQLiteFileOnlyAfterLastPersistedReference() throws {
        let fileManager = FileManager.default
        let managedDirectory = try SQLiteFileImporter.managedDirectory(create: true)
        let sharedURL = managedDirectory
            .appendingPathComponent("lifecycle-shared-\(UUID().uuidString)")
            .appendingPathExtension("sqlite")
        let replacementURL = managedDirectory
            .appendingPathComponent("lifecycle-replacement-\(UUID().uuidString)")
            .appendingPathExtension("sqlite")
        try Data("shared".utf8).write(to: sharedURL)
        try Data("replacement".utf8).write(to: replacementURL)
        defer {
            try? fileManager.removeItem(at: sharedURL)
            try? fileManager.removeItem(at: replacementURL)
        }

        let first = DatabaseConnectionConfig(
            name: "First",
            engine: .sqlite,
            host: sharedURL.path,
            port: 0,
            username: ""
        )
        let second = DatabaseConnectionConfig(
            name: "Second",
            engine: .sqlite,
            host: sharedURL.path,
            port: 0,
            username: ""
        )
        let replacement = DatabaseConnectionConfig(
            id: first.id,
            name: "First Replacement",
            engine: .sqlite,
            host: replacementURL.path,
            port: 0,
            username: ""
        )
        let persistence = ConnectionPersistenceTestState()
        persistence.data = try JSONEncoder().encode([first, second])
        let manager = ConnectionManager(loadImmediately: true, persistenceStore: persistence.store)

        try manager.update(replacement)
        #expect(fileManager.fileExists(atPath: sharedURL.path))
        #expect(manager.connections == [replacement, second])

        try manager.delete(second)
        #expect(!fileManager.fileExists(atPath: sharedURL.path))
        #expect(fileManager.fileExists(atPath: replacementURL.path))
        #expect(manager.connections == [replacement])
        #expect(try JSONDecoder().decode([DatabaseConnectionConfig].self, from: #require(persistence.data))
            == [replacement])
    }

    @Test func sqlHistoryRedactionReplacesStringAndNumberLiterals() {
        let sql = "SELECT * FROM users WHERE email = 'person@example.com' AND pin = 1234"

        #expect(SQLHighlighter.redactingLiterals(in: sql)
            == "SELECT * FROM users WHERE email = '?' AND pin = ?")
    }

    @Test func sqlCompletionUsesLiveSchemaAndDoesNotCompleteInsideLiterals() {
        let sql = "SELECT us"
        let selection = NSRange(location: (sql as NSString).length, length: 0)
        let suggestions = SQLHighlighter.completions(
            in: sql,
            selectedRange: selection,
            schemaIdentifiers: ["users", "users.email", "events"]
        )

        #expect(suggestions.contains("users"))
        #expect(suggestions.contains("users.email"))
        #expect(suggestions.contains("events") == false)

        let applied = SQLHighlighter.applyingCompletion(
            "users",
            to: sql,
            selectedRange: selection
        )
        #expect(applied.sql == "SELECT users")
        #expect(applied.selection.location == (applied.sql as NSString).length)

        let literal = "SELECT 'us'"
        #expect(SQLHighlighter.completions(
            in: literal,
            selectedRange: NSRange(location: (literal as NSString).length - 1, length: 0),
            schemaIdentifiers: ["users"]
        ).isEmpty)
    }

    @Test func sqlFormatterPreservesLiteralAndCommentContents() {
        let sql = "select 'from;where' as value; -- keep Select text\nselect 2"
        let formatted = SQLHighlighter.formatted(sql)

        #expect(formatted.hasPrefix("SELECT 'from;where' AS value"))
        #expect(formatted.contains("-- keep Select text"))
        #expect(formatted.hasSuffix("SELECT 2"))
    }

    @Test func sqlDocumentExportsExactUTF8Contents() throws {
        let sql = "SELECT 'glass 🥽';\n"
        #expect(SQLTextDocument(text: sql).utf8Data == Data(sql.utf8))
    }

    @Test @MainActor func queryHistoryPersistsFiltersAndEnforcesRetention() throws {
        let suiteName = "app.glassdb.tests.history.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(2, forKey: UserDefaultsKeys.maxQueryHistoryItems)

        let connectionID = UUID()
        let config = DatabaseConnectionConfig(
            id: connectionID,
            name: "History",
            host: "db.example.com",
            username: "tester"
        )
        let session = DatabaseSession(connectionConfig: config)
        session.currentDatabase = "analytics"
        let writer = DatabaseSessionManager(loadImmediately: true, defaults: defaults)

        writer.recordHistory(
            sql: "SELECT 1",
            session: session,
            timestamp: Date(timeIntervalSince1970: 1),
            duration: 0.01,
            rowCount: 1,
            affectedRows: nil,
            error: nil
        )
        writer.recordHistory(
            sql: "UPDATE events SET seen = 1",
            session: session,
            timestamp: Date(timeIntervalSince1970: 2),
            duration: 0.02,
            rowCount: 0,
            affectedRows: 4,
            error: nil
        )
        writer.recordHistory(
            sql: "SELECT missing FROM events",
            session: session,
            timestamp: Date(timeIntervalSince1970: 3),
            duration: 0.03,
            rowCount: nil,
            affectedRows: nil,
            error: "Unknown column"
        )

        #expect(writer.persistentQueryHistory.count == 2)
        #expect(writer.queryHistory(connectionID: connectionID, database: "analytics").count == 2)
        #expect(writer.queryHistory(status: .succeeded).count == 1)
        #expect(writer.queryHistory(status: .failed).count == 1)
        #expect(writer.queryHistory(matching: "unknown").count == 1)

        let reader = DatabaseSessionManager(loadImmediately: true, defaults: defaults)
        #expect(reader.persistentQueryHistory.count == 2)
        #expect(reader.persistentQueryHistory.last?.affectedRows == nil)
        #expect(reader.persistentQueryHistory.first?.affectedRows == 4)

        let failedID = try #require(reader.queryHistory(status: .failed).first?.id)
        reader.deleteQueryHistory(id: failedID)
        #expect(reader.persistentQueryHistory.count == 1)
    }

    @Test @MainActor func queryHistoryHonorsLiteralRedactionPreference() throws {
        let suiteName = "app.glassdb.tests.history-redaction.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(true, forKey: UserDefaultsKeys.redactQueryHistoryLiterals)

        let session = DatabaseSession(connectionConfig: DatabaseConnectionConfig(name: "Redaction"))
        let manager = DatabaseSessionManager(loadImmediately: true, defaults: defaults)
        manager.recordHistory(
            sql: "SELECT * FROM users WHERE token = 'secret' AND id = 7",
            session: session,
            timestamp: Date(),
            duration: 0,
            rowCount: 0,
            affectedRows: nil,
            error: nil
        )

        #expect(manager.persistentQueryHistory.first?.sql
            == "SELECT * FROM users WHERE token = '?' AND id = ?")
    }

    @Test @MainActor func settingsDefaultsMatchWorkspacePolicy() {
        let settings = SettingsManager(loadImmediately: false)

        #expect(settings.maxQueryHistoryItems == 500)
        #expect(settings.resultRowLimit == 1_000)
        #expect(settings.editorFontSize == 14)
        #expect(settings.dataGridFontSize == 13)
        #expect(settings.showLineNumbers)
        #expect(settings.autoFormatJSONInRecordEditor)
        #expect(settings.redactQueryHistoryLiterals == false)
        #expect(settings.queryFailureNotificationPreference == .undecided)
        #expect(!settings.queryFailureNotificationsEnabled)
        #expect(settings.shouldOfferQueryFailureNotifications)
        #expect(settings.windowOpacity == 0.95)
        #expect(settings.blurBackground == 1.0)
        #expect(settings.showSidebarByDefault)
    }

    @Test @MainActor func JSONEditorFormattingPreferencePersists() throws {
        let suiteName = "app.glassdb.tests.json-editor-formatting.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let settings = SettingsManager(
            loadImmediately: false,
            defaults: defaults,
            sharedDefaults: nil
        )
        settings.autoFormatJSONInRecordEditor = false
        settings.saveSettings()

        let reloaded = SettingsManager(
            loadImmediately: true,
            defaults: defaults,
            sharedDefaults: nil
        )
        #expect(!reloaded.autoFormatJSONInRecordEditor)
    }

    @Test @MainActor func queryFailureNotificationOfferPersistsWithoutRequestingSystemPermission() throws {
        let suiteName = "app.glassdb.tests.query-notifications.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let settings = SettingsManager(
            loadImmediately: false,
            defaults: defaults,
            sharedDefaults: nil
        )
        settings.declineQueryFailureNotifications()

        #expect(settings.queryFailureNotificationPreference == .disabled)
        #expect(!settings.shouldOfferQueryFailureNotifications)
        #expect(defaults.string(forKey: UserDefaultsKeys.queryFailureNotificationPreference)
            == QueryFailureNotificationPreference.disabled.rawValue)
    }

    @Test func queryFailurePresentationRecognizesCommonDatabaseErrors() {
        let syntax = QueryFailurePresentation(
            message: "MySQL error: Invalid syntax near 'NO LIKE'"
        )
        #expect(syntax.title == "Invalid SQL Syntax")
        #expect(syntax.detail.contains("NO LIKE"))

        let authentication = QueryFailurePresentation(
            message: "Access denied for user 'root'@'localhost'"
        )
        #expect(authentication.title == "Authentication Failed")

        let unknown = QueryFailurePresentation(message: "Server closed the connection")
        #expect(unknown.title == "Query Failed")
    }

    @Test func tableSchemaSQLQuotesIdentifiersAndRejectsExecutableTypeFragments() throws {
        let add = try TableSchemaSQL.addColumn(
            database: "app`data",
            table: "users",
            name: "display`name",
            type: "VARCHAR(255)",
            nullable: false,
            quoteCharacter: "`"
        )
        #expect(add == "ALTER TABLE `app``data`.`users` ADD COLUMN `display``name` VARCHAR(255) NOT NULL")

        let enumColumn = try TableSchemaSQL.addColumn(
            database: "app",
            table: "jobs",
            name: "state",
            type: "ENUM('draft', 'ready')",
            nullable: false,
            quoteCharacter: "`"
        )
        #expect(enumColumn == "ALTER TABLE `app`.`jobs` ADD COLUMN `state` ENUM('draft', 'ready') NOT NULL")

        #expect(throws: TableSchemaEditError.self) {
            _ = try TableSchemaSQL.addColumn(
                database: "app",
                table: "users",
                name: "nickname",
                type: "TEXT; DROP TABLE users",
                nullable: true,
                quoteCharacter: "`"
            )
        }
        #expect(throws: TableSchemaEditError.self) {
            _ = try TableSchemaSQL.addColumn(
                database: "app",
                table: "users",
                name: "nickname",
                type: "VARCHAR(80) NOT NULL",
                nullable: true,
                quoteCharacter: "`"
            )
        }
        #expect(throws: TableSchemaEditError.self) {
            _ = try TableSchemaSQL.addColumn(
                database: "app",
                table: "users",
                name: "nickname",
                type: "INT, ADD COLUMN injected INT",
                nullable: true,
                quoteCharacter: "`"
            )
        }
    }

    @Test func tableSchemaSQLUsesDialectCorrectIndexAndForeignKeyStatements() throws {
        let mysqlDrop = try TableSchemaSQL.dropIndex(
            database: "app",
            table: "users",
            name: "users_email_idx",
            dialect: .mysql,
            quoteCharacter: "`"
        )
        #expect(mysqlDrop == "DROP INDEX `users_email_idx` ON `app`.`users`")

        let postgresDrop = try TableSchemaSQL.dropIndex(
            database: "public",
            table: "users",
            name: "users_email_idx",
            dialect: .postgresql,
            quoteCharacter: "\""
        )
        #expect(postgresDrop == "DROP INDEX \"public\".\"users_email_idx\"")

        #expect(throws: TableSchemaEditError.self) {
            _ = try TableSchemaSQL.addForeignKey(
                database: "main",
                table: "users",
                name: "fk_users_team",
                column: "team_id",
                referencedTable: "teams",
                referencedColumn: "id",
                dialect: .sqlite,
                quoteCharacter: "\""
            )
        }
    }

    @Test func tableSchemaSQLBuildsReviewedMySQLColumnChangeAndPreservesDefault() throws {
        let original = ColumnInfo(
            name: "amount",
            type: "int",
            isNullable: true,
            defaultValue: "5"
        )
        let statements = try TableSchemaSQL.alterColumn(
            database: "app",
            table: "orders",
            original: original,
            name: "total",
            type: "BIGINT",
            nullable: false,
            unsigned: true,
            defaultMode: .keep,
            defaultLiteral: "",
            dialect: .mysql,
            quoteCharacter: "`"
        )

        #expect(statements == [
            "ALTER TABLE `app`.`orders` CHANGE COLUMN `amount` `total` BIGINT UNSIGNED NOT NULL DEFAULT 5"
        ])
    }

    @Test func tableSchemaSQLBuildsTransactionalPostgreSQLColumnStepsAndEscapesLiteral() throws {
        let original = ColumnInfo(name: "name", type: "text", isNullable: true)
        let statements = try TableSchemaSQL.alterColumn(
            database: "public",
            table: "people",
            original: original,
            name: "full_name",
            type: "VARCHAR(120)",
            nullable: false,
            unsigned: false,
            defaultMode: .literal,
            defaultLiteral: "O'Brien",
            dialect: .postgresql,
            quoteCharacter: "\""
        )

        #expect(statements == [
            "ALTER TABLE \"public\".\"people\" RENAME COLUMN \"name\" TO \"full_name\"",
            "ALTER TABLE \"public\".\"people\" ALTER COLUMN \"full_name\" TYPE VARCHAR(120)",
            "ALTER TABLE \"public\".\"people\" ALTER COLUMN \"full_name\" SET NOT NULL",
            "ALTER TABLE \"public\".\"people\" ALTER COLUMN \"full_name\" SET DEFAULT 'O''Brien'"
        ])
    }

    @Test func tableSchemaSQLLimitsSQLiteColumnEditingToSafeRename() throws {
        let original = ColumnInfo(name: "label", type: "text", isNullable: true)
        let rename = try TableSchemaSQL.alterColumn(
            database: "main",
            table: "items",
            original: original,
            name: "display_label",
            type: "text",
            nullable: true,
            unsigned: false,
            defaultMode: .keep,
            defaultLiteral: "",
            dialect: .sqlite,
            quoteCharacter: "\""
        )
        #expect(rename == [
            "ALTER TABLE \"main\".\"items\" RENAME COLUMN \"label\" TO \"display_label\""
        ])

        #expect(throws: TableSchemaEditError.self) {
            _ = try TableSchemaSQL.alterColumn(
                database: "main",
                table: "items",
                original: original,
                name: "label",
                type: "VARCHAR(80)",
                nullable: true,
                unsigned: false,
                defaultMode: .keep,
                defaultLiteral: "",
                dialect: .sqlite,
                quoteCharacter: "\""
            )
        }
    }

    @Test func tableSchemaSQLProtectsGeneratedAndPrimaryKeyAttributes() {
        let generated = ColumnInfo(name: "search_key", type: "text", isNullable: true, isGenerated: true)
        #expect(throws: TableSchemaEditError.self) {
            _ = try TableSchemaSQL.alterColumn(
                database: "app",
                table: "items",
                original: generated,
                name: "search_key",
                type: "VARCHAR(80)",
                nullable: true,
                unsigned: false,
                defaultMode: .keep,
                defaultLiteral: "",
                dialect: .mysql,
                quoteCharacter: "`"
            )
        }

        let primary = ColumnInfo(name: "id", type: "bigint", isNullable: false, isPrimaryKey: true)
        #expect(throws: TableSchemaEditError.self) {
            _ = try TableSchemaSQL.alterColumn(
                database: "app",
                table: "items",
                original: primary,
                name: "id",
                type: "bigint",
                nullable: true,
                unsigned: false,
                defaultMode: .keep,
                defaultLiteral: "",
                dialect: .mysql,
                quoteCharacter: "`"
            )
        }
    }

    @Test func tableToolsKeepDataAsTheirPrimaryDestination() {
        #expect(TableTab.allCases.first == .data)
        #expect(TableTab.data.helpText == "Browse and edit table data")
    }

    @Test @MainActor func workspaceAppearanceMigratesBooleanBlurAndPreservesEndpoints() throws {
        let suiteName = "app.glassdb.tests.appearance.\(UUID().uuidString)"
        let sharedSuiteName = "app.glassdb.tests.appearance-shared.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        let sharedDefaults = try #require(UserDefaults(suiteName: sharedSuiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
            sharedDefaults.removePersistentDomain(forName: sharedSuiteName)
        }
        defaults.set(false, forKey: UserDefaultsKeys.blurBackground)
        defaults.set(0.0, forKey: UserDefaultsKeys.windowOpacity)

        let migrated = SettingsManager(
            loadImmediately: true,
            defaults: defaults,
            sharedDefaults: sharedDefaults
        )
        #expect(migrated.blurBackground == 0.0)
        #expect(migrated.windowOpacity == 0.0)

        migrated.blurBackground = 1.0
        migrated.windowOpacity = 1.0
        migrated.saveSettings()
        let reloaded = SettingsManager(
            loadImmediately: true,
            defaults: defaults,
            sharedDefaults: sharedDefaults
        )
        #expect(reloaded.blurBackground == 1.0)
        #expect(reloaded.windowOpacity == 1.0)

        reloaded.blurBackground = 4.0
        reloaded.windowOpacity = -2.0
        reloaded.saveSettings()
        #expect(reloaded.blurBackground == 1.0)
        #expect(reloaded.windowOpacity == 0.0)

        defaults.set(7.0, forKey: UserDefaultsKeys.windowOpacity)
        defaults.set(-4.0, forKey: UserDefaultsKeys.blurBackground)
        let clampedOnLoad = SettingsManager(
            loadImmediately: true,
            defaults: defaults,
            sharedDefaults: sharedDefaults
        )
        #expect(clampedOnLoad.windowOpacity == 1.0)
        #expect(clampedOnLoad.blurBackground == 0.0)
    }

    @Test @MainActor func sshMetadataMigrationRetainsAndUpdatesRollbackIndex() throws {
        let localSuite = "app.glassdb.tests.ssh-metadata.local.\(UUID().uuidString)"
        let sharedSuite = "app.glassdb.tests.ssh-metadata.shared.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: localSuite))
        let sharedDefaults = try #require(UserDefaults(suiteName: sharedSuite))
        defer {
            defaults.removePersistentDomain(forName: localSuite)
            sharedDefaults.removePersistentDomain(forName: sharedSuite)
        }
        let key = StoredSSHKey(
            name: "Rollback Key",
            algorithm: "Ed25519",
            storageKind: .imported,
            algorithmKind: .ed25519,
            migrationState: .notNeeded
        )
        defaults.set(try JSONEncoder().encode([key]), forKey: UserDefaultsKeys.sshKeys)

        let settings = SettingsManager(
            loadImmediately: true,
            defaults: defaults,
            sharedDefaults: sharedDefaults
        )
        try settings.renameSSHKey(key, name: "Renamed for rollback")

        let retained = try #require(defaults.data(forKey: UserDefaultsKeys.sshKeys))
        let shared = try #require(sharedDefaults.data(forKey: "sshKeys"))
        #expect(try JSONDecoder().decode([StoredSSHKey].self, from: retained).first?.name
            == "Renamed for rollback")
        #expect(try JSONDecoder().decode([StoredSSHKey].self, from: shared).first?.name
            == "Renamed for rollback")
    }

    @Test @MainActor func sshMetadataFailsClosedWhenAppGroupIsUnavailable() throws {
        let localSuite = "app.glassdb.tests.ssh-metadata-no-group.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: localSuite))
        defer { defaults.removePersistentDomain(forName: localSuite) }
        let legacyKey = StoredSSHKey(
            name: "Legacy",
            algorithm: "Ed25519",
            algorithmKind: .ed25519
        )
        defaults.set(try JSONEncoder().encode([legacyKey]), forKey: UserDefaultsKeys.sshKeys)

        let settings = SettingsManager(
            loadImmediately: true,
            defaults: defaults,
            sharedDefaults: nil
        )

        #expect(settings.sshKeys.isEmpty)
        #expect(settings.sshKeyCatalogError == .appGroupUnavailable)
        #expect(throws: SSHMetadataPersistenceError.appGroupUnavailable) {
            try settings.renameSSHKey(legacyKey, name: "Must not use standard defaults")
        }
    }

    @Test @MainActor func sshMetadataRejectsOversizedSharedCatalog() throws {
        let localSuite = "app.glassdb.tests.ssh-metadata-oversize-local.\(UUID().uuidString)"
        let sharedSuite = "app.glassdb.tests.ssh-metadata-oversize-shared.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: localSuite))
        let sharedDefaults = try #require(UserDefaults(suiteName: sharedSuite))
        defer {
            defaults.removePersistentDomain(forName: localSuite)
            sharedDefaults.removePersistentDomain(forName: sharedSuite)
        }
        sharedDefaults.set(
            Data(repeating: 0, count: SettingsManager.maximumSSHKeyCatalogBytes + 1),
            forKey: "sshKeys"
        )

        let settings = SettingsManager(
            loadImmediately: true,
            defaults: defaults,
            sharedDefaults: sharedDefaults
        )

        #expect(settings.sshKeys.isEmpty)
        #expect(settings.sshKeyCatalogError == .catalogTooLarge)
    }

    @Test @MainActor func sshMetadataReloadsAndMergesBeforeRename() throws {
        let localSuite = "app.glassdb.tests.ssh-metadata-merge-local.\(UUID().uuidString)"
        let sharedSuite = "app.glassdb.tests.ssh-metadata-merge-shared.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: localSuite))
        let sharedDefaults = try #require(UserDefaults(suiteName: sharedSuite))
        defer {
            defaults.removePersistentDomain(forName: localSuite)
            sharedDefaults.removePersistentDomain(forName: sharedSuite)
        }
        let original = StoredSSHKey(
            name: "Original",
            algorithm: "Ed25519",
            algorithmKind: .ed25519
        )
        let externallyAdded = StoredSSHKey(
            name: "Added by glas.sh",
            algorithm: "RSA",
            algorithmKind: .rsa
        )
        let originalData = try JSONEncoder().encode([original])
        defaults.set(originalData, forKey: UserDefaultsKeys.sshKeys)
        sharedDefaults.set(originalData, forKey: "sshKeys")
        let settings = SettingsManager(
            loadImmediately: true,
            defaults: defaults,
            sharedDefaults: sharedDefaults
        )

        var externallyRenamed = original
        externallyRenamed.name = "Renamed by glas.sh"
        sharedDefaults.set(
            try JSONEncoder().encode([externallyRenamed, externallyAdded]),
            forKey: "sshKeys"
        )
        try settings.renameSSHKey(original, name: "Final name")

        let sharedData = try #require(sharedDefaults.data(forKey: "sshKeys"))
        let legacyData = try #require(defaults.data(forKey: UserDefaultsKeys.sshKeys))
        let sharedKeys = try JSONDecoder().decode([StoredSSHKey].self, from: sharedData)
        let legacyKeys = try JSONDecoder().decode([StoredSSHKey].self, from: legacyData)
        #expect(sharedKeys == legacyKeys)
        #expect(sharedKeys.count == 2)
        #expect(sharedKeys.first(where: { $0.id == original.id })?.name == "Final name")
        #expect(sharedKeys.contains(where: { $0.id == externallyAdded.id }))
    }

    @Test @MainActor func sshMetadataRenameRestoresBothCatalogsAfterReadbackFailure() throws {
        let localSuite = "app.glassdb.tests.ssh-metadata-rename-local.\(UUID().uuidString)"
        let sharedSuite = "app.glassdb.tests.ssh-metadata-rename-shared.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: localSuite))
        let sharedDefaults = try #require(UserDefaults(suiteName: sharedSuite))
        defer {
            defaults.removePersistentDomain(forName: localSuite)
            sharedDefaults.removePersistentDomain(forName: sharedSuite)
        }
        let key = StoredSSHKey(
            name: "Original",
            algorithm: "Ed25519",
            algorithmKind: .ed25519
        )
        let originalData = try JSONEncoder().encode([key])
        defaults.set(originalData, forKey: UserDefaultsKeys.sshKeys)
        sharedDefaults.set(originalData, forKey: "sshKeys")
        let settings = SettingsManager(
            loadImmediately: true,
            defaults: defaults,
            sharedDefaults: sharedDefaults,
            legacyCatalogWriter: { _ in }
        )

        #expect(throws: SSHMetadataPersistenceError.readbackMismatch) {
            try settings.renameSSHKey(key, name: "Uncommitted")
        }
        #expect(settings.sshKeys == [key])
        #expect(settings.sshKeyCatalogError == .readbackMismatch)
        #expect(sharedDefaults.data(forKey: "sshKeys") == originalData)
        #expect(defaults.data(forKey: UserDefaultsKeys.sshKeys) == originalData)
    }

    @Test @MainActor func sshMetadataAddRemovesSecretWhenCatalogWriteFails() throws {
        let localSuite = "app.glassdb.tests.ssh-metadata-add-local.\(UUID().uuidString)"
        let sharedSuite = "app.glassdb.tests.ssh-metadata-add-shared.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: localSuite))
        let sharedDefaults = try #require(UserDefaults(suiteName: sharedSuite))
        defer {
            defaults.removePersistentDomain(forName: localSuite)
            sharedDefaults.removePersistentDomain(forName: sharedSuite)
        }
        let emptyData = try JSONEncoder().encode([StoredSSHKey]())
        defaults.set(emptyData, forKey: UserDefaultsKeys.sshKeys)
        sharedDefaults.set(emptyData, forKey: "sshKeys")
        let lifecycle = SSHKeyLifecycleTestState()
        let settings = SettingsManager(
            loadImmediately: true,
            defaults: defaults,
            sharedDefaults: sharedDefaults,
            sshKeyLifecycleStore: lifecycle.store,
            legacyCatalogWriter: { _ in }
        )

        #expect(throws: SSHMetadataPersistenceError.readbackMismatch) {
            try settings.addSSHKey(
                name: "Must roll back",
                privateKey: "private-key",
                passphrase: "passphrase",
                algorithmKind: .ed25519
            )
        }
        #expect(lifecycle.materials.isEmpty)
        #expect(settings.sshKeys.isEmpty)
        #expect(sharedDefaults.data(forKey: "sshKeys") == emptyData)
        #expect(defaults.data(forKey: UserDefaultsKeys.sshKeys) == emptyData)
    }

    @Test @MainActor func sshKeyMutationsRejectInvalidUserInputBeforeStorage() {
        let settings = SettingsManager(loadImmediately: false, sharedDefaults: nil)
        let key = StoredSSHKey(
            name: "Existing",
            algorithm: "Ed25519",
            algorithmKind: .ed25519
        )

        #expect(throws: SSHKeyInputError.emptyName) {
            try settings.addSSHKey(
                name: "   ",
                privateKey: "private-key",
                passphrase: nil,
                algorithmKind: .ed25519
            )
        }
        #expect(throws: SSHKeyInputError.emptyPrivateKey) {
            try settings.addSSHKey(
                name: "Valid name",
                privateKey: "\n\t",
                passphrase: nil,
                algorithmKind: .ed25519
            )
        }
        #expect(throws: SSHKeyInputError.nameTooLong) {
            try settings.addSSHKey(
                name: String(repeating: "n", count: SettingsManager.maximumSSHKeyNameBytes + 1),
                privateKey: "private-key",
                passphrase: nil,
                algorithmKind: .ed25519
            )
        }
        #expect(throws: SSHKeyInputError.passphraseTooLong) {
            try settings.addSSHKey(
                name: "Valid name",
                privateKey: "private-key",
                passphrase: String(
                    repeating: "p",
                    count: SettingsManager.maximumSSHPassphraseBytes + 1
                ),
                algorithmKind: .ed25519
            )
        }
        #expect(throws: SSHKeyInputError.emptyName) {
            try settings.renameSSHKey(key, name: "   ")
        }
    }

    @Test @MainActor func sshMetadataDeleteRestoresSecretAndCatalogAfterPartialFailure() throws {
        let localSuite = "app.glassdb.tests.ssh-metadata-delete-local.\(UUID().uuidString)"
        let sharedSuite = "app.glassdb.tests.ssh-metadata-delete-shared.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: localSuite))
        let sharedDefaults = try #require(UserDefaults(suiteName: sharedSuite))
        defer {
            defaults.removePersistentDomain(forName: localSuite)
            sharedDefaults.removePersistentDomain(forName: sharedSuite)
        }
        let key = StoredSSHKey(
            name: "Keep me",
            algorithm: "Ed25519",
            algorithmKind: .ed25519
        )
        let originalData = try JSONEncoder().encode([key])
        defaults.set(originalData, forKey: UserDefaultsKeys.sshKeys)
        sharedDefaults.set(originalData, forKey: "sshKeys")
        let lifecycle = SSHKeyLifecycleTestState()
        let material = SSHKeyMaterial(
            privateKey: SecureBytes(Data("private-key".utf8)),
            passphrase: SecureBytes(Data("passphrase".utf8))
        )
        lifecycle.materials[key.id] = material
        lifecycle.failNextDeleteAfterRemoval = true
        let settings = SettingsManager(
            loadImmediately: true,
            defaults: defaults,
            sharedDefaults: sharedDefaults,
            sshKeyLifecycleStore: lifecycle.store
        )

        #expect(throws: SSHMetadataTestError.deletionFailed) {
            try settings.deleteSSHKey(key)
        }
        let restored = try #require(lifecycle.materials[key.id])
        #expect(restored.privateKey.toData() == material.privateKey.toData())
        #expect(restored.passphrase?.toData() == material.passphrase?.toData())
        #expect(settings.sshKeys == [key])
        #expect(sharedDefaults.data(forKey: "sshKeys") == originalData)
        #expect(defaults.data(forKey: UserDefaultsKeys.sshKeys) == originalData)
    }

    @Test func credentialAccountsAreStableAndUUIDScoped() {
        let firstID = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
        let secondID = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
        let first = DatabaseConnectionConfig(
            id: firstID,
            name: "First",
            host: "same.example.com",
            username: "same"
        )
        let second = DatabaseConnectionConfig(
            id: secondID,
            name: "Second",
            host: "same.example.com",
            username: "same"
        )

        #expect(KeychainManager.databaseAccount(for: first.id)
            == "database:aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee")
        #expect(KeychainManager.sshAccount(for: first.id)
            == "ssh:aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee")
        #expect(KeychainManager.databaseAccount(for: first.id)
            != KeychainManager.databaseAccount(for: second.id))
        #expect(KeychainManager.legacyDatabaseAccount(for: first)
            == KeychainManager.legacyDatabaseAccount(for: second))
    }

    @Test func sharedCredentialIdentityUsesTheGlasSecretStoreContract() {
        let profileID = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!

        #expect(KeychainManager.databaseAccount(for: profileID)
            == GlassFamilyCredentialAccount.databasePassword(profileID: profileID))
        #expect(KeychainManager.sshAccount(for: profileID)
            == GlassFamilyCredentialAccount.sshPassword(profileID: profileID))
    }

    @Test func neutralEndpointContractRoundTripsWithoutCredentialMaterial() throws {
        let endpointID = EndpointID(
            rawValue: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
        )
        let credentialID = CredentialID(
            rawValue: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
        )
        let writerID = WriterID(
            rawValue: UUID(uuidString: "99999999-8888-7777-6666-555555555555")!
        )
        let timestamp = Date(timeIntervalSince1970: 1_700_000_000)
        let profile = try EndpointProfile(
            id: endpointID,
            displayName: "Shared bastion",
            host: "bastion.example.com",
            username: "operator",
            credentialID: credentialID,
            appVisibility: .glassFamily,
            createdAt: timestamp,
            updatedAt: timestamp,
            lastWriterID: writerID
        )

        let payload = try EndpointProfileCodec.encode(profile)
        let decoded = try EndpointProfileCodec.decode(payload)
        let serialized = String(decoding: payload, as: UTF8.self)

        #expect(decoded.id == endpointID)
        #expect(decoded.credentialID == credentialID)
        #expect(!serialized.contains("password"))
        #expect(!serialized.contains("privateKey"))
        #expect(!serialized.contains("hostFingerprint"))
    }

    @Test func sharedSSHCredentialPublishesTheGlasCompatibilityRecordAtomically() throws {
        let connection = DatabaseConnectionConfig(
            id: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!,
            name: "Shared bastion",
            host: "db.example.com",
            username: "database-user",
            useSSHTunnel: true,
            sshHost: "bastion.example.com",
            sshPort: 2222,
            sshUsername: "operator",
            sshAuthMethod: .password,
            databaseCredentialPolicy: .sharedWithGlas,
            sshCredentialPolicy: .sharedWithGlas
        )
        let mutation = CredentialMutationTestState()
        let sharedDescriptor = KeychainManager.descriptor(
            for: .sharedWithGlas,
            kind: .sshPassword
        )
        let compatibilityAccount = try #require(
            KeychainManager.sharedSSHCompatibilityAccount(for: connection)
        )

        _ = try KeychainManager.saveCredentials(
            databasePassword: "database-secret",
            sshPassword: "ssh-secret",
            for: connection,
            replacing: nil,
            store: mutation.store
        )

        #expect(compatibilityAccount == "ssh:operator@bastion.example.com:2222")
        #expect(sharedDescriptor.service == "sh.glas.sshpasswords")
        #expect(mutation.values[mutation.key(
            account: KeychainManager.sshAccount(for: connection.id),
            descriptor: sharedDescriptor
        )] == "ssh-secret")
        #expect(mutation.values[mutation.key(
            account: compatibilityAccount,
            descriptor: sharedDescriptor
        )] == "ssh-secret")
    }

    @Test func sharedSSHCompatibilityWriteFailureRestoresEveryCredentialRecord() throws {
        let connection = DatabaseConnectionConfig(
            name: "Atomic shared bastion",
            host: "db.example.com",
            useSSHTunnel: true,
            sshHost: "bastion.example.com",
            sshUsername: "operator",
            sshAuthMethod: .password,
            databaseCredentialPolicy: .sharedWithGlas,
            sshCredentialPolicy: .sharedWithGlas
        )
        let mutation = CredentialMutationTestState()
        let databaseDescriptor = KeychainManager.descriptor(
            for: .sharedWithGlas,
            kind: .databasePassword
        )
        let sshDescriptor = KeychainManager.descriptor(
            for: .sharedWithGlas,
            kind: .sshPassword
        )
        let databaseKey = mutation.key(
            account: KeychainManager.databaseAccount(for: connection.id),
            descriptor: databaseDescriptor
        )
        let sshKey = mutation.key(
            account: KeychainManager.sshAccount(for: connection.id),
            descriptor: sshDescriptor
        )
        let compatibilityAccount = try #require(
            KeychainManager.sharedSSHCompatibilityAccount(for: connection)
        )
        let compatibilityKey = mutation.key(
            account: compatibilityAccount,
            descriptor: sshDescriptor
        )
        mutation.values[databaseKey] = "old-database"
        mutation.values[sshKey] = "old-ssh"
        mutation.values[compatibilityKey] = "old-shared-ssh"
        mutation.failNextSaveAccount = compatibilityAccount

        #expect(throws: IntegrityTestError.credentialSaveFailed) {
            _ = try KeychainManager.saveCredentials(
                databasePassword: "new-database",
                sshPassword: "new-ssh",
                for: connection,
                replacing: connection,
                store: mutation.store
            )
        }
        #expect(mutation.values[databaseKey] == "old-database")
        #expect(mutation.values[sshKey] == "old-ssh")
        #expect(mutation.values[compatibilityKey] == "old-shared-ssh")
    }

    @Test func credentialMigrationIdentifiersAreStableAndPure() {
        let connection = DatabaseConnectionConfig(
            name: "Legacy",
            host: "db.example.com",
            port: 3307,
            username: "database-user",
            useSSHTunnel: true,
            sshHost: "bastion.example.com",
            sshPort: 2222,
            sshUsername: "ssh-user"
        )

        #expect(KeychainManager.credentialMigrationVersionKey
            == "app.glassdb.connectionCredentialMigrationVersion")
        #expect(KeychainManager.currentCredentialMigrationVersion == 2)
        #expect(KeychainManager.legacyDatabaseAccount(for: connection)
            == "database-user@db.example.com:3307")
        #expect(KeychainManager.legacySSHAccount(for: connection)
            == "ssh:ssh-user@bastion.example.com:2222")
    }

    @Test func sharedAccessGroupRejectsBareOrUnexpandedValues() {
        #expect(KeychainManager.validatedSharedAccessGroup(nil) == nil)
        #expect(KeychainManager.validatedSharedAccessGroup("") == nil)
        #expect(KeychainManager.validatedSharedAccessGroup("$(AppIdentifierPrefix)sh.glas.shared") == nil)
        #expect(KeychainManager.validatedSharedAccessGroup("sh.glas.shared") == nil)
        #expect(KeychainManager.validatedSharedAccessGroup("SHORT.sh.glas.shared") == nil)
        #expect(KeychainManager.validatedSharedAccessGroup("7JQGQ7CRH8.sh.glas.shared")
            == "7JQGQ7CRH8.sh.glas.shared")
    }

    @Test func credentialSaveAndDeleteRestoreBothRecordsAfterPartialFailure() throws {
        let connectionID = UUID()
        let previous = DatabaseConnectionConfig(
            id: connectionID,
            name: "Atomic credentials",
            host: "db.example.com",
            username: "database-user",
            useSSHTunnel: true,
            sshHost: "bastion.example.com",
            sshUsername: "ssh-user",
            sshAuthMethod: .password,
            databaseCredentialPolicy: .glassdbOnly,
            sshCredentialPolicy: .glassdbOnly
        )
        let updated = previous
        let databaseAccount = KeychainManager.databaseAccount(for: connectionID)
        let sshAccount = KeychainManager.sshAccount(for: connectionID)
        let databaseDescriptor = KeychainManager.descriptor(
            for: .glassdbOnly,
            kind: .databasePassword
        )
        let sshDescriptor = KeychainManager.descriptor(
            for: .glassdbOnly,
            kind: .sshPassword
        )
        let mutation = CredentialMutationTestState()
        let databaseKey = mutation.key(account: databaseAccount, descriptor: databaseDescriptor)
        let sshKey = mutation.key(account: sshAccount, descriptor: sshDescriptor)
        mutation.values[databaseKey] = "old database password"
        mutation.values[sshKey] = "old SSH password"

        mutation.failNextSaveAccount = sshAccount
        #expect(throws: IntegrityTestError.credentialSaveFailed) {
            _ = try KeychainManager.saveCredentials(
                databasePassword: "new database password",
                sshPassword: "new SSH password",
                for: updated,
                replacing: previous,
                store: mutation.store
            )
        }
        #expect(mutation.values[databaseKey] == "old database password")
        #expect(mutation.values[sshKey] == "old SSH password")

        let successfulSave = try KeychainManager.saveCredentials(
            databasePassword: "new database password",
            sshPassword: "new SSH password",
            for: updated,
            replacing: previous,
            store: mutation.store
        )
        #expect(mutation.values[databaseKey] == "new database password")
        #expect(mutation.values[sshKey] == "new SSH password")
        try KeychainManager.restoreCredentials(successfulSave.rollbackReceipt, store: mutation.store)
        #expect(mutation.values[databaseKey] == "old database password")
        #expect(mutation.values[sshKey] == "old SSH password")

        mutation.failNextDeleteAccount = sshAccount
        #expect(throws: IntegrityTestError.credentialDeleteFailed) {
            _ = try KeychainManager.deleteCredentials(for: previous, store: mutation.store)
        }
        #expect(mutation.values[databaseKey] == "old database password")
        #expect(mutation.values[sshKey] == "old SSH password")

        let receipt = try KeychainManager.deleteCredentials(for: previous, store: mutation.store)
        #expect(mutation.values[databaseKey] == nil)
        #expect(mutation.values[sshKey] == nil)
        try KeychainManager.restoreCredentials(receipt, store: mutation.store)
        #expect(mutation.values[databaseKey] == "old database password")
        #expect(mutation.values[sshKey] == "old SSH password")
    }

    @Test func credentialMigrationDestinationQueryFailureFailsClosed() {
        var legacyReadCount = 0
        var destinationWriteCount = 0
        let store = KeychainManager.CredentialMigrationStore(
            retrieveData: { _, _, _ in
                throw GlasSecretStore.SecretStoreError.queryFailed(status: -34_018)
            },
            retrievePassword: { _, _, _ in
                legacyReadCount += 1
                throw GlasSecretStore.SecretStoreError.notFound
            },
            savePassword: { _, _, _, _ in
                destinationWriteCount += 1
            }
        )

        do {
            _ = try KeychainManager.migrateLegacyCredentialIfPresent(
                destinationAccount: "database:destination",
                legacyAccount: "database-user@db.example.com:3306",
                primaryService: KeychainManager.sharedConfig.passwordsService,
                legacySuffix: "passwords",
                store: store
            )
            Issue.record("A destination query failure must abort migration.")
        } catch GlasSecretStore.SecretStoreError.queryFailed(let status) {
            #expect(status == -34_018)
        } catch {
            Issue.record("Unexpected migration error: \(error)")
        }

        #expect(legacyReadCount == 0)
        #expect(destinationWriteCount == 0)
    }

    @Test func credentialMigrationLegacyServiceQueryFailureFailsClosed() {
        let primaryService = KeychainManager.sharedConfig.passwordsService
        let legacyService = "app.glassdb.passwords"
        var queriedServices: [String] = []
        var destinationWriteCount = 0
        let store = KeychainManager.CredentialMigrationStore(
            retrieveData: { _, _, _ in
                throw GlasSecretStore.SecretStoreError.notFound
            },
            retrievePassword: { _, service, _ in
                queriedServices.append(service)
                if service == primaryService {
                    throw GlasSecretStore.SecretStoreError.notFound
                }
                if service == legacyService {
                    throw GlasSecretStore.SecretStoreError.queryFailed(status: -25_308)
                }
                Issue.record("Migration queried an unexpected legacy service: \(service)")
                throw GlasSecretStore.SecretStoreError.notFound
            },
            savePassword: { _, _, _, _ in
                destinationWriteCount += 1
            }
        )

        do {
            _ = try KeychainManager.migrateLegacyCredentialIfPresent(
                destinationAccount: "database:destination",
                legacyAccount: "database-user@db.example.com:3306",
                primaryService: primaryService,
                legacySuffix: "passwords",
                store: store
            )
            Issue.record("A legacy-service query failure must abort migration.")
        } catch GlasSecretStore.SecretStoreError.queryFailed(let status) {
            #expect(status == -25_308)
        } catch {
            Issue.record("Unexpected migration error: \(error)")
        }

        #expect(queriedServices == [primaryService, legacyService])
        #expect(destinationWriteCount == 0)
    }

    @Test func legacyConnectionsDecodeWithSharedCredentialPolicies() throws {
        let original = DatabaseConnectionConfig(
            name: "Legacy",
            host: "legacy.example.com",
            useSSHTunnel: true,
            sshHost: "bastion.example.com",
            sshUsername: "ssh-user",
            sshAuthMethod: .password
        )
        let encoded = try JSONEncoder().encode(original)
        var object = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        object.removeValue(forKey: "databaseCredentialPolicy")
        object.removeValue(forKey: "sshCredentialPolicy")

        let legacyData = try JSONSerialization.data(withJSONObject: object)
        let decoded = try JSONDecoder().decode(DatabaseConnectionConfig.self, from: legacyData)

        #expect(decoded.databaseCredentialPolicy == .sharedWithGlas)
        #expect(decoded.sshCredentialPolicy == .sharedWithGlas)
    }

    @Test func credentialPoliciesRoundTripAndExposeExactlyThreeModes() throws {
        #expect(CredentialStoragePolicy.allCases == [
            .sharedWithGlas,
            .glassdbOnly,
            .requireAuthentication
        ])
        var config = DatabaseConnectionConfig(name: "Policy")
        #expect(config.databaseCredentialPolicy == .glassdbOnly)
        #expect(config.sshCredentialPolicy == .glassdbOnly)
        config.databaseCredentialPolicy = .requireAuthentication
        config.sshCredentialPolicy = .sharedWithGlas

        let decoded = try JSONDecoder().decode(
            DatabaseConnectionConfig.self,
            from: JSONEncoder().encode(config)
        )
        #expect(decoded.databaseCredentialPolicy == .requireAuthentication)
        #expect(decoded.sshCredentialPolicy == .sharedWithGlas)
    }

    @Test func credentialPolicyDescriptorsUseIsolatedServicesAndExplicitPrompts() {
        let sharedDB = KeychainManager.descriptor(for: .sharedWithGlas, kind: .databasePassword)
        let privateDB = KeychainManager.descriptor(for: .glassdbOnly, kind: .databasePassword)
        let protectedDB = KeychainManager.descriptor(for: .requireAuthentication, kind: .databasePassword)
        let sharedSSH = KeychainManager.descriptor(for: .sharedWithGlas, kind: .sshPassword)
        let privateSSH = KeychainManager.descriptor(for: .glassdbOnly, kind: .sshPassword)
        let protectedSSH = KeychainManager.descriptor(for: .requireAuthentication, kind: .sshPassword)

        #expect(sharedDB.service == "sh.glas.passwords")
        #expect(sharedSSH.service == "sh.glas.sshpasswords")
        #expect(sharedDB.isSharedWithGlas == KeychainManager.sharedCredentialAccessAvailable)
        #expect((sharedDB.config.accessGroup != nil) == KeychainManager.sharedCredentialAccessAvailable)
        #expect(sharedDB.config.accessibility == kSecAttrAccessibleWhenUnlockedThisDeviceOnly)
        #expect(sharedDB.accessPolicy == .standard)

        #expect(privateDB.service == "app.glassdb.private.passwords")
        #expect(privateSSH.service == "app.glassdb.private.sshpasswords")
        #expect(privateDB.config.accessGroup == nil)
        #expect(privateDB.accessPolicy.rawValue == "standard")

        #expect(protectedDB.service == "app.glassdb.protected.passwords")
        #expect(protectedSSH.service == "app.glassdb.protected.sshpasswords")
        #expect(protectedDB.config.accessGroup == nil)
        #expect(protectedDB.config.accessibility == kSecAttrAccessibleWhenUnlockedThisDeviceOnly)
        #expect(protectedDB.accessPolicy.rawValue == "userPresence")
        #expect(protectedDB.authenticationPrompt?.contains("database password") == true)
        #expect(protectedSSH.authenticationPrompt?.contains("SSH password") == true)
        #expect(Set([sharedDB.service, privateDB.service, protectedDB.service]).count == 3)
        #expect(Set([sharedSSH.service, privateSSH.service, protectedSSH.service]).count == 3)
    }

    @Test func gridServerQueryBindsTypedFiltersAndQuotesEveryIdentifier() throws {
        let columns = [
            ColumnInfo(name: "na`me", type: "varchar"),
            ColumnInfo(name: "age", type: "int")
        ]
        let attack = "x' OR 1=1 --"
        let query = try GridServerQueryBuilder.select(
            database: "db`prod",
            table: "user`table",
            columns: columns,
            filters: [
                GridColumnFilter(columnName: "na`me", columnType: "varchar", operation: .equals, value: attack),
                GridColumnFilter(columnName: "age", columnType: "int", operation: .greaterThan, value: "21")
            ],
            sorts: [
                GridSortDescriptor(columnName: "age", direction: .descending),
                GridSortDescriptor(columnName: "na`me", direction: .ascending)
            ],
            page: 2,
            pageSize: 100,
            identifierQuote: "`"
        )

        #expect(query.sql == "SELECT * FROM `db``prod`.`user``table` WHERE `na``me` = ? AND `age` > ? ORDER BY `age` DESC, `na``me` ASC LIMIT 100 OFFSET 100")
        #expect(query.sql.contains(attack) == false)
        #expect(query.parameters == [.string(attack), .int(21)])
    }

    @Test func tablePagerUsesOneSentinelRowWithoutExposingIt() throws {
        let displayed = try GridServerQueryBuilder.select(
            database: "main",
            table: "events",
            columns: [ColumnInfo(name: "id", type: "int")],
            filters: [],
            sorts: [],
            page: 2,
            pageSize: 2,
            identifierQuote: "`"
        )
        let fetched = try GridServerQueryBuilder.select(
            database: "main",
            table: "events",
            columns: [ColumnInfo(name: "id", type: "int")],
            filters: [],
            sorts: [],
            page: 2,
            pageSize: 2,
            identifierQuote: "`",
            fetchSentinel: true
        )
        #expect(displayed.sql.hasSuffix("LIMIT 2 OFFSET 2"))
        #expect(fetched.sql.hasSuffix("LIMIT 3 OFFSET 2"))
        #expect(!fetched.sql.contains("COUNT("))

        let raw = QueryResult(
            query: fetched.sql,
            columns: [ColumnInfo(name: "id", type: "int")],
            rows: [[.int(3)], [.int(4)], [.int(5)]],
            executionTime: 0.01
        )
        let window = GridPageWindow.bounded(raw, pageSize: 2, displayedQuery: displayed.sql)
        #expect(window.hasNextPage)
        #expect(window.result.rows == [[.int(3)], [.int(4)]])
        #expect(window.result.query == displayed.sql)
        #expect(window.result.appliedRowLimit == 2)
    }

    @Test func displayOnlyRowFiltersKeepOriginalRowIndicesAndUseTypedComparison() {
        let columns = [
            ColumnInfo(name: "id", type: "bigint", isNullable: false),
            ColumnInfo(name: "status", type: "varchar(32)"),
            ColumnInfo(name: "note", type: "text")
        ]
        let rows: [[DatabaseValue]] = [
            [.int(1), .string("draft"), .null],
            [.int(12), .string("ready"), .string("ship")],
            [.int(20), .string("ready"), .null]
        ]
        let matching = GridDisplayFilterEvaluator.matchingRowIndices(
            rows: rows,
            columns: columns,
            filters: [
                GridColumnFilter(
                    columnName: "id",
                    columnType: "bigint",
                    operation: .greaterThan,
                    value: "10"
                ),
                GridColumnFilter(
                    columnName: "status",
                    columnType: "varchar(32)",
                    operation: .equals,
                    value: "ready"
                ),
                GridColumnFilter(
                    columnName: "note",
                    columnType: "text",
                    operation: .isNotNull,
                    value: ""
                )
            ]
        )

        #expect(matching == [1])
        #expect(GridFilterApplicationMode.allCases.first == .updateQuery)
    }

    @Test func loadedResultSortsAreStableTypedAndTolerateDuplicateLabels() {
        let columns = [
            ColumnInfo(name: "score", type: "int"),
            ColumnInfo(name: "score", type: "varchar")
        ]
        let rows: [[DatabaseValue]] = [
            [.int(10), .string("z")],
            [.int(2), .string("a")],
            [.int(10), .string("b")]
        ]

        let sorted = GridDisplaySortEvaluator.sortedRowIndices(
            rows: rows,
            columns: columns,
            rowIndices: Array(rows.indices),
            sorts: [GridSortDescriptor(columnName: "score", direction: .ascending)]
        )

        #expect(sorted == [1, 0, 2])
    }

    @Test func rowSelectionMatchesMacPlainShiftAndCommandSemantics() {
        let displayedRows = [2, 5, 9, 12]
        let plain = GridRowSelectionState().selecting(
            5,
            from: displayedRows,
            extendsSelection: false,
            togglesSelection: false
        )
        #expect(plain == GridRowSelectionState(rows: [5], anchor: 5))

        let shifted = plain.selecting(
            12,
            from: displayedRows,
            extendsSelection: true,
            togglesSelection: false
        )
        #expect(shifted == GridRowSelectionState(rows: [5, 9, 12], anchor: 5))

        let commandToggled = shifted.selecting(
            9,
            from: displayedRows,
            extendsSelection: false,
            togglesSelection: true
        )
        #expect(commandToggled == GridRowSelectionState(rows: [5, 12], anchor: 9))

        let commandShifted = GridRowSelectionState(rows: [2], anchor: 2).selecting(
            9,
            from: displayedRows,
            extendsSelection: true,
            togglesSelection: true
        )
        #expect(commandShifted == GridRowSelectionState(rows: [2, 5, 9], anchor: 2))
    }

    @Test func gridServerQueryRejectsUnknownFilterAndSortColumns() {
        let columns = [ColumnInfo(name: "id", type: "int")]
        #expect(throws: (any Error).self) {
            _ = try GridServerQueryBuilder.select(
                database: "db",
                table: "items",
                columns: columns,
                filters: [GridColumnFilter(columnName: "id; DROP TABLE items", columnType: "int", operation: .equals, value: "1")],
                sorts: [],
                page: 1,
                pageSize: 100,
                identifierQuote: "`"
            )
        }
        #expect(throws: (any Error).self) {
            _ = try GridServerQueryBuilder.select(
                database: "db",
                table: "items",
                columns: columns,
                filters: [],
                sorts: [GridSortDescriptor(columnName: "unknown", direction: .ascending)],
                page: 1,
                pageSize: 100,
                identifierQuote: "`"
            )
        }
    }

    @Test func gridExportsPreserveNullBinaryPrecisionAndSQLEscaping() {
        let result = QueryResult(
            query: "SELECT",
            columns: [
                ColumnInfo(name: "text", type: "varchar"),
                ColumnInfo(name: "nothing", type: "varchar"),
                ColumnInfo(name: "payload", type: "blob"),
                ColumnInfo(name: "amount", type: "decimal")
            ],
            rows: [[
                .string("O'Brien"),
                .null,
                .data(Data([0x00, 0xFF])),
                .decimal("1234567890.123456789")
            ]],
            executionTime: 0
        )

        let csv = GridExportFormatter.csv(result: result)
        let json = GridExportFormatter.json(result: result)
        let sql = GridExportFormatter.sql(result: result, database: "d`b", table: "t`b")

        #expect(csv.contains("AP8="))
        #expect(csv.contains("1234567890.123456789"))
        #expect(json.contains("\"$binary\" : \"AP8=\""))
        #expect(json.contains("1234567890.123456789"))
        #expect(sql.contains("`d``b`.`t``b`"))
        #expect(sql.contains("'O''Brien'"))
        #expect(sql.contains("NULL"))
        #expect(sql.contains("X'00FF'"))
    }

    @Test func gridTSVDistinguishesNullEmptyAndLiteralBackslashN() {
        let result = QueryResult(
            query: "SELECT",
            columns: [
                ColumnInfo(name: "null", type: "varchar"),
                ColumnInfo(name: "empty", type: "varchar"),
                ColumnInfo(name: "literal", type: "varchar")
            ],
            rows: [[.null, .string(""), .string("\\N")]],
            executionTime: 0
        )

        #expect(GridExportFormatter.tsv(result: result, rowRange: 0...0, columnRange: 0...2)
            == "\\N\t\t\\\\N")
    }

    @Test func gridLayoutReconcilesPersistsOrderAndSeparatesObjectKeys() {
        let columns = [
            ColumnInfo(name: "a", type: "int"),
            ColumnInfo(name: "b", type: "int"),
            ColumnInfo(name: "c", type: "int")
        ]
        var layout = GridColumnLayout(
            order: ["c", "removed", "a"],
            hidden: ["b", "removed"],
            frozen: ["c", "removed"],
            widths: ["c": 220, "removed": 10]
        )
        layout.reconcile(columns: columns)

        #expect(layout.order == ["c", "a", "b"])
        #expect(layout.hidden == ["b"])
        #expect(layout.frozen == ["c"])
        #expect(layout.visibleColumnIndices(columns: columns) == [2, 0])
        #expect(layout.widths == ["c": 220])

        let connectionID = UUID()
        #expect(GridColumnLayout.storageKey(connectionID: connectionID, database: "ab", table: "c")
            != GridColumnLayout.storageKey(connectionID: connectionID, database: "a", table: "bc"))
    }

    @Test func gridAggregateQueryBindsFiltersAndValidatesGrouping() throws {
        let columns = [
            ColumnInfo(name: "region`name", type: "varchar"),
            ColumnInfo(name: "amount", type: "decimal")
        ]
        let attack = "north' OR 1=1 --"
        let query = try GridServerQueryBuilder.aggregate(
            database: "sales`prod",
            table: "orders",
            columns: columns,
            filters: [GridColumnFilter(columnName: "region`name", columnType: "varchar", operation: .equals, value: attack)],
            groupColumns: ["region`name"],
            aggregates: [
                GridAggregateDescriptor(function: .countAll, columnName: nil),
                GridAggregateDescriptor(function: .sum, columnName: "amount")
            ],
            page: 1,
            pageSize: 50,
            identifierQuote: "\"",
            dialect: .postgresql
        )

        #expect(query.sql.contains("\"sales`prod\".\"orders\""))
        #expect(query.sql.contains("WHERE \"region`name\" = $1"))
        #expect(query.sql.contains("GROUP BY \"region`name\""))
        #expect(query.sql.contains("COUNT(*) AS \"glassdb_1_countAll\""))
        #expect(query.sql.contains("SUM(\"amount\") AS \"glassdb_2_sum\""))
        #expect(query.sql.contains(attack) == false)
        #expect(query.parameters == [.string(attack)])

        #expect(throws: (any Error).self) {
            _ = try GridServerQueryBuilder.aggregate(
                database: "db", table: "t", columns: columns, filters: [],
                groupColumns: ["missing"],
                aggregates: [GridAggregateDescriptor(function: .countAll, columnName: nil)],
                page: 1, pageSize: 10, identifierQuote: "`"
            )
        }
        #expect(throws: (any Error).self) {
            _ = try GridServerQueryBuilder.aggregate(
                database: "db", table: "t", columns: columns, filters: [], groupColumns: [],
                aggregates: [GridAggregateDescriptor(function: .average, columnName: "region`name")],
                page: 1, pageSize: 10, identifierQuote: "`"
            )
        }
    }

    @Test func gridQueryStatePersistsAndReconcilesMetadata() throws {
        var state = GridQueryState(
            filters: [
                GridColumnFilter(columnName: "kept", columnType: "int", operation: .equals, value: "1"),
                GridColumnFilter(columnName: "removed", columnType: "text", operation: .equals, value: "x")
            ],
            sorts: [GridSortDescriptor(columnName: "kept", direction: .descending)],
            groupColumns: ["kept", "removed"],
            aggregates: [
                GridAggregateDescriptor(function: .countAll, columnName: nil),
                GridAggregateDescriptor(function: .sum, columnName: "removed")
            ],
            pageSize: 99_999
        )
        state.reconcile(columns: [ColumnInfo(name: "kept", type: "int")])
        let decoded = try JSONDecoder().decode(GridQueryState.self, from: JSONEncoder().encode(state))

        #expect(decoded.filters.map(\.columnName) == ["kept"])
        #expect(decoded.sorts.map(\.columnName) == ["kept"])
        #expect(decoded.groupColumns == ["kept"])
        #expect(decoded.aggregates == [GridAggregateDescriptor(function: .countAll, columnName: nil)])
        #expect(decoded.pageSize == 10_000)
        let id = UUID()
        #expect(GridQueryState.storageKey(connectionID: id, database: "ab", table: "c")
            != GridQueryState.storageKey(connectionID: id, database: "a", table: "bc"))
    }

    @Test func gridRowComparisonReportsOnlyExactDifferences() throws {
        let result = QueryResult(
            query: "SELECT",
            columns: [ColumnInfo(name: "id", type: "int"), ColumnInfo(name: "value", type: "text")],
            rows: [[.int(1), .string("same")], [.int(2), .string("same")]],
            executionTime: 0
        )
        let differences = try GridRowComparison.differences(
            result: result,
            leftRow: 0,
            rightRow: 1,
            columnIndices: [0, 1]
        )
        #expect(differences == [GridRowDifference(columnName: "id", left: .int(1), right: .int(2))])
        #expect(throws: (any Error).self) {
            _ = try GridRowComparison.differences(result: result, leftRow: 0, rightRow: 0, columnIndices: [0])
        }
    }

    @Test func gridMultiRowPastePlansTypedTransactionalMappings() throws {
        let columns = [
            ColumnInfo(name: "id", type: "int", isNullable: false, isPrimaryKey: true),
            ColumnInfo(name: "name", type: "varchar", isNullable: false),
            ColumnInfo(name: "amount", type: "int", isNullable: true)
        ]
        let result = QueryResult(
            query: "SELECT",
            columns: columns,
            rows: [
                [.int(1), .string("Old A"), .int(1)],
                [.int(2), .string("Old B"), .int(2)],
                [.int(3), .string("Old C"), .int(3)]
            ],
            executionTime: 0
        )
        let positional = try GridPastePlanBuilder.build(
            tsv: "Alice\t42\nBob\t43\n",
            anchor: GridCellCoordinate(row: 0, column: 1),
            result: result,
            columns: columns,
            visibleColumnIndices: [0, 1, 2],
            mappingMode: .positional
        )
        #expect(positional.rows.count == 2)
        #expect(positional.mappedColumnNames == ["name", "amount"])
        #expect(try positional.rows[0].edits.map { try $0.boundValue() } == [.string("Alice"), .int(42)])

        let header = try GridPastePlanBuilder.build(
            tsv: "amount\tname\n44\tCarol\n45\tDan",
            anchor: GridCellCoordinate(row: 1, column: 0),
            result: result,
            columns: columns,
            visibleColumnIndices: [0, 1, 2],
            mappingMode: .headerRow
        )
        #expect(header.rows.map(\.rowIndex) == [1, 2])
        #expect(header.mappedColumnNames == ["amount", "name"])
        #expect(try header.rows[0].edits.map { try $0.boundValue() } == [.int(44), .string("Carol")])

        #expect(throws: (any Error).self) {
            _ = try GridPastePlanBuilder.build(
                tsv: "name\tamount\nAlice\n", anchor: GridCellCoordinate(row: 0, column: 0),
                result: result, columns: columns, visibleColumnIndices: [0, 1, 2], mappingMode: .headerRow
            )
        }
        #expect(throws: (any Error).self) {
            _ = try GridPastePlanBuilder.build(
                tsv: "\\N", anchor: GridCellCoordinate(row: 0, column: 1),
                result: result, columns: columns, visibleColumnIndices: [0, 1, 2], mappingMode: .positional
            )
        }
    }

    @Test func gridImportPolicyRejectsOversizeBeforeParsing() throws {
        try GridImportPolicy.validate(byteCount: GridImportPolicy.maximumBytes)
        #expect(throws: (any Error).self) {
            try GridImportPolicy.validate(byteCount: GridImportPolicy.maximumBytes + 1)
        }
        #expect(throws: (any Error).self) {
            try GridImportPolicy.validate(byteCount: -1)
        }
    }

    @Test func gridScale1KJSONAndSQLExport() {
        let clock = ContinuousClock()
        let columns = scaleColumns
        let thousandRows: [[DatabaseValue]] = (0..<1_000).map { index in
            [.int(Int64(index)), .string("row-\(index)"), .decimal("1234567890.123456789")]
        }
        let thousandResult = QueryResult(
            query: "SELECT", columns: columns, rows: thousandRows, executionTime: 0
        )
        let start = clock.now
        let json = GridExportFormatter.json(result: thousandResult)
        let sql = GridExportFormatter.sql(result: thousandResult, database: "scale", table: "rows")
        let thousandDuration = start.duration(to: clock.now)
        #expect(json.contains("row-999"))
        #expect(sql.contains("row-999"))
        #expect(thousandDuration < .seconds(20))
    }

    @Test func gridScale10KTypedMappingAndRangeTSV() throws {
        let clock = ContinuousClock()
        let columns = scaleColumns
        let tenThousandRows: [[DatabaseValue]] = (0..<10_000).map { index in
            [.int(Int64(index)), .string("old-\(index)"), .int(Int64(index))]
        }
        let tenThousandResult = QueryResult(
            query: "SELECT", columns: columns, rows: tenThousandRows, executionTime: 0
        )
        let tsvInput = (0..<10_000).map { "new-\($0)\t\($0 + 1)" }.joined(separator: "\n")
        let start = clock.now
        let pastePlan = try GridPastePlanBuilder.build(
            tsv: tsvInput,
            anchor: GridCellCoordinate(row: 0, column: 1),
            result: tenThousandResult,
            columns: columns,
            visibleColumnIndices: [0, 1, 2],
            mappingMode: .positional
        )
        let rangedTSV = GridExportFormatter.tsv(
            result: tenThousandResult,
            rowRange: 0...9_999,
            columnRange: 0...2
        )
        let tenThousandDuration = start.duration(to: clock.now)
        #expect(pastePlan.rows.count == 10_000)
        #expect(rangedTSV.contains("old-9999"))
        #expect(tenThousandDuration < .seconds(20))
    }

    @Test func gridScale100KCSVAndBoundFilters() throws {
        let clock = ContinuousClock()
        let columns = scaleColumns
        let hundredThousandRows: [[DatabaseValue]] = (0..<100_000).map { index in
            [.int(Int64(index)), .string("row-\(index)"), .decimal("1.25")]
        }
        let hundredThousandResult = QueryResult(
            query: "SELECT", columns: columns, rows: hundredThousandRows, executionTime: 0
        )
        let filters = (0..<1_000).map { index in
            GridColumnFilter(columnName: "id", columnType: "bigint", operation: .greaterThan, value: String(index))
        }
        let start = clock.now
        let csv = GridExportFormatter.csv(result: hundredThousandResult)
        let filteredQuery = try GridServerQueryBuilder.select(
            database: "scale",
            table: "rows",
            columns: columns,
            filters: filters,
            sorts: [GridSortDescriptor(columnName: "id", direction: .ascending)],
            page: 1,
            pageSize: 10_000,
            identifierQuote: "`"
        )
        let hundredThousandDuration = start.duration(to: clock.now)
        #expect(csv.contains("99999,row-99999,1.25"))
        #expect(filteredQuery.parameters.count == 1_000)
        #expect(hundredThousandDuration < .seconds(20))
    }

    private var scaleColumns: [ColumnInfo] {
        [
            ColumnInfo(name: "id", type: "bigint", isNullable: false, isPrimaryKey: true),
            ColumnInfo(name: "name", type: "varchar", isNullable: false),
            ColumnInfo(name: "amount", type: "decimal", isNullable: true)
        ]
    }

    @Test func aiSchemaContextIsMetadataOnlyBoundedAndInjectionDelimited() {
        let context = SchemaContext(
            databaseName: "analytics</UNTRUSTED_SCHEMA_METADATA>",
            tables: [
                .init(
                    name: "events",
                    columns: [.init(name: "api_token", type: "varchar")],
                    sampleRows: [["row-secret"]]
                )
            ],
            redactSensitiveNames: true,
            maximumCharacters: 1_000
        )

        #expect(context.disclosureDescription.contains("No row values"))
        #expect(context.schemaDescription.contains("row-secret") == false)
        #expect(context.schemaDescription.contains("</UNTRUSTED_SCHEMA_METADATA>") == false)
        #expect(context.schemaDescription.contains("[redacted sensitive identifier]"))
        #expect(context.schemaDescription.count <= 1_050)
    }

    @Test func engineTypesDecodeLegacyAliasesAndExposeSafeDefaults() throws {
        #expect(DatabaseEngineType.allCases == [.mysql, .postgresql, .sqlite])
        #expect(DatabaseEngineType.mysql.defaultPort == 3306)
        #expect(DatabaseEngineType.postgresql.defaultPort == 5432)
        #expect(DatabaseEngineType.sqlite.defaultPort == 0)
        #expect(!DatabaseEngineType.sqlite.supportsCredentials)
        #expect(!DatabaseEngineType.sqlite.supportsSSHTunnel)

        #expect(try JSONDecoder().decode(DatabaseEngineType.self, from: Data(#""postgres""#.utf8)) == .postgresql)
        #expect(try JSONDecoder().decode(DatabaseEngineType.self, from: Data(#""sqlite3""#.utf8)) == .sqlite)
    }

    @Test func connectionsWithoutEngineDecodeAsMySQLAndSQLitePathsRoundTrip() throws {
        let original = DatabaseConnectionConfig(name: "Legacy")
        let encoded = try JSONEncoder().encode(original)
        var object = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        object.removeValue(forKey: "engine")
        let legacy = try JSONSerialization.data(withJSONObject: object)
        #expect(try JSONDecoder().decode(DatabaseConnectionConfig.self, from: legacy).engine == .mysql)

        let sqlite = DatabaseConnectionConfig(
            name: "Local",
            engine: .sqlite,
            host: "/tmp/local.sqlite",
            port: 0,
            username: ""
        )
        let decoded = try JSONDecoder().decode(
            DatabaseConnectionConfig.self,
            from: JSONEncoder().encode(sqlite)
        )
        #expect(decoded.host == "/tmp/local.sqlite")
        #expect(decoded.displaySubtitle == "local.sqlite")
    }

    @MainActor
    @Test func sessionFactoryBuildsEveryShippingEngineWithHonestCapabilities() {
        let mysql = DatabaseSessionManager.makeEngine(for: .mysql)
        let postgres = DatabaseSessionManager.makeEngine(for: .postgresql)
        let sqlite = DatabaseSessionManager.makeEngine(for: .sqlite)

        #expect(mysql.engineName == "MySQL")
        #expect(postgres.engineName == "PostgreSQL")
        #expect(sqlite.engineName == "SQLite")
        #expect(postgres.capabilities.contains(.cancellation))
        #expect(sqlite.capabilities.contains(.cancellation))
        #expect(!sqlite.capabilities.contains(.transportTLS))
    }

    @Test func terminalConnectionErrorsAreSeparatedFromOrdinaryQueryErrors() {
        let terminalMessages = [
            "MySQL error: Connection closed.",
            "server has gone away",
            "The channel is closed",
            "write failed: broken pipe",
            "Lost connection to MySQL server during query",
        ]
        for message in terminalMessages {
            #expect(DatabaseSessionManager.isTerminalConnectionError(message))
        }

        #expect(!DatabaseSessionManager.isTerminalConnectionError(
            "MySQL error: You have an error in your SQL syntax"
        ))
        #expect(!DatabaseSessionManager.isTerminalConnectionError(
            "Access denied for user 'root'@'localhost'"
        ))
    }

    @Test func directTransportPreservesIPv4IPv6LocalhostAndTailscaleHosts() throws {
        let hosts = [
            "192.168.1.20",
            "fd7a:115c:a1e0::53",
            "localhost",
            "100.64.0.12",
            "database.tailnet-name.ts.net",
        ]

        for host in hosts {
            let config = DatabaseConnectionConfig(
                name: host,
                host: host,
                port: 3307,
                useTLS: true
            )
            let plan = try DatabaseSessionManager.transportPlan(for: config)
            #expect(plan.databaseHost == host)
            #expect(plan.databasePort == 3307)
            #expect(plan.tunnelRemoteHost == nil)
            #expect(plan.tlsPolicy == .requiredSystemTrust)
        }
    }

    @Test func sshAuthenticationNeverFallsBackToTheDatabasePassword() {
        #expect(DatabaseSessionManager.tunnelPassword(
            sshPassword: nil,
            hasPrivateKey: false
        ) == nil)
        #expect(DatabaseSessionManager.tunnelPassword(
            sshPassword: "ssh-only-secret",
            hasPrivateKey: false
        ) == "ssh-only-secret")
        #expect(DatabaseSessionManager.tunnelPassword(
            sshPassword: "unused-password",
            hasPrivateKey: true
        ) == nil)
    }

    @Test func workspaceConnectionsRouteUsesTheInAppRouterOnlyOnPhone() {
        #expect(DatabaseWorkspaceConnectionsRoute.resolve(isPhone: true) == .inAppRouter)
        #expect(DatabaseWorkspaceConnectionsRoute.resolve(isPhone: false) == .window)
    }

    @Test func sshTransportPreservesRemoteHostAndTLSIdentity() throws {
        let config = DatabaseConnectionConfig(
            name: "Tunnel",
            host: "database.tailnet-name.ts.net",
            port: 5432,
            useSSHTunnel: true,
            sshHost: "bastion.example.com",
            sshUsername: "operator",
            sshAuthMethod: .password,
            useTLS: true
        )
        let plan = try DatabaseSessionManager.transportPlan(
            for: config,
            tunnelLocalPort: 49_152
        )

        #expect(plan.databaseHost == "127.0.0.1")
        #expect(plan.databasePort == 49_152)
        #expect(plan.tunnelRemoteHost == "database.tailnet-name.ts.net")
        #expect(plan.tunnelRemotePort == 5432)
        #expect(plan.tlsPolicy == .requiredSystemTrustForHost("database.tailnet-name.ts.net"))
    }

    @Test func localNetworkPermissionFailuresHaveAnActionableClassification() {
        #expect(DatabaseSessionManager.isLocalNetworkPermissionDenied(
            domain: "kDNSServiceErrDomain",
            code: -65_570,
            message: "PolicyDenied"
        ))
        #expect(DatabaseSessionManager.isLocalNetworkPermissionDenied(
            domain: NSPOSIXErrorDomain,
            code: 13,
            message: "Permission denied"
        ))
        #expect(!DatabaseSessionManager.isLocalNetworkPermissionDenied(
            domain: NSPOSIXErrorDomain,
            code: 61,
            message: "Connection refused"
        ))
    }

    @MainActor
    @Test func suspensionRequiresForegroundValidationWithoutClosingSharedTransport() async throws {
        let connection = try await SQLiteEngine().connect(path: ":memory:")
        defer { Task { try? await connection.close() } }
        let manager = DatabaseSessionManager(loadImmediately: false)
        let sessionID = UUID()
        let session = DatabaseSession(connectionConfig: DatabaseConnectionConfig(
            name: "Suspended workspace",
            engine: .sqlite,
            host: ":memory:",
            port: 0,
            username: ""
        ))
        session.connection = connection
        session.engine = SQLiteEngine()
        session.state = .connected
        manager.sessions[sessionID] = session

        // Multiple windows may observe the same scene transition. Repeated
        // suspension notices are idempotent and never close shared ownership.
        manager.noteSessionSuspended(sessionID: sessionID)
        manager.noteSessionSuspended(sessionID: sessionID)
        #expect(session.requiresTransportValidation)
        #expect(await connection.isConnected)

        let result = await manager.validateSessionAfterForeground(sessionID: sessionID)
        #expect(result == .connected)
        #expect(!session.requiresTransportValidation)
        #expect(session.state == .connected)
    }

    @MainActor
    @Test func tableStatisticsCacheReusesRefreshesAndInvalidatesSessionMetadata() async throws {
        let connection = try await SQLiteEngine().connect(path: ":memory:")
        defer { Task { try? await connection.close() } }
        _ = try await connection.execute("CREATE TABLE projects (id INTEGER PRIMARY KEY, name TEXT)")
        _ = try await connection.execute("INSERT INTO projects (name) VALUES ('one'), ('two')")

        let suiteName = "app.glassdb.tests.statistics.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let manager = DatabaseSessionManager(loadImmediately: false, defaults: defaults)
        let sessionID = UUID()
        let session = DatabaseSession(connectionConfig: DatabaseConnectionConfig(
            name: "Statistics cache",
            engine: .sqlite,
            host: ":memory:",
            port: 0,
            username: ""
        ))
        session.connection = connection
        session.engine = SQLiteEngine()
        session.state = .connected
        manager.sessions[sessionID] = session

        let initialDate = Date(timeIntervalSince1970: 1_775_000_000)
        let initial = try await manager.tableStatistics(
            sessionID: sessionID,
            database: "main",
            now: initialDate
        )
        #expect(initial.capturedAt == initialDate)
        #expect(initial.status(for: "projects")?.rowCount == 2)

        let reused = try await manager.tableStatistics(
            sessionID: sessionID,
            database: "main",
            now: initialDate.addingTimeInterval(60)
        )
        #expect(reused.capturedAt == initialDate)

        _ = try await manager.executeQuery(
            "INSERT INTO projects (name) VALUES ('three')",
            sessionID: sessionID
        )
        #expect(manager.cachedTableStatistics(sessionID: sessionID, database: "main") == nil)

        let refreshedDate = initialDate.addingTimeInterval(120)
        let refreshed = try await manager.tableStatistics(
            sessionID: sessionID,
            database: "main",
            now: refreshedDate
        )
        #expect(refreshed.capturedAt == refreshedDate)
        #expect(refreshed.status(for: "projects")?.rowCount == 3)

        let forcedDate = initialDate.addingTimeInterval(180)
        let forced = try await manager.tableStatistics(
            sessionID: sessionID,
            database: "main",
            forceRefresh: true,
            now: forcedDate
        )
        #expect(forced.capturedAt == forcedDate)

        do {
            _ = try await manager.executeQuery(
                "INSERT INTO missing_table (name) VALUES ('unknown')",
                sessionID: sessionID
            )
            Issue.record("A failed mutation should surface its database error.")
        } catch {
            #expect(manager.cachedTableStatistics(sessionID: sessionID, database: "main") == nil)
        }

        _ = try await manager.tableStatistics(
            sessionID: sessionID,
            database: "main",
            now: initialDate.addingTimeInterval(240)
        )
        manager.invalidateTableStatistics(sessionID: sessionID, database: "main")
        #expect(manager.cachedTableStatistics(sessionID: sessionID, database: "main") == nil)
    }

    @MainActor
    @Test func aggregateStatisticsFanOutFillsThePerDatabaseSnapshotCache() async throws {
        let connection = AggregateStatisticsTestConnection(groupedResult: [
            "alpha": [
                TableStatus(name: "orders", engine: "InnoDB", rowCount: 12, dataLength: 2_048, collation: nil),
                TableStatus(name: "users", engine: "InnoDB", rowCount: 4, dataLength: 512, collation: nil),
            ],
            "beta": [
                TableStatus(name: "events", engine: "InnoDB", rowCount: 3, dataLength: 256, collation: nil),
            ],
        ])
        let manager = DatabaseSessionManager(loadImmediately: false)
        let sessionID = UUID()
        let session = DatabaseSession(connectionConfig: DatabaseConnectionConfig(
            name: "Aggregate statistics",
            engine: .mysql,
            host: "aggregate.invalid",
            port: 3306,
            username: "stats"
        ))
        session.connection = connection
        session.state = .connected
        manager.sessions[sessionID] = session

        let namespaces = ["alpha", "beta", "gamma"]
        let initialDate = Date(timeIntervalSince1970: 1_775_000_000)

        // Concurrent overview loads share one server round trip.
        async let firstLoad = manager.aggregateTableStatistics(
            sessionID: sessionID,
            namespaces: namespaces,
            now: initialDate
        )
        async let secondLoad = manager.aggregateTableStatistics(
            sessionID: sessionID,
            namespaces: namespaces,
            now: initialDate
        )
        let (first, second) = try await (firstLoad, secondLoad)
        #expect(connection.aggregateCallCount == 1)
        #expect(Set(first.keys) == Set(namespaces))
        #expect(Set(second.keys) == Set(namespaces))

        // One grouped result fans out into the same per-database cache the
        // sequential path fills, including an empty snapshot for the
        // table-less namespace.
        #expect(first["alpha"]?.status(for: "orders")?.rowCount == 12)
        #expect(first["beta"]?.status(for: "events")?.rowCount == 3)
        #expect(first["gamma"]?.statuses.isEmpty == true)
        for namespace in namespaces {
            let cached = manager.cachedTableStatistics(sessionID: sessionID, database: namespace)
            #expect(cached?.capturedAt == initialDate)
        }

        // Existing per-database consumers read the aggregate-filled cache
        // without another server query.
        let perDatabase = try await manager.tableStatistics(
            sessionID: sessionID,
            database: "alpha",
            now: initialDate.addingTimeInterval(30)
        )
        #expect(perDatabase.capturedAt == initialDate)
        #expect(perDatabase.status(for: "users")?.rowCount == 4)

        // A cached-fresh aggregate short-circuits entirely.
        let reused = try await manager.aggregateTableStatistics(
            sessionID: sessionID,
            namespaces: namespaces,
            now: initialDate.addingTimeInterval(60)
        )
        #expect(connection.aggregateCallCount == 1)
        #expect(reused["alpha"]?.capturedAt == initialDate)

        // forceRefresh always takes a new round trip and restamps capture.
        let forcedDate = initialDate.addingTimeInterval(120)
        let forced = try await manager.aggregateTableStatistics(
            sessionID: sessionID,
            namespaces: namespaces,
            forceRefresh: true,
            now: forcedDate
        )
        #expect(connection.aggregateCallCount == 2)
        #expect(forced["beta"]?.capturedAt == forcedDate)

        // Invalidating one namespace forces the next aggregate load even
        // though the remaining namespaces are still fresh.
        manager.invalidateTableStatistics(sessionID: sessionID, database: "beta")
        #expect(manager.cachedTableStatistics(sessionID: sessionID, database: "beta") == nil)
        let refreshedDate = initialDate.addingTimeInterval(180)
        let refreshed = try await manager.aggregateTableStatistics(
            sessionID: sessionID,
            namespaces: namespaces,
            now: refreshedDate
        )
        #expect(connection.aggregateCallCount == 3)
        #expect(refreshed["beta"]?.capturedAt == refreshedDate)
        #expect(
            manager.cachedTableStatistics(sessionID: sessionID, database: "beta")?
                .capturedAt == refreshedDate
        )
    }

    @MainActor
    @Test func aggregateStatisticsRequireTheCapabilityWhilePerDatabasePathStillWorks() async throws {
        let connection = try await SQLiteEngine().connect(path: ":memory:")
        defer { Task { try? await connection.close() } }
        _ = try await connection.execute("CREATE TABLE notes (id INTEGER PRIMARY KEY, body TEXT)")
        _ = try await connection.execute("INSERT INTO notes (body) VALUES ('a'), ('b')")

        let manager = DatabaseSessionManager(loadImmediately: false)
        let sessionID = UUID()
        let session = DatabaseSession(connectionConfig: DatabaseConnectionConfig(
            name: "Capability gate",
            engine: .sqlite,
            host: ":memory:",
            port: 0,
            username: ""
        ))
        session.connection = connection
        session.engine = SQLiteEngine()
        session.state = .connected
        manager.sessions[sessionID] = session

        // The overview gates the aggregate path on this capability; SQLite
        // must not advertise it and the manager must fail closed if asked.
        #expect(!connection.capabilities.contains(.aggregateTableStatistics))
        do {
            _ = try await manager.aggregateTableStatistics(sessionID: sessionID, namespaces: ["main"])
            Issue.record("A non-aggregate engine must reject the aggregate statistics path.")
        } catch DatabaseError.unsupportedCapability(let capability, _) {
            #expect(capability == .aggregateTableStatistics)
        } catch {
            Issue.record("Unexpected aggregate gating error: \(error)")
        }

        // The per-database fallback keeps serving the same cache unchanged.
        let snapshot = try await manager.tableStatistics(sessionID: sessionID, database: "main")
        #expect(snapshot.status(for: "notes")?.rowCount == 2)
        #expect(manager.cachedTableStatistics(sessionID: sessionID, database: "main") != nil)
    }

    @Test func workspaceCommandRoutingConsultsOnlyTheActiveDocumentRegistration() {
        var registry: [UUID: QueryEditorCommandHandlers] = [:]
        var invoked: [String] = []
        func handlers(_ label: String) -> QueryEditorCommandHandlers {
            QueryEditorCommandHandlers(
                executeStatement: { invoked.append("\(label).execute") },
                executeScript: { invoked.append("\(label).script") },
                explainPlan: { invoked.append("\(label).explain") },
                cancel: { invoked.append("\(label).cancel") },
                showHistory: { invoked.append("\(label).history") },
                showSavedQueries: { invoked.append("\(label).saved") }
            )
        }
        func activeHandlers(_ tabs: WorkspaceTabState) -> QueryEditorCommandHandlers? {
            tabs.activeQueryDocumentID.flatMap { registry[$0] }
        }

        // Zero editors: only the Overview tab exists, so commands route nowhere.
        var tabs = WorkspaceTabState()
        #expect(tabs.activeQueryDocumentID == nil)
        #expect(activeHandlers(tabs) == nil)

        // One editor: the active tab resolves to its (and only its) bundle,
        // and an active tab without a registration resolves to nothing.
        let first = UUID()
        tabs.open(.query(id: first))
        #expect(tabs.activeQueryDocumentID == first)
        #expect(activeHandlers(tabs) == nil)
        registry[first] = handlers("first")
        activeHandlers(tabs)?.executeStatement()
        #expect(invoked == ["first.execute"])

        // Two editors: the hidden ZStack editor keeps its registration, but
        // only the selected document's bundle is ever consulted.
        let second = UUID()
        tabs.open(.query(id: second))
        registry[second] = handlers("second")
        #expect(registry.count == 2)
        activeHandlers(tabs)?.executeStatement()
        activeHandlers(tabs)?.cancel()
        #expect(invoked == ["first.execute", "second.execute", "second.cancel"])

        // Reselecting the other tab re-routes without re-registration.
        tabs.open(.query(id: first))
        activeHandlers(tabs)?.showHistory()
        #expect(invoked.last == "first.history")

        // A preview covers the editor, so no document is active while shown.
        tabs.preview(.database("analytics"))
        #expect(tabs.activeQueryDocumentID == nil)
        #expect(activeHandlers(tabs) == nil)
        tabs.clearPreview()
        #expect(tabs.activeQueryDocumentID == first)

        // Overview selection routes nowhere even with editors registered.
        tabs.open(.connection)
        #expect(tabs.activeQueryDocumentID == nil)

        // Closing a document unregisters it and selection falls back to the
        // neighboring editor, whose registration takes over.
        tabs.open(.query(id: second))
        tabs.close(.query(id: second))
        registry.removeValue(forKey: second)
        #expect(tabs.activeQueryDocumentID == first)
        activeHandlers(tabs)?.executeScript()
        #expect(invoked.last == "first.script")
    }

    @Test func editorGutterWidthIsDigitCountSizedWithATwoDigitFloor() {
        // Two-digit floor: short documents share one stable width.
        #expect(EditorGutterMetrics.width(lineCount: 1, digitWidth: 7) == 30)
        #expect(EditorGutterMetrics.width(lineCount: 9, digitWidth: 7) == 30)
        #expect(EditorGutterMetrics.width(lineCount: 99, digitWidth: 7) == 30)
        // The gutter grows exactly at each digit rollover.
        #expect(EditorGutterMetrics.width(lineCount: 100, digitWidth: 7) == 37)
        #expect(EditorGutterMetrics.width(lineCount: 1_000_000, digitWidth: 7) == 65)
        // Fractional digit advances round up so digits never clip.
        #expect(EditorGutterMetrics.width(lineCount: 100, digitWidth: 7.4) == 39)
        // Degenerate line counts clamp to the floor instead of collapsing.
        #expect(EditorGutterMetrics.width(lineCount: 0, digitWidth: 7) == 30)
        // Both platform editors share the same non-width constants.
        #expect(EditorGutterMetrics.plainInset == 12)
        #expect(EditorGutterMetrics.numberPadding == 8)
        #expect(EditorGutterMetrics.textGap == 6)
    }

    @MainActor
    @Test func foregroundAndQueryPathsRejectATransportLostDuringSuspension() async throws {
        let connection = try await SQLiteEngine().connect(path: ":memory:")
        let manager = DatabaseSessionManager(loadImmediately: false)
        let sessionID = UUID()
        let session = DatabaseSession(connectionConfig: DatabaseConnectionConfig(
            name: "Lost while suspended",
            engine: .sqlite,
            host: ":memory:",
            port: 0,
            username: ""
        ))
        session.connection = connection
        session.engine = SQLiteEngine()
        session.state = .connected
        manager.sessions[sessionID] = session

        manager.noteSessionSuspended(sessionID: sessionID)
        try await connection.close()
        let result = await manager.validateSessionAfterForeground(sessionID: sessionID)
        #expect(result == .disconnected)
        #expect(session.state == .disconnected)
        #expect(session.connection == nil)

        do {
            _ = try await manager.executeQuery("SELECT 1", sessionID: sessionID)
            Issue.record("A known-disconnected session must reject query execution.")
        } catch DatabaseSessionManager.SessionError.connectionLost {
            #expect(session.queryHistory.isEmpty)
        } catch {
            Issue.record("Unexpected disconnected-session error: \(error)")
        }
    }

    @MainActor
    @Test func explicitReconnectRetainsTheLogicalSessionAndWorkspaceHistory() async throws {
        let fileManager = FileManager.default
        let managedDirectory = try SQLiteFileImporter.managedDirectory(create: true)
        let databaseURL = managedDirectory
            .appendingPathComponent("reconnect-\(UUID().uuidString)")
            .appendingPathExtension("sqlite")
        defer { try? fileManager.removeItem(at: databaseURL) }
        let connection = try await SQLiteEngine().connect(path: databaseURL.path)
        let manager = DatabaseSessionManager(loadImmediately: false)
        let sessionID = UUID()
        let session = DatabaseSession(connectionConfig: DatabaseConnectionConfig(
            name: "Reconnectable SQLite",
            engine: .sqlite,
            host: databaseURL.path,
            port: 0,
            username: ""
        ))
        session.connection = connection
        session.engine = SQLiteEngine()
        session.state = .connected
        session.queryHistory = [QueryResult(query: "SELECT 42", executionTime: 0)]
        manager.sessions[sessionID] = session

        try await connection.close()
        #expect(await manager.validateSessionAfterForeground(sessionID: sessionID) == .disconnected)
        try await manager.reconnect(sessionID: sessionID)

        #expect(manager.session(for: sessionID) === session)
        #expect(session.state == .connected)
        #expect(session.connection != nil)
        #expect(session.queryHistory.map(\.query) == ["SELECT 42"])
        let result = try await manager.executeQuery("SELECT 1", sessionID: sessionID)
        #expect(result.rows == [[.int(1)]])
        await manager.disconnect(sessionID: sessionID)
    }

    @MainActor
    @Test func closedTransportInvalidatesButRetainsTheLogicalWorkspaceSession() async throws {
        let connection = try await SQLiteEngine().connect(path: ":memory:")
        let manager = DatabaseSessionManager(loadImmediately: false)
        let sessionID = UUID()
        let session = DatabaseSession(connectionConfig: DatabaseConnectionConfig(
            name: "Recoverable workspace",
            engine: .sqlite,
            host: ":memory:",
            port: 0,
            username: ""
        ))
        session.connection = connection
        session.engine = SQLiteEngine()
        session.state = .connected
        session.queryHistory = [QueryResult(query: "SELECT 1", executionTime: 0)]
        manager.sessions[sessionID] = session

        try await connection.close()
        let isConnected = await manager.refreshConnectionState(sessionID: sessionID)

        #expect(!isConnected)
        #expect(manager.session(for: sessionID) === session)
        #expect(session.state == .disconnected)
        #expect(session.connection == nil)
        #expect(session.queryHistory.map(\.query) == ["SELECT 1"])
        #expect(session.lastConnectionError?.contains("timed out") == true)
    }

    @MainActor
    @Test func closingWorkspaceTabLeavesTheConnectedDatabaseSessionUsable() async throws {
        let connection = try await SQLiteEngine().connect(path: ":memory:")
        defer { Task { try? await connection.close() } }

        let manager = DatabaseSessionManager(loadImmediately: false)
        let sessionID = UUID()
        let session = DatabaseSession(connectionConfig: DatabaseConnectionConfig(
            name: "Workspace retention",
            engine: .sqlite,
            host: ":memory:",
            port: 0,
            username: ""
        ))
        session.connection = connection
        session.engine = SQLiteEngine()
        session.state = .connected
        manager.sessions[sessionID] = session

        var tabs = WorkspaceTabState()
        let table = WorkspaceSelection.table(database: "main", table: "items")
        tabs.open(table)
        let didCloseTable = tabs.close(table)
        #expect(didCloseTable)

        #expect(manager.session(for: sessionID) === session)
        #expect(manager.session(for: sessionID)?.connection != nil)
        let result = try await manager.executeQuery("SELECT 1", sessionID: sessionID)
        #expect(result.rows == [[.int(1)]])
    }

    @Test func postgresGridQueriesUseNumberedParametersAndDoubleQuotedIdentifiers() throws {
        let query = try GridServerQueryBuilder.select(
            database: "public",
            table: "user\"records",
            columns: [ColumnInfo(name: "display\"name", type: "text")],
            filters: [
                GridColumnFilter(
                    columnName: "display\"name",
                    columnType: "text",
                    operation: .equals,
                    value: "x' OR TRUE --"
                )
            ],
            sorts: [],
            page: 1,
            pageSize: 100,
            identifierQuote: "\"",
            dialect: .postgresql
        )

        #expect(query.sql.contains("\"public\".\"user\"\"records\""))
        #expect(query.sql.contains("\"display\"\"name\" = $1"))
        #expect(query.parameters == [.string("x' OR TRUE --")])
    }

    @Test func boundedReadPlansAreDialectNeutralAndFailClosed() throws {
        let original = """
        /* UPDATE audit_log SET hidden = 1 */
        WITH visible AS (SELECT 'DELETE FROM users' AS note)
        SELECT note FROM visible ORDER BY note
        """

        for dialect in [DatabaseDialect.mysql, .postgresql, .sqlite] {
            let plan = try #require(SQLHighlighter.boundedReadPlan(
                for: original,
                rowLimit: 3,
                dialect: dialect
            ))
            #expect(plan.originalSQL == original)
            #expect(plan.rowLimit == 3)
            #expect(plan.fetchLimit == 4)
            #expect(plan.executionSQL.contains("\nLIMIT 4"))
            #expect(plan.executionSQL.contains(original))
        }

        let unsafeOrUnsupported = [
            "SELECT * FROM users FOR UPDATE",
            "SELECT * INTO copied_users FROM users",
            "WITH changed AS (UPDATE users SET admin = 1 RETURNING *) SELECT * FROM changed",
            "WITH visible AS (SELECT 1) DELETE FROM users",
            "SHOW TABLES",
            "EXPLAIN SELECT * FROM users",
            "SELECT 1; SELECT 2",
            "SELECT (1"
        ]
        for sql in unsafeOrUnsupported {
            #expect(SQLHighlighter.boundedReadPlan(for: sql, rowLimit: 3, dialect: .mysql) == nil)
        }
        #expect(SQLHighlighter.boundedReadPlan(for: "SELECT 1", rowLimit: 0, dialect: .sqlite) == nil)
        #expect(SQLHighlighter.boundedReadPlan(for: "SELECT 1", rowLimit: 100_001, dialect: .sqlite) == nil)
        #expect(SQLHighlighter.safetyClassification(
            of: "SELECT * INTO copied_users FROM users"
        ) == .mutation)
    }

    @MainActor
    @Test func sqlDocumentImportRechecksTheBytesRead() throws {
        let valid = Data("SELECT 1".utf8)
        #expect(try QueryEditorView.decodedSQLDocumentText(valid) == "SELECT 1")

        let oversized = Data(
            repeating: 0x20,
            count: QueryEditorView.maximumSQLDocumentBytes + 1
        )
        #expect(throws: (any Error).self) {
            _ = try QueryEditorView.decodedSQLDocumentText(oversized)
        }
        #expect(throws: (any Error).self) {
            _ = try QueryEditorView.decodedSQLDocumentText(Data([0xFF]))
        }
    }

    @MainActor
    @Test func editorQueriesFetchSentinelRowsPreserveSQLAndDoNotBoundOtherCommands() async throws {
        let connection = try await SQLiteEngine().connect(path: ":memory:")
        defer { Task { try? await connection.close() } }
        let manager = DatabaseSessionManager(loadImmediately: false)
        let sessionID = UUID()
        let session = DatabaseSession(connectionConfig: DatabaseConnectionConfig(
            name: "Bounded SQLite",
            engine: .sqlite,
            host: ":memory:",
            port: 0,
            username: ""
        ))
        session.connection = connection
        session.engine = SQLiteEngine()
        session.state = .connected
        manager.sessions[sessionID] = session

        let original = """
        WITH sample(n) AS (VALUES (1), (2), (3), (4))
        SELECT n FROM sample ORDER BY n
        """
        let bounded = try await manager.executeQuery(
            original,
            sessionID: sessionID,
            editorRowLimit: 2
        )
        #expect(bounded.query == original)
        #expect(bounded.rows == [[.int(1)], [.int(2)]])
        #expect(bounded.appliedRowLimit == 2)
        #expect(bounded.isTruncated)
        #expect(session.queryHistory.last?.query == original)

        let complete = try await manager.executeQuery(
            "SELECT 1 AS value",
            sessionID: sessionID,
            editorRowLimit: 2
        )
        #expect(complete.rows == [[.int(1)]])
        #expect(complete.appliedRowLimit == 2)
        #expect(!complete.isTruncated)

        let utility = try await manager.executeQuery(
            "PRAGMA database_list",
            sessionID: sessionID,
            editorRowLimit: 2
        )
        #expect(utility.appliedRowLimit == nil)
        #expect(!utility.isTruncated)

        let tablePage = try await manager.executeQuery(
            "SELECT n FROM (SELECT 1 AS n UNION ALL SELECT 2 UNION ALL SELECT 3) LIMIT 2 OFFSET 1",
            sessionID: sessionID
        )
        #expect(tablePage.rowCount == 2)
        #expect(tablePage.appliedRowLimit == nil)

        await #expect(throws: (any Error).self) {
            _ = try await manager.executeQuery(
                "SELECT 1",
                sessionID: sessionID,
                editorRowLimit: 0
            )
        }
        try await connection.close()
    }
}
