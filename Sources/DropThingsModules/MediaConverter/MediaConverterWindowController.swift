import AppKit
import SwiftUI

@MainActor
final class MediaConverterWindowController: NSObject, NSWindowDelegate {
    private weak var module: MediaConverterModule?
    private var window: NSWindow?

    init(module: MediaConverterModule) {
        self.module = module
    }

    func show() {
        guard let module else { return }
        if window == nil {
            let content = ScrollView {
                MediaConverterSettingsView(module: module)
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 780, height: 680),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.title = "Media Converter — Beta"
            window.minSize = NSSize(width: 620, height: 520)
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: content)
            window.delegate = self
            self.window = window
        }
        window?.center()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func hide() {
        window?.orderOut(nil)
    }
}
