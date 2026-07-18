//
//  Constants.swift
//  glassdb
//
//  Typed constants for UserDefaults keys.
//  Keychain service names are now derived from the shared GlasSecretStore configuration.
//

import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

enum UserDefaultsKeys {
    static let connections = "glassdb.connections"
    static let savedQueries = "glassdb.savedQueries"
    static let queryHistory = "glassdb.queryHistory"
    static let sshKeys = "glassdb.sshKeys"

    // Settings
    static let maxQueryHistoryItems = "glassdb.maxQueryHistoryItems"
    static let resultRowLimit = "glassdb.resultRowLimit"
    static let windowOpacity = "glassdb.windowOpacity"
    static let blurBackground = "glassdb.blurBackground"
    static let showSidebarByDefault = "glassdb.showSidebarByDefault"
    static let editorFontSize = "glassdb.editorFontSize"
    static let dataGridFontSize = "glassdb.dataGridFontSize"
    static let showLineNumbers = "glassdb.showLineNumbers"
    static let redactQueryHistoryLiterals = "glassdb.redactQueryHistoryLiterals"
}

enum KeychainServiceNames {
    private static let config = KeychainManager.config
    static var passwords: String { config.passwordsService }
    static var sshPasswords: String { config.sshPasswordsService }
    static var sshKeysPrivate: String { config.sshKeysPrivateService }
    static var sshKeysPassphrase: String { config.sshKeysPassphraseService }
    static var sealedP256: String { config.sealedP256Service }
    static var sealedP256Tag: String { config.sealedP256TagService }
}

// MARK: - Shared platform adapters

enum DatabaseSidebarLayout {
    static let minimumWidth: CGFloat = 300
    static let idealWidth: CGFloat = 340
    static let maximumWidth: CGFloat = 440
}

enum PlatformClipboard {
    static func copy(_ value: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = value
        #elseif canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
        #endif
    }
}

extension View {
    @ViewBuilder
    func databaseSidebarColumnWidth() -> some View {
        #if os(macOS)
        navigationSplitViewColumnWidth(
            min: DatabaseSidebarLayout.minimumWidth,
            ideal: DatabaseSidebarLayout.idealWidth,
            max: DatabaseSidebarLayout.maximumWidth
        )
        #else
        self
        #endif
    }

    @ViewBuilder
    func databaseLookScrollEnabled() -> some View {
        #if os(visionOS)
        scrollInputBehavior(.enabled, for: .look)
        #else
        self
        #endif
    }

    @ViewBuilder
    func databaseASCIICapableKeyboard() -> some View {
        #if canImport(UIKit)
        keyboardType(.asciiCapable)
        #else
        self
        #endif
    }

    @ViewBuilder
    func databaseNoAutocapitalization() -> some View {
        #if canImport(UIKit)
        textInputAutocapitalization(.never)
        #else
        self
        #endif
    }

    @ViewBuilder
    func databaseWorkspaceWindowBackground() -> some View {
        #if os(macOS)
        containerBackground(.clear, for: .window)
        #else
        self
        #endif
    }

    /// Keeps the schema browser in Apple-provided material while the database
    /// canvas independently follows the user's opacity and blur settings.
    func databaseWorkspaceSidebarMaterial() -> some View {
        background(.regularMaterial)
    }

    @ViewBuilder
    func databaseWorkspaceWindowChrome() -> some View {
        #if os(macOS)
        background(MacDatabaseWorkspaceWindowReader())
        #else
        self
        #endif
    }

    @ViewBuilder
    func databaseWorkspaceTabControlTarget() -> some View {
        #if os(macOS)
        frame(minWidth: 28, minHeight: 28)
        #else
        frame(minWidth: 44, minHeight: 44)
        #endif
    }

    @ViewBuilder
    func databaseSidebarChrome() -> some View {
        #if os(macOS)
        self
        #else
        toolbar(removing: .sidebarToggle)
        #endif
    }
}

#if os(macOS)
/// A non-interactive material layer for AppKit's titlebar region. It must never
/// participate in hit testing: the window's toolbar and SwiftUI content retain
/// normal pointer, keyboard, and accessibility behavior.
@MainActor
final class MacDatabaseWorkspaceTitlebarMaterialView: NSVisualEffectView {
    static let materialIdentifier = NSUserInterfaceItemIdentifier(
        "app.glassdb.workspace-titlebar-material"
    )

