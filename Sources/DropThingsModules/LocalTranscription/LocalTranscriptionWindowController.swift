import AppKit
import SwiftUI

@MainActor
final class LocalTranscriptionWindowController: NSObject, NSWindowDelegate {
    private weak var module: LocalTranscriptionModule?
    private var window: NSWindow?

    init(module: LocalTranscriptionModule) {
        self.module = module
    }

    func show() {
        if window == nil { makeWindow() }
        window?.center()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func hide() {
        window?.orderOut(nil)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard module?.isProcessing == true else { return true }
        let alert = NSAlert()
        alert.messageText = "A transcription is still running."
        alert.informativeText = "You can keep it running in the background or cancel the active file."
        alert.addButton(withTitle: "Keep Running")
        alert.addButton(withTitle: "Cancel and Close")
        if alert.runModal() == .alertSecondButtonReturn {
            module?.cancelActiveJob()
            return true
        }
        return true
    }

    private func makeWindow() {
        guard let module else { return }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 880, height: 620),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Local Transcription"
        window.contentMinSize = NSSize(width: 680, height: 480)
        window.isReleasedWhenClosed = false
        window.setFrameAutosaveName("app.dropthings.local-transcription.window")
        window.delegate = self
        window.contentViewController = NSHostingController(rootView: LocalTranscriptionWorkspaceView(module: module))
        self.window = window
    }
}
