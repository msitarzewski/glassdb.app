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
    static let autoFormatJSONInRecordEditor = "glassdb.autoFormatJSONInRecordEditor"
    static let redactQueryHistoryLiterals = "glassdb.redactQueryHistoryLiterals"
    static let queryFailureNotificationPreference = "glassdb.queryFailureNotificationPreference"
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

/// Canonical independent levels for database-canvas paint and passthrough
/// blur. Foreground content never inherits either value.
struct DatabaseGlassAppearance: Equatable, Sendable {
    let opacity: Double
    let blur: Double

    init(opacity: Double, blur: Double) {
        self.opacity = Self.unitValue(opacity)
        self.blur = Self.unitValue(blur)
    }

    var paintsCanvas: Bool { opacity > 0 }
    var compositesBlur: Bool { blur > 0 }
    var isFullyTransparent: Bool { !paintsCanvas && !compositesBlur }

    func surfaceAlpha(strength: Double = 0.06) -> Double {
        opacity * Self.unitValue(strength)
    }

    /// Pinned content must occlude scrolling text while preserving the exact
    /// transparent and opaque endpoints selected by the user.
    var pinnedSurfaceAlpha: Double {
        sqrt(opacity)
    }

    /// visionOS composites its database canvas with a SwiftUI material rather
    /// than AppKit's behind-window effect. Strengthen that local material under
    /// pinned grid chrome so scrolling values cannot visually merge with it.
    var pinnedBlurAlpha: Double {
        sqrt(blur)
    }

    private static func unitValue(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        return min(1, max(0, value))
    }
}

enum DatabaseCanvasPalette {
    @MainActor
    static var background: Color {
        #if canImport(AppKit)
        Color(nsColor: .textBackgroundColor)
        #else
        Color(uiColor: .systemBackground)
        #endif
    }
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

