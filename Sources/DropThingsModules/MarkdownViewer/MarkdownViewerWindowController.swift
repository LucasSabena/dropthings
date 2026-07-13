import AppKit
import SwiftUI
import DropThingsCore
import DropThingsDesignSystem

/// Owns the single viewer window. The window is created lazily on first
/// `show` and reused afterwards: bringing the module to the front via the
/// hotkey or the menu-bar action reuses the existing window and document.
@MainActor
final class MarkdownViewerWindowController {
    private var window: NSWindow?
    private var hostingController: NSHostingController<MarkdownViewerRootView>?

    /// A stable size token so the window persists its frame between opens
    /// within a single app session (full state persistence is v2).
    private let defaultSize = NSSize(width: DTSize.markdownViewerWidth, height: DTSize.markdownViewerHeight)

    var isWindowVisible: Bool { window?.isVisible ?? false }

    /// Show the window with the supplied document and settings. The document
    /// is owned by the module; the window just observes it.
    func show(document: MarkdownDocument, settings: MarkdownViewerSettings, module: MarkdownViewerModule) {
        if window == nil {
            makeWindow(document: document, settings: settings, module: module)
        } else {
            updateRoot(document: document, settings: settings, module: module)
        }
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func hide() {
        window?.orderOut(nil)
    }

    /// Rebuild the hosted root view and title from the module's current
    /// active document and settings. Called after tab switches, opens,
    /// closes, and settings changes so the window always reflects the
    /// module's published state.
    func refresh(module: MarkdownViewerModule) {
        let document = module.currentDocument
        let settings = module.viewerSettings
        updateRoot(document: document, settings: settings, module: module)
        window?.title = document.displayName
    }

    /// Apply new settings (theme/font/layout) without rebuilding the window.
    func updateSettings(_ settings: MarkdownViewerSettings, module: MarkdownViewerModule) {
        updateRoot(document: module.currentDocument, settings: settings, module: module)
        window?.title = module.currentDocument.displayName
    }

    private func makeWindow(document: MarkdownDocument, settings: MarkdownViewerSettings, module: MarkdownViewerModule) {
        let rect = NSRect(origin: .zero, size: defaultSize)
        let window = NSWindow(
            contentRect: rect,
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = document.displayName
        window.titlebarAppearsTransparent = false
        window.titleVisibility = .visible
        window.isReleasedWhenClosed = false
        window.setFrameAutosaveName("app.dropthings.markdown-viewer.window")
        window.contentMinSize = NSSize(width: 480, height: 360)

        let root = MarkdownViewerRootView(document: document, settings: settings, module: module)
        let hosting = NSHostingController(rootView: root)
        window.contentViewController = hosting
        window.isMovableByWindowBackground = true
        self.window = window
        self.hostingController = hosting
    }

    private func updateRoot(document: MarkdownDocument, settings: MarkdownViewerSettings, module: MarkdownViewerModule) {
        let root = MarkdownViewerRootView(document: document, settings: settings, module: module)
        hostingController?.rootView = root
        window?.title = document.displayName
    }
}
