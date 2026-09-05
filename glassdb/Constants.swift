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

/// Connection library column metrics, mirrored from glas.sh's
/// `ConnectionLibraryMacColumnLayout` (`ConnectionManagerView.swift:16-23`) so
/// both Glass-family Connections windows open at the same proportions. These
/// are deliberately separate from `DatabaseSidebarLayout`, which measures the
/// database workspace's schema sidebar, not this window.
enum ConnectionLibraryColumnLayout {
    static let navigationMinimum: CGFloat = 240
    static let navigationIdeal: CGFloat = 340
    static let navigationMaximum: CGFloat = 480
    static let resultsMinimum: CGFloat = 320
    static let resultsIdeal: CGFloat = 510
    static let resultsMaximum: CGFloat = 760
    /// AppKit persists the user's divider positions under this name, so a
    /// resize survives relaunch. Namespaced to glassdb; glas.sh keeps its own.
    static let autosaveName = "app.glassdb.connection-library.columns"
}

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

    /// Attaches AppKit's split-view autosave so the user's own column widths
    /// replace the defaults after the first resize. Mirrors glas.sh's
    /// `MacConnectionLibrarySplitViewAutosave`.
    @ViewBuilder
    func connectionLibraryColumnAutosave() -> some View {
        #if os(macOS)
        background(MacConnectionLibrarySplitViewAutosave(
            name: ConnectionLibraryColumnLayout.autosaveName
        ))
        #else
        self
        #endif
    }

    @ViewBuilder
    func connectionLibraryNavigationColumnWidth() -> some View {
        #if os(macOS)
        navigationSplitViewColumnWidth(
            min: ConnectionLibraryColumnLayout.navigationMinimum,
            ideal: ConnectionLibraryColumnLayout.navigationIdeal,
            max: ConnectionLibraryColumnLayout.navigationMaximum
        )
        #else
        self
        #endif
    }

    @ViewBuilder
    func connectionLibraryResultsColumnWidth() -> some View {
        #if os(macOS)
        navigationSplitViewColumnWidth(
            min: ConnectionLibraryColumnLayout.resultsMinimum,
            ideal: ConnectionLibraryColumnLayout.resultsIdeal,
            max: ConnectionLibraryColumnLayout.resultsMaximum
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
    func databaseWorkspaceWindowChrome(opensSidebarInitially: Bool = true) -> some View {
        #if os(macOS)
        background(MacDatabaseWorkspaceWindowReader(opensSidebarInitially: opensSidebarInitially))
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
    private var leadingConstraint: NSLayoutConstraint?
    private weak var sidebarItem: NSSplitViewItem?
    private var sidebarObservation: NSKeyValueObservation?
    private var resizeObservation: NSObjectProtocol?

    isolated deinit {
        if let resizeObservation { NotificationCenter.default.removeObserver(resizeObservation) }
    }

    // Same passive geometry contract as glas.sh: read native layout, never
    // constrain decoration to a live sidebar or detail view.
    func followSidebarBoundary() {
        guard let contentBoundary else { return }
        var discoveredSidebar: NSSplitViewItem?
        var discoveredSplit: NSSplitView?
        var views = [contentBoundary]
        var index = 0
        while index < views.count, index < 256 {
            let view = views[index]
            index += 1
            if let split = view as? NSSplitView,
               let controller = split.delegate as? NSSplitViewController,
               let sidebar = controller.splitViewItems.first(where: { $0.behavior == .sidebar }) {
                discoveredSidebar = sidebar
                discoveredSplit = split
                break
            }
            views.append(contentsOf: view.subviews)
        }
        if sidebarItem !== discoveredSidebar {
            sidebarObservation = nil
            if let resizeObservation { NotificationCenter.default.removeObserver(resizeObservation) }
            resizeObservation = nil
            sidebarItem = discoveredSidebar
            sidebarObservation = discoveredSidebar?.observe(\.isCollapsed, options: [.new]) { [weak self] _, _ in
                MainActor.assumeIsolated { self?.updateLeadingBoundary() }
            }
            if let discoveredSplit {
                resizeObservation = NotificationCenter.default.addObserver(
                    forName: NSSplitView.didResizeSubviewsNotification,
                    object: discoveredSplit, queue: .main
                ) { [weak self] _ in
                    MainActor.assumeIsolated { self?.updateLeadingBoundary() }
                }
            }
        }
        updateLeadingBoundary()
    }

    private func updateLeadingBoundary() {
        guard let frame = superview else { return }
        var offset: CGFloat = 0
        if let sidebarItem, !sidebarItem.isCollapsed {
            let sidebar = sidebarItem.viewController.view
            offset = sidebar.convert(sidebar.bounds, to: frame).maxX - frame.bounds.minX
        }
        offset = min(max(0, offset), frame.bounds.width)
        if let leadingConstraint {
            if abs(leadingConstraint.constant - offset) > 0.1 {
                leadingConstraint.constant = offset
            }
        } else {
            leadingConstraint = leadingAnchor.constraint(equalTo: frame.leadingAnchor, constant: offset)
            leadingConstraint?.isActive = true
        }
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}

/// Reuses the sister app's proven AppKit window-reader pattern to preserve
/// native titlebar material around a transparent SwiftUI database canvas.
struct MacDatabaseWorkspaceWindowReader: NSViewRepresentable {
    var opensSidebarInitially = true

    func makeNSView(context: Context) -> NSView {
        let view = NonHitTestingWindowReaderView(frame: .zero)
        view.opensSidebarInitially = opensSidebarInitially
        view.scheduleConfiguration()
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let view = nsView as? NonHitTestingWindowReaderView else { return }
        view.opensSidebarInitially = opensSidebarInitially
        view.scheduleConfiguration()
    }

    @MainActor
    final class NonHitTestingWindowReaderView: NSView {
        var opensSidebarInitially = true
        private weak var configuredWindow: NSWindow?
        private var appliedInitialSidebar = false
        private var hasActivated = false

        deinit { NotificationCenter.default.removeObserver(self) }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let window, configuredWindow !== window {
                NotificationCenter.default.removeObserver(self)
                configuredWindow = window
                appliedInitialSidebar = false
                hasActivated = window.isKeyWindow
                NotificationCenter.default.addObserver(
                    self, selector: #selector(windowDidBecomeKey(_:)),
                    name: NSWindow.didBecomeKeyNotification, object: window
                )
            }
            scheduleConfiguration()
        }

        @objc private func windowDidBecomeKey(_ notification: Notification) {
            guard !hasActivated else { return }
            hasActivated = true
            // Wait until initial native window presentation/restoration settles.
            // Later activations never reopen a sidebar the user has hidden.
            DispatchQueue.main.async { [weak self] in self?.applyInitialSidebarIfNeeded() }
        }

        func scheduleConfiguration() {
            DispatchQueue.main.async { [weak self] in
                guard let self, let window = self.window else { return }
                MacDatabaseWorkspaceWindowPolicy.apply(window)
                self.applyInitialSidebarIfNeeded()
            }
        }

        override func layout() {
            super.layout()
            applyInitialSidebarIfNeeded()
        }

        private func applyInitialSidebarIfNeeded() {
            guard hasActivated, opensSidebarInitially, !appliedInitialSidebar,
                  let root = window?.contentView else { return }
            var views = [root]
            var index = 0
            while index < views.count, index < 256 {
                let view = views[index]
                index += 1
                if let split = view as? NSSplitView,
                   let controller = split.delegate as? NSSplitViewController,
                   let sidebar = controller.splitViewItems.first(where: { $0.behavior == .sidebar }) {
                    // One initial native action, never an update-time toolbar mutation.
                    appliedInitialSidebar = true
                    sidebar.isCollapsed = false
                    return
                }
                views.append(contentsOf: view.subviews)
            }
        }

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
        // Match glas.sh's `MacTerminalWindowPolicy` and Apple's full-height
        // sidebar windows: content extends under the toolbar, and SwiftUI's
        // NavigationSplitView places its per-column titlebar backgrounds in
        // that top band. Removing `.fullSizeContentView` pushed the split view
        // below the toolbar, so those 40pt titlebar backgrounds landed on top
        // of the workspace tab strip instead.
        // The window itself is clear, so AppKit draws no titlebar material of
        // its own; `installTitlebarMaterial` supplies it behind the band.
        window.titlebarAppearsTransparent = true
        window.styleMask.insert(.fullSizeContentView)
        window.ignoresMouseEvents = false
        window.isMovableByWindowBackground = false
        window.autorecalculatesKeyViewLoop = true
        // As in glas.sh, let the system choose toolbar style and control size.
        // The passive material must not impose compact window chrome.
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
                existing.followSidebarBoundary()
                return
            }
            existing.removeFromSuperview()
        }

        let materialView = MacDatabaseWorkspaceTitlebarMaterialView(frame: .zero)
        materialView.identifier = MacDatabaseWorkspaceTitlebarMaterialView.materialIdentifier
        materialView.contentBoundary = contentView
        materialView.material = .sidebar
        materialView.blendingMode = .behindWindow
        materialView.state = .followsWindowActiveState
        materialView.alphaValue = 1
        materialView.translatesAutoresizingMaskIntoConstraints = false
        materialView.setAccessibilityElement(false)
        themeFrame.addSubview(materialView, positioned: .below, relativeTo: nil)
        materialView.followSidebarBoundary()

        // Under `.fullSizeContentView` the content view reaches the window's
        // top edge, so the titlebar/toolbar band is the strip between the
        // frame's top and the content layout guide. Anchoring to the guide
        // keeps the material exactly that tall as the toolbar resolves its
        // height, and never lets it reach the workspace tab strip below.
        let bottomAnchor: NSLayoutYAxisAnchor
        if let layoutGuide = window.contentLayoutGuide as? NSLayoutGuide {
            bottomAnchor = layoutGuide.topAnchor
        } else {
            bottomAnchor = contentView.topAnchor
        }
        NSLayoutConstraint.activate([
            materialView.trailingAnchor.constraint(equalTo: themeFrame.trailingAnchor),
            materialView.topAnchor.constraint(equalTo: themeFrame.topAnchor),
            materialView.bottomAnchor.constraint(equalTo: bottomAnchor),
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
    let runTitle: String
    let canRunSelection: Bool
    let executeSelection: () -> Void
    let executeCurrentStatement: () -> Void
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
    let executeSelection: () -> Void
    let executeCurrentStatement: () -> Void
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
            Button(workspaceActions?.runTitle ?? "Run Statement") { workspaceActions?.executeStatement() }
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(workspaceActions?.canExecute != true)
            Button("Run Statement at Cursor") { workspaceActions?.executeCurrentStatement() }
                .disabled(workspaceActions?.canExecute != true)
            Button("Run Selection") { workspaceActions?.executeSelection() }
                .disabled(workspaceActions?.canRunSelection != true)
            Button("Run All Statements") { workspaceActions?.executeScript() }
                .keyboardShortcut(.return, modifiers: [.command, .shift])
                .disabled(workspaceActions?.canExecute != true)
            Button("Explain Plan") { workspaceActions?.explainPlan() }
                .keyboardShortcut("e", modifiers: [.command, .shift])
                .disabled(workspaceActions?.canExecute != true || workspaceActions?.canUseQueryLibrary != true)
            Button("Cancel Query") { workspaceActions?.cancel() }
                .keyboardShortcut(".", modifiers: .command)
                .disabled(workspaceActions?.canCancel != true)

            Divider()

            Button("Format SQL") { workspaceActions?.formatSQL() }
                .keyboardShortcut("f", modifiers: [.command, .shift])
                .disabled(workspaceActions?.canExecute != true || workspaceActions?.canUseQueryLibrary != true)

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

#if os(macOS)
/// Walks up to the hosting `NSSplitView` and gives it an autosave name, which
/// is what makes AppKit remember divider positions across launches. SwiftUI
/// exposes no equivalent for `NavigationSplitView`, so the attachment view is
/// invisible and never takes hit tests.
private struct MacConnectionLibrarySplitViewAutosave: NSViewRepresentable {
    let name: String

    func makeNSView(context: Context) -> AttachmentView {
        let view = AttachmentView(frame: .zero)
        view.autosaveName = name
        view.applyAutosaveName()
        return view
    }

    func updateNSView(_ nsView: AttachmentView, context: Context) {
        nsView.autosaveName = name
        nsView.applyAutosaveName()
    }

    @MainActor
    final class AttachmentView: NSView {
        var autosaveName = ""

        override func viewDidMoveToSuperview() {
            super.viewDidMoveToSuperview()
            applyAutosaveName()
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            applyAutosaveName()
        }

        /// Deferred: the split view is not in the hierarchy yet while SwiftUI
        /// is still assembling the columns.
        func applyAutosaveName() {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                var candidate = self.superview
                while let view = candidate {
                    if let splitView = view as? NSSplitView {
                        if splitView.autosaveName != self.autosaveName {
                            splitView.autosaveName = self.autosaveName
                        }
                        return
                    }
                    candidate = view.superview
                }
            }
        }

        override func hitTest(_ point: NSPoint) -> NSView? {
            nil
        }
    }
}
#endif