    /// Registers a window-scoped Command-W action with the macOS application
    /// dispatcher. The registration remains present while disabled so a
    /// database workspace never falls through to native Close Window.
    @ViewBuilder
    func databaseCommandWTarget(
        priority: DatabaseCommandWTargetPriority,
        isEnabled: Bool,
        perform action: @escaping @MainActor () -> Void
    ) -> some View {
        #if os(macOS)
        background {
            MacDatabaseCommandWTarget(
                priority: priority.rawValue,
                isEnabled: isEnabled,
                action: action
            )
        }
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

    /// Structural contrast inside the live database canvas. Scaling by the
    /// user's paint opacity guarantees the surface disappears at 0%.
    func databaseCanvasSurface(opacity: Double, strength: Double = 0.06) -> some View {
        let alpha = DatabaseGlassAppearance(opacity: opacity, blur: 0)
            .surfaceAlpha(strength: strength)
        return background(Color.primary.opacity(alpha))
    }

    /// Appearance-aware backing for headers that remain fixed while database
    /// rows scroll beneath them. This intentionally strengthens intermediate
    /// values while still disappearing when both workspace controls are 0%.
    @ViewBuilder
    func databaseCanvasPinnedSurface(opacity: Double, blur: Double) -> some View {
        let appearance = DatabaseGlassAppearance(opacity: opacity, blur: blur)
        #if os(visionOS)
        background {
            ZStack {
                if appearance.compositesBlur {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .opacity(appearance.pinnedBlurAlpha)
                }
                Rectangle()
                    .fill(DatabaseCanvasPalette.background)
                    .opacity(appearance.pinnedSurfaceAlpha)
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
        #else
        background(DatabaseCanvasPalette.background.opacity(appearance.pinnedSurfaceAlpha))
        #endif
    }
}

enum DatabaseCommandWTargetPriority: Int {
    case workspace = 100
}

#if os(macOS)
@MainActor
final class MacDatabaseCommandWRouter: NSObject, NSMenuItemValidation {
    static let shared = MacDatabaseCommandWRouter()

    private static let semanticModifiers: NSEvent.ModifierFlags = [
        .command,
        .option,
        .control,
        .shift,
    ]

    private final class Registration {
        weak var window: NSWindow?
        var priority: Int
        var isEnabled: Bool
        var action: @MainActor () -> Void

        init(
            window: NSWindow?,
            priority: Int,
            isEnabled: Bool,
            action: @escaping @MainActor () -> Void
        ) {
            self.window = window
            self.priority = priority
            self.isEnabled = isEnabled
            self.action = action
        }
    }

    private var registrations: [UUID: Registration] = [:]

    /// SwiftUI's macOS lifecycle owns the application object, so the reliable
    /// interception point is the File menu command that AppKit invokes for both
    /// its Command-W key equivalent and a direct menu selection.
    func installCloseCommandInterceptor(in mainMenu: NSMenu? = NSApp.mainMenu) {
        guard let closeItem = mainMenu.flatMap(Self.commandWItem) else { return }
        closeItem.target = self
        closeItem.action = #selector(performCloseCommand(_:))
    }

    func update(
        id: UUID,
        window: NSWindow?,
        priority: Int,
        isEnabled: Bool,
        action: @escaping @MainActor () -> Void
    ) {
        if let registration = registrations[id] {
            registration.window = window
            registration.priority = priority
            registration.isEnabled = isEnabled
            registration.action = action
        } else {
            registrations[id] = Registration(
                window: window,
                priority: priority,
                isEnabled: isEnabled,
                action: action
            )
        }
        installCloseCommandInterceptor()
    }

    func remove(id: UUID) {
        registrations[id] = nil
    }

    /// Returns true when the target window belongs to a database workspace.
    /// Even with no enabled editor action, consuming Close prevents the
    /// permanent Overview/SQL workspace from being closed accidentally.
    func routeClose(targetWindow: NSWindow?) -> Bool {
        guard let targetWindow else { return false }
        registrations = registrations.filter { $0.value.window != nil }
        let windowRegistrations = registrations.values.filter {
            $0.window === targetWindow
        }
        guard !windowRegistrations.isEmpty else { return false }

        let action = windowRegistrations
            .filter(\.isEnabled)
            .max { $0.priority < $1.priority }?
            .action
        action?()
        return true
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        menuItem.action != #selector(performCloseCommand(_:))
            || NSApp.keyWindow != nil
    }

    @objc private func performCloseCommand(_ sender: NSMenuItem) {
        guard NSApp.currentEvent?.isARepeat != true else { return }
        let targetWindow = NSApp.keyWindow ?? NSApp.mainWindow
        guard !routeClose(targetWindow: targetWindow) else { return }
        targetWindow?.performClose(sender)
    }

    private static func commandWItem(in mainMenu: NSMenu) -> NSMenuItem? {
        mainMenu.items
            .compactMap(\.submenu)
            .flatMap(\.items)
            .first { item in
                item.keyEquivalent.lowercased() == "w"
                    && item.keyEquivalentModifierMask
                        .intersection(semanticModifiers) == .command
                    && !item.isAlternate
            }
    }
}

struct MacDatabaseCommandWTarget: NSViewRepresentable {
    let priority: Int
    let isEnabled: Bool
    let action: @MainActor () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> WindowReaderView {
        let view = WindowReaderView(frame: .zero)
        view.windowDidChange = { [weak coordinator = context.coordinator] window in
            coordinator?.attach(to: window)
        }
        context.coordinator.update(
            priority: priority,
            isEnabled: isEnabled,
            action: action
        )
        return view
    }

    func updateNSView(_ nsView: WindowReaderView, context: Context) {
        context.coordinator.update(
            priority: priority,
            isEnabled: isEnabled,
            action: action
        )
        context.coordinator.attach(to: nsView.window)
    }

    static func dismantleNSView(_ nsView: WindowReaderView, coordinator: Coordinator) {
        nsView.windowDidChange = nil
        coordinator.removeRegistration()
    }

    @MainActor
    final class Coordinator {
        private let id = UUID()
        private weak var window: NSWindow?
        private var priority = 0
        private var isEnabled = false
        private var action: @MainActor () -> Void = {}

        func attach(to window: NSWindow?) {
            self.window = window
            publish()
        }

        func update(
            priority: Int,
            isEnabled: Bool,
            action: @escaping @MainActor () -> Void
        ) {
            self.priority = priority
            self.isEnabled = isEnabled
            self.action = action
            publish()
        }

        func removeRegistration() {
            MacDatabaseCommandWRouter.shared.remove(id: id)
        }

        private func publish() {
            MacDatabaseCommandWRouter.shared.update(
                id: id,
                window: window,
                priority: priority,
                isEnabled: isEnabled,
                action: action
            )
        }
    }

    @MainActor
    final class WindowReaderView: NSView {
        var windowDidChange: ((NSWindow?) -> Void)?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            windowDidChange?(window)
        }

        override func hitTest(_ point: NSPoint) -> NSView? {
            nil
        }
    }
}

/// Uses AppKit's behind-window compositor without changing the opacity of SQL,
/// grid text, selection, or toolbar content.
struct MacDatabaseCanvasVisualEffect: NSViewRepresentable {
    let amount: Double

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView(frame: .zero)
        view.blendingMode = .behindWindow
        view.material = .underWindowBackground
        view.state = .active
        view.wantsLayer = true
        view.alphaValue = DatabaseGlassAppearance(opacity: 0, blur: amount).blur
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = .underWindowBackground
        nsView.state = .active
        nsView.alphaValue = DatabaseGlassAppearance(opacity: 0, blur: amount).blur
    }
}

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
        window.toolbarStyle = .unifiedCompact
        // SwiftUI's unifiedCompact style can still resolve to regular-height
        // Liquid Glass controls on macOS 27. Keep workspace toolbar items in the
        // compact native row without changing control sizes inside the canvas.
        window.toolbar?.sizeMode = .small
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
        #elseif os(iOS)
        if #available(iOS 27.0, *) {
            visibilityPriority(.high)
        } else {
            self
        }
        #else
        self
        #endif
    }
}

// MARK: - Native command routing