    weak var contentBoundary: NSView?

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}

/// Reuses the sister app's proven AppKit window-reader pattern to preserve
/// native titlebar material around a transparent SwiftUI database canvas.
struct MacDatabaseWorkspaceWindowReader: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NonHitTestingWindowReaderView(frame: .zero)
        DispatchQueue.main.async {
            MacDatabaseWorkspaceWindowPolicy.apply(view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            MacDatabaseWorkspaceWindowPolicy.apply(nsView.window)
        }
    }

    @MainActor
    private final class NonHitTestingWindowReaderView: NSView {
        override func hitTest(_ point: NSPoint) -> NSView? {
            nil
        }
    }
}

@MainActor
enum MacDatabaseWorkspaceWindowPolicy {
    static func apply(_ window: NSWindow?) {
        guard let window else { return }
        window.isOpaque = false
        window.backgroundColor = .clear
        window.titlebarAppearsTransparent = false
        window.styleMask.remove(.fullSizeContentView)
        window.ignoresMouseEvents = false
        window.isMovableByWindowBackground = false
        window.autorecalculatesKeyViewLoop = true
        installTitlebarMaterial(in: window)
    }

    private static func installTitlebarMaterial(in window: NSWindow) {
        guard let contentView = window.contentView,
              let themeFrame = contentView.superview else { return }

        if let existing = themeFrame.subviews
            .compactMap({ $0 as? MacDatabaseWorkspaceTitlebarMaterialView })
            .first(where: {
                $0.identifier == MacDatabaseWorkspaceTitlebarMaterialView.materialIdentifier
            }) {
            if existing.contentBoundary === contentView {
                return
            }
            existing.removeFromSuperview()
        }

        let materialView = MacDatabaseWorkspaceTitlebarMaterialView(frame: .zero)
        materialView.identifier = MacDatabaseWorkspaceTitlebarMaterialView.materialIdentifier
        materialView.contentBoundary = contentView
        materialView.material = .titlebar
        materialView.blendingMode = .behindWindow
        materialView.state = .followsWindowActiveState
        materialView.alphaValue = 1
        materialView.translatesAutoresizingMaskIntoConstraints = false
        themeFrame.addSubview(materialView, positioned: .below, relativeTo: nil)

        NSLayoutConstraint.activate([
            materialView.leadingAnchor.constraint(equalTo: themeFrame.leadingAnchor),
            materialView.trailingAnchor.constraint(equalTo: themeFrame.trailingAnchor),
            materialView.topAnchor.constraint(equalTo: themeFrame.topAnchor),
            materialView.bottomAnchor.constraint(equalTo: contentView.topAnchor),
        ])
    }
}
#endif

extension ToolbarContent {
    @ToolbarContentBuilder
    func databaseHighVisibilityPriority() -> some ToolbarContent {
        #if os(macOS)
        visibilityPriority(.high)
        #else
        self
        #endif
    }
}

// MARK: - Native command routing

/// Routes menu-bar commands to the editor in the focused database window.
/// Focused values prevent a command from accidentally affecting every open
/// connection window.
struct DatabaseCommandActions {
    let canExecute: Bool
    let canCancel: Bool
    let canSave: Bool
    let canCloseTab: Bool
    let executeStatement: () -> Void
    let executeScript: () -> Void
    let explainPlan: () -> Void
    let cancel: () -> Void
    let openDocument: () -> Void
    let saveDocument: () -> Void
    let showHistory: () -> Void
    let showSavedQueries: () -> Void
    let formatSQL: () -> Void
    let newTab: () -> Void
    let closeTab: () -> Void
}

struct DatabaseWorkspaceCommandActions {
    let canCloseTab: Bool
    let closeTab: () -> Void
}

private struct DatabaseCommandActionsKey: FocusedValueKey {
    typealias Value = DatabaseCommandActions
}

private struct DatabaseWorkspaceCommandActionsKey: FocusedValueKey {
    typealias Value = DatabaseWorkspaceCommandActions
}

