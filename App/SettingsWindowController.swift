import AppKit
import SwiftUI

/// Manual settings window. We avoid SwiftUI's `Settings` scene because it
/// races with `setActivationPolicy(.accessory)` (the menu-bar-only policy
/// the app adopts in `AppDelegate`). SwiftUI's `SettingsLink` and the
/// `showSettingsWindow:` selector are unreliable in that combination — the
/// window either does not appear or appears off-screen. Owning the window
/// ourselves makes the behavior predictable.
@MainActor
final class SettingsWindowController {
    let window: NSWindow

    init(initialSize: NSSize) {
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: initialSize),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "DropThings Settings"
        window.isReleasedWhenClosed = false
        window.hidesOnDeactivate = false
        window.center()
        self.window = window
    }

    func setContent<V: View>(_ view: V) {
        window.contentView = NSHostingView(rootView: AnyView(view))
    }

    func show() {
        if window.isMiniaturized {
            window.deminiaturize(nil)
        }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func hide() {
        window.orderOut(nil)
    }
}
