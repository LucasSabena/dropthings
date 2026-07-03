import AppKit
import SwiftUI
import DropThingsCore
import DropThingsDesignSystem
import DropThingsPlatform

/// Floating panel for the Clipboard History module. Hosts the SwiftUI content
/// and remembers the app that had keyboard focus before the panel appeared,
/// so auto-paste can deliver ⌘V into that app after the panel hides.
final class ClipboardHistoryPanelController {
    private var panel: NSPanel?
    private weak var module: ClipboardHistoryModule?
    /// The frontmost app right before the panel took focus. Captured on show
    /// so we can hand focus back to it before synthesizing ⌘V.
    private var previousApp: NSRunningApplication?

    init(module: ClipboardHistoryModule) {
        self.module = module
    }

    func show() {
        if panel == nil {
            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 660, height: 460),
                styleMask: [.titled, .closable, .nonactivatingPanel, .resizable],
                backing: .buffered,
                defer: false
            )
            panel.title = "Clipboard History"
            panel.level = .floating
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            panel.isReleasedWhenClosed = false
            panel.minSize = NSSize(width: 540, height: 320)
            panel.contentView = NSHostingView(rootView: AnyView(EmptyView()))
            self.panel = panel
        }
        // Capture the app we are about to steal focus from.
        if panel?.isVisible == false {
            previousApp = NSWorkspace.shared.frontmostApplication
        }
        refreshContent()
        panel?.center()
        panel?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
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

    private func refreshContent() {
        guard let module, let panel else { return }
        let root = AnyView(
            ClipboardHistoryPanelView(module: module, onClose: { [weak self] in self?.hide() })
                .frame(minWidth: 540, minHeight: 320)
        )
        (panel.contentView as? NSHostingView<AnyView>)?.rootView = root
    }
}