extension FocusedValues {
    var databaseCommandActions: DatabaseCommandActions? {
        get { self[DatabaseCommandActionsKey.self] }
        set { self[DatabaseCommandActionsKey.self] = newValue }
    }


    var databaseWorkspaceCommandActions: DatabaseWorkspaceCommandActions? {
        get { self[DatabaseWorkspaceCommandActionsKey.self] }
        set { self[DatabaseWorkspaceCommandActionsKey.self] = newValue }
    }
}

#if os(macOS)
struct DatabaseCommands: Commands {
    @FocusedValue(\.databaseCommandActions) private var actions
    @FocusedValue(\.databaseWorkspaceCommandActions) private var workspaceActions

    var body: some Commands {
        CommandMenu("Query") {
            Button("Execute Statement") { actions?.executeStatement() }
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(actions?.canExecute != true)
            Button("Execute Script") { actions?.executeScript() }
                .keyboardShortcut(.return, modifiers: [.command, .shift])
                .disabled(actions?.canExecute != true)
            Button("Explain Plan") { actions?.explainPlan() }
                .keyboardShortcut("e", modifiers: [.command, .shift])
                .disabled(actions?.canExecute != true)
            Button("Cancel Query") { actions?.cancel() }
                .keyboardShortcut(".", modifiers: .command)
                .disabled(actions?.canCancel != true)

            Divider()

            Button("Open SQL Document…") { actions?.openDocument() }
                .keyboardShortcut("o", modifiers: .command)
                .disabled(actions == nil)
            Button("Save SQL Document…") { actions?.saveDocument() }
                .keyboardShortcut("s", modifiers: .command)
                .disabled(actions?.canSave != true)
            Button("Format SQL") { actions?.formatSQL() }
                .keyboardShortcut("f", modifiers: [.command, .shift])
                .disabled(actions?.canExecute != true)

            Divider()

            Button("Query History") { actions?.showHistory() }
                .disabled(actions == nil)
            Button("Saved Queries") { actions?.showSavedQueries() }
                .disabled(actions == nil)
            Button("New Query Tab") { actions?.newTab() }
                .keyboardShortcut("t", modifiers: .command)
                .disabled(actions == nil)
            Button("Close Active Tab") {
                if workspaceActions?.canCloseTab == true {
                    workspaceActions?.closeTab()
                } else {
                    actions?.closeTab()
                }
            }
                .keyboardShortcut("w", modifiers: [.command, .shift])
                .disabled(
                    workspaceActions?.canCloseTab != true
                        && actions?.canCloseTab != true
                )
        }
    }
}
#endif

#if os(macOS)
@MainActor let databaseToolbarPlacement: ToolbarItemPlacement = .automatic
@MainActor let databaseExecutionToolbarPlacement: ToolbarItemPlacement = .automatic
@MainActor let databaseTransferToolbarPlacement: ToolbarItemPlacement = .automatic
@MainActor let databaseContextToolbarPlacement: ToolbarItemPlacement = .automatic
@MainActor let databaseSidebarToolbarPlacement: ToolbarItemPlacement = .navigation
#else
@MainActor let databaseToolbarPlacement: ToolbarItemPlacement = .bottomOrnament
@MainActor let databaseExecutionToolbarPlacement: ToolbarItemPlacement = .primaryAction
@MainActor let databaseTransferToolbarPlacement: ToolbarItemPlacement = .bottomOrnament
@MainActor let databaseContextToolbarPlacement: ToolbarItemPlacement = .bottomOrnament
@MainActor let databaseSidebarToolbarPlacement: ToolbarItemPlacement = .topBarLeading
#endif

#if os(macOS)
/// Persistent workspace actions shared by every macOS database detail surface.
/// The active child places this content last so native toolbar spacers can keep
/// the group at the trailing edge without misusing modal action placements.
struct DatabasePersistentToolbar: ToolbarContent {
    let openSQL: () -> Void

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: databaseToolbarPlacement) {
            Button(action: openSQL) {
                Label("SQL Editor", systemImage: "text.page")
            }
            .help("Show the SQL editor")

            SettingsLink {
                Label("Settings", systemImage: "gearshape")
            }
            .help("Open Settings")
        }
    }
}
#endif
