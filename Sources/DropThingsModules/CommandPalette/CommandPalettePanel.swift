import AppKit
import SwiftUI
import os
import DropThingsPlatform

@MainActor
final class CommandPalettePanelController: NSObject, NSWindowDelegate {
    private enum Layout {
        static let size = NSSize(width: 680, height: 480)
        static let minimumSize = NSSize(width: 520, height: 320)
    }

    private let coordinator: PaletteQueryCoordinator
    private var panel: NSPanel?
    private var screenObserver: NSObjectProtocol?
    private let performanceLog = OSLog(subsystem: "app.dropthings", category: "command-palette-performance")

    init(coordinator: PaletteQueryCoordinator) {
        self.coordinator = coordinator
        super.init()
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, let panel = self.panel, panel.isVisible else { return }
                self.place(panel)
            }
        }
    }

    deinit {
        if let screenObserver { NotificationCenter.default.removeObserver(screenObserver) }
    }

    var isVisible: Bool { panel?.isVisible ?? false }

    func show() {
        let startedAt = DispatchTime.now().uptimeNanoseconds
        let panel = panel ?? makePanel()
        place(panel)
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        let elapsedMilliseconds = Double(DispatchTime.now().uptimeNanoseconds - startedAt) / 1_000_000
        os_signpost(
            .event,
            log: performanceLog,
            name: "Panel Visible",
            "duration_ms=%{public}.3f",
            elapsedMilliseconds
        )
    }

    func hide() {
        panel?.orderOut(nil)
    }

    func windowWillClose(_ notification: Notification) {
        coordinator.clearActionError()
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: Layout.size),
            styleMask: [.titled, .fullSizeContentView, .resizable],
            backing: .buffered,
            defer: false
        )
        panel.title = "Command Palette"
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.isReleasedWhenClosed = false
        panel.minSize = Layout.minimumSize
        panel.backgroundColor = .windowBackgroundColor
        panel.delegate = self
        panel.contentView = NSHostingView(rootView: CommandPalettePanelView(
            coordinator: coordinator,
            onClose: { [weak self] in self?.hide() }
        ))
        self.panel = panel
        return panel
    }

    private func place(_ panel: NSPanel) {
        let screens = NSScreen.screens.map { screen in
            PaletteDisplayGeometry(id: Self.id(for: screen), frame: screen.frame, visibleFrame: screen.visibleFrame)
        }
        let fallback = NSApp.keyWindow?.screen ?? NSApp.mainWindow?.screen
        guard let target = PaletteScreenPlacement.targetDisplay(
            mouseLocation: NSEvent.mouseLocation,
            displays: screens,
            fallbackID: fallback.map(Self.id(for:))
        ) else { return }
        let origin = PaletteScreenPlacement.panelOrigin(size: panel.frame.size, visibleFrame: target.visibleFrame)
        panel.setFrameOrigin(origin)
    }

    private static func id(for screen: NSScreen) -> String {
        if let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber {
            return number.stringValue
        }
        return "\(screen.frame.origin.x):\(screen.frame.origin.y):\(screen.frame.width)x\(screen.frame.height)"
    }
}
