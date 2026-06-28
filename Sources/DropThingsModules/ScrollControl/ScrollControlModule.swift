import AppKit
import Combine
import SwiftUI
import DropThingsCore
import DropThingsDesignSystem
import DropThingsPlatform
import os

/// Splits natural scrolling on the trackpad from inverted scrolling on a
/// mouse wheel so a MacBook user can plug in a mouse without losing the
/// Windows-style wheel feel. Backed by a `CGEventTap` on scroll events.
public final class ScrollControlModule: DropThingsModule, ObservableObject {
    public let id = ModuleID.scrollControl
    public let name = "Scroll Control"
    public let summary = "Different scroll direction per input device."
    public let requiredPermissions: [SystemPermission] = [.accessibility]

    @Published public private(set) var state: ModuleState = .off
    @Published public private(set) var settings: ScrollSettings
    @Published public private(set) var lastError: String?

    private let settingsStore: SettingsStore
    private let permissions: PermissionCenter
    private let logger = ModuleLogger(subsystem: "app.dropthings", category: "scroll-control")
    private var tap: EventTapClient?
    private var transformer: ScrollEventTransformer {
        ScrollEventTransformer(settings: settings)
    }

    public init(settings: SettingsStore, permissions: PermissionCenter) {
        self.settingsStore = settings
        self.permissions = permissions
        self.settings = settings.loadScrollSettings()
    }

    public func start() async throws {
        guard permissions.state(for: .accessibility) == .granted else {
            let missing = permissions.missing(from: requiredPermissions)
            state = .needsPermission(missing: missing)
            logger.notice("Start blocked: Accessibility not granted")
            return
        }
        do {
            try installTap()
            state = .running
            lastError = nil
            logger.info("Scroll Control started")
        } catch {
            let message = String(describing: error)
            state = .failed(reason: message, recovery: "Disable and re-enable the module.")
            lastError = message
            logger.error("Scroll Control failed to start: \(message)")
        }
    }

    public func stop() async {
        tap?.stop()
        tap = nil
        state = .off
        logger.info("Scroll Control stopped")
    }

    // MARK: - Settings surface

    public func updateSettings(_ newSettings: ScrollSettings) {
        let sanitized = ScrollSettings.sanitized(
            trackpadDirection: newSettings.trackpadDirection,
            mouseWheelDirection: newSettings.mouseWheelDirection,
            magicMouseDirection: newSettings.magicMouseDirection,
            horizontalScrollEnabled: newSettings.horizontalScrollEnabled,
            scrollMultiplier: newSettings.scrollMultiplier,
            hotkey: newSettings.hotkey
        )
        settings = sanitized
        settingsStore.saveScrollSettings(sanitized)
    }

    public func updateTrackpadDirection(_ direction: ScrollDirection) {
        var new = settings
        new.trackpadDirection = direction
        updateSettings(new)
    }

    public func updateMouseWheelDirection(_ direction: ScrollDirection) {
        var new = settings
        new.mouseWheelDirection = direction
        updateSettings(new)
    }

    public func updateMagicMouseDirection(_ direction: ScrollDirection) {
        var new = settings
        new.magicMouseDirection = direction
        updateSettings(new)
    }

    public func updateHorizontalScrollEnabled(_ enabled: Bool) {
        var new = settings
        new.horizontalScrollEnabled = enabled
        updateSettings(new)
    }

    public func updateScrollMultiplier(_ multiplier: Double) {
        var new = settings
        new.scrollMultiplier = multiplier
        updateSettings(new)
    }

    public func setHotkey(_ hotkey: GlobalHotkey.Definition?) {
        var new = settings
        new.hotkey = hotkey
        updateSettings(new)
    }

    public var scrollSettings: ScrollSettings { settings }

    // MARK: - SwiftUI surface

    public func makeSettingsView() -> AnyView {
        AnyView(ScrollControlSettingsView(module: self))
    }

    // MARK: - Tap wiring

    private func installTap() throws {
        let client = EventTapClient()
        let transformer = self.transformer
        try client.start { input in
            transformer.transform(input)
        }
        tap = client
    }
}
