import AppKit
import SwiftUI
import DropThingsCore
import DropThingsDesignSystem

/// Floating panel for the Smart Clipboard module. Hosts the SwiftUI content
/// and remembers the app that had keyboard focus before the panel appeared,
/// so optional paste-back can deliver ⌘V into that app after the panel hides.
final class SmartClipboardPanelController {
    private var panel: NSPanel?
    private weak var module: SmartClipboardModule?
    /// The frontmost app right before the panel took focus. Captured on show
    /// so paste-back can hand focus back to it.
    private var previousApp: NSRunningApplication?

    init(module: SmartClipboardModule) {
        self.module = module
    }

    var isVisible: Bool {
        panel?.isVisible ?? false
    }

    /// The kind the user has forced via "Treat As", or `nil` to use the
    /// classifier's automatic choice. Held here so the panel controller is the
    /// single source of truth the module reads back via `forcedKind`.
    private var forcedKind: SmartClipboardKind?
    private var forcedChangeCount: Int?

    func forceKind(_ kind: SmartClipboardKind?, for changeCount: Int?) {
        forcedKind = kind
        forcedChangeCount = kind == nil ? nil : changeCount
    }

    func forcedKind(for changeCount: Int) -> SmartClipboardKind? {
        guard forcedChangeCount == changeCount else { return nil }
        return forcedKind
    }

    func resetForcedKind(ifSnapshotChangedTo changeCount: Int) {
        guard forcedChangeCount != changeCount else { return }
        forcedKind = nil
        forcedChangeCount = nil
    }

    func show() {
        if panel == nil {
            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 760, height: 560),
                styleMask: [.titled, .closable, .resizable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            panel.title = "Smart Clipboard"
            panel.level = .floating
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            panel.isReleasedWhenClosed = false
            panel.minSize = NSSize(width: 560, height: 420)
            panel.contentView = NSHostingView(rootView: AnyView(EmptyView()))
            self.panel = panel
        }
        if panel?.isVisible == false {
            previousApp = NSWorkspace.shared.frontmostApplication
        }
        refreshContent()
        panel?.center()
        NSApp.activate(ignoringOtherApps: true)
        panel?.makeKeyAndOrderFront(nil)
    }

    func hide() {
        panel?.orderOut(nil)
    }

    /// Bring the previously focused app back to the front. Called right before
    /// a synthesized ⌘V so the paste lands in the user's actual target.
    func reactivatePreviousApp() {
        previousApp?.activate()
        previousApp = nil
    }

    /// Called by the module when a pasteboard change arrives and the panel is
    /// already open, so the preview stays live without re-showing the window.
    func refreshIfOpen() {
        guard isVisible else { return }
        refreshContent()
    }

    private func refreshContent() {
        guard let module, let panel else { return }
        let root = AnyView(
            SmartClipboardPanelView(module: module, controller: self)
                .frame(minWidth: 560, minHeight: 420)
        )
        (panel.contentView as? NSHostingView<AnyView>)?.rootView = root
    }
}
