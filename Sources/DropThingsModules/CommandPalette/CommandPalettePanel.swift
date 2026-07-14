import AppKit
import SwiftUI
import os
import DropThingsPlatform

@MainActor
final class CommandPalettePanelController: NSObject, NSWindowDelegate {
    private enum Layout {
        static let size = NSSize(width: 780, height: 500)
        static let minimumSize = NSSize(width: 640, height: 340)
    }

    private let coordinator: PaletteQueryCoordinator
    private let presentation = CommandPalettePresentationState()
    private var panel: NSPanel?
    private weak var previouslyKeyWindow: NSWindow?
    private var previouslyActiveApplication: NSRunningApplication?
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
        rememberFocusOwner()
        place(panel)
        panel.makeKeyAndOrderFront(nil)
        presentation.requestFocus()
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
        restoreFocusOwnerIfNeeded()
    }

    func windowWillClose(_ notification: Notification) {
        coordinator.clearActionError()
    }

    private func makePanel() -> NSPanel {
        let panel = CommandPalettePanel(
            contentRect: NSRect(origin: .zero, size: Layout.size),
            styleMask: [.borderless, .nonactivatingPanel, .resizable],
            backing: .buffered,
            defer: false
        )
        panel.title = "Command Palette"
        panel.isMovableByWindowBackground = true
        panel.becomesKeyOnlyIfNeeded = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.isReleasedWhenClosed = false
        panel.minSize = Layout.minimumSize
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.delegate = self
        let hostingView = NSHostingView(rootView: CommandPalettePanelView(
            coordinator: coordinator,
            presentation: presentation,
            onClose: { [weak self] in self?.hide() }
        ))
        hostingView.wantsLayer = true
        hostingView.layer?.cornerRadius = 18
        hostingView.layer?.cornerCurve = .continuous
        hostingView.layer?.masksToBounds = true
        panel.contentView = hostingView
        self.panel = panel
        return panel
    }

    private func rememberFocusOwner() {
        previouslyKeyWindow = NSApp.keyWindow
        let current = NSRunningApplication.current
        let frontmost = NSWorkspace.shared.frontmostApplication
        previouslyActiveApplication = frontmost?.processIdentifier == current.processIdentifier ? nil : frontmost
    }

    private func restoreFocusOwnerIfNeeded() {
        if let previouslyKeyWindow, previouslyKeyWindow.isVisible {
            previouslyKeyWindow.makeKey()
        }
        guard NSApp.isActive, let application = previouslyActiveApplication else { return }
        application.activate(options: [])
        previouslyActiveApplication = nil
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

@MainActor
final class CommandPalettePresentationState: ObservableObject {
    @Published private(set) var focusRequest = 0
    func requestFocus() { focusRequest &+= 1 }
}

/// A non-activating panel can become key without making DropThings the active
/// application. That gives the search field keyboard focus while preserving
/// the front app's responder chain for when the panel disappears.
private final class CommandPalettePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