/// Routes menu-bar commands to the focused database workspace. The workspace
/// is the single publisher of this value: every SQL tab stays alive hidden in
/// the workspace ZStack, and competing `focusedSceneValue` publishers resolve
/// focus-dependently, so per-editor publication goes dead as soon as a second
/// editor exists. Enablement flags are computed from workspace-owned document
/// state; editor-internal verbs delegate to the active tab's registered
/// `QueryEditorCommandHandlers`.
struct DatabaseWorkspaceCommandActions {
    let canExecute: Bool
    let canCancel: Bool
    let canSave: Bool
    let canUseQueryLibrary: Bool
    let canCloseTab: Bool
    let newQueryTab: () -> Void
    let closeTab: () -> Void
    let openDocument: () -> Void
    let saveDocument: () -> Void
    let executeStatement: () -> Void
    let executeScript: () -> Void
    let explainPlan: () -> Void
    let cancel: () -> Void
    let formatSQL: () -> Void
    let showHistory: () -> Void
    let showSavedQueries: () -> Void
}

/// Verbs only an individual SQL editor can perform (execution pipeline and
/// its presentation sheets). Each editor registers one bundle with its owning
/// workspace for its whole lifetime, keyed by document id; the workspace
/// consults only the active tab's bundle. Closures capture `@State` and
/// `@Binding` storage, so a single registration stays current.
struct QueryEditorCommandHandlers {
    let executeStatement: () -> Void
    let executeScript: () -> Void
    let explainPlan: () -> Void
    let cancel: () -> Void
    let showHistory: () -> Void
    let showSavedQueries: () -> Void
}

private struct DatabaseWorkspaceCommandActionsKey: FocusedValueKey {
    typealias Value = DatabaseWorkspaceCommandActions
}

extension FocusedValues {
    var databaseWorkspaceCommandActions: DatabaseWorkspaceCommandActions? {
        get { self[DatabaseWorkspaceCommandActionsKey.self] }
        set { self[DatabaseWorkspaceCommandActionsKey.self] = newValue }
    }
}

#if os(macOS)
struct DatabaseCommands: Commands {
    @FocusedValue(\.databaseWorkspaceCommandActions) private var workspaceActions
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        // File owns the SQL document lifecycle per the macOS HIG. Replacing
        // .newItem removes the system-generated "New Connections Window ⌘N"
        // for the primary WindowGroup, which otherwise captures ⌘N before the
        // Query menu can see it.
        CommandGroup(replacing: .newItem) {
            Button("New SQL Document") { workspaceActions?.newQueryTab() }
                .keyboardShortcut("n", modifiers: .command)
                .disabled(workspaceActions == nil)
            Button("New Connections Window") { openWindow(id: "main") }
                .keyboardShortcut("n", modifiers: [.command, .shift])
        }
        CommandGroup(after: .newItem) {
            Button("Open SQL Document…") { workspaceActions?.openDocument() }
                .keyboardShortcut("o", modifiers: .command)
                .disabled(workspaceActions == nil)

            Divider()

            Button("Close Active Tab") { workspaceActions?.closeTab() }
                .keyboardShortcut("w", modifiers: [.command, .shift])
                .disabled(workspaceActions?.canCloseTab != true)
            Button("Save SQL Document…") { workspaceActions?.saveDocument() }
                .keyboardShortcut("s", modifiers: .command)
                .disabled(workspaceActions?.canSave != true)
        }

        CommandMenu("Query") {
            Button("Execute Statement") { workspaceActions?.executeStatement() }
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(workspaceActions?.canExecute != true)
            Button("Execute Script") { workspaceActions?.executeScript() }
                .keyboardShortcut(.return, modifiers: [.command, .shift])
                .disabled(workspaceActions?.canExecute != true)
            Button("Explain Plan") { workspaceActions?.explainPlan() }
                .keyboardShortcut("e", modifiers: [.command, .shift])
                .disabled(workspaceActions?.canExecute != true)
            Button("Cancel Query") { workspaceActions?.cancel() }
                .keyboardShortcut(".", modifiers: .command)
                .disabled(workspaceActions?.canCancel != true)

            Divider()

            Button("Format SQL") { workspaceActions?.formatSQL() }
                .keyboardShortcut("f", modifiers: [.command, .shift])
                .disabled(workspaceActions?.canExecute != true)

            Divider()

            Button("Query History") { workspaceActions?.showHistory() }
                .disabled(workspaceActions?.canUseQueryLibrary != true)
            Button("Saved Queries") { workspaceActions?.showSavedQueries() }
                .disabled(workspaceActions?.canUseQueryLibrary != true)
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
#elseif os(iOS)
@MainActor let databaseToolbarPlacement: ToolbarItemPlacement = .bottomBar
@MainActor let databaseExecutionToolbarPlacement: ToolbarItemPlacement = .primaryAction
@MainActor let databaseTransferToolbarPlacement: ToolbarItemPlacement = .bottomBar
@MainActor let databaseContextToolbarPlacement: ToolbarItemPlacement = .bottomBar
@MainActor let databaseSidebarToolbarPlacement: ToolbarItemPlacement = .topBarLeading
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
