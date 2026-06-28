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
    @Published public private(set) var isPaused: Bool = false

    private let settingsStore: SettingsStore
    private let permissions: PermissionCenter
    private let logger = ModuleLogger(subsystem: "app.dropthings", category: "scroll-control")
    private var tap: EventTapClient?
    private var hotkey: GlobalHotkey?

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
        installTap()
        registerHotkey()
        if case .failed = state { return }
        state = .running
        logger.info("Scroll Control started")
    }

    public func stop() async {
        unregisterHotkey()
        tap?.stop()
        tap = nil
        state = .off
        isPaused = false
        logger.info("Scroll Control stopped")
    }

    // MARK: - Public actions

    /// Pause the event tap so scroll events pass through unmodified, or
    /// resume if already paused. No-op when the module is not running.
    public func togglePause() {
        guard state == .running else { return }
        if isPaused {
            installTap()
            isPaused = false
            logger.info("Scroll Control resumed")
        } else {
            tap?.stop()
            tap = nil
            isPaused = true
            logger.info("Scroll Control paused — events pass through unchanged")
        }
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
        let hotkeyChanged = sanitized.hotkey != settings.hotkey
        settings = sanitized
        settingsStore.saveScrollSettings(sanitized)
        if hotkeyChanged && state == .running {
            unregisterHotkey()
            registerHotkey()
        }
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

    private func installTap() {
        let client = EventTapClient()
        let transformer = ScrollEventTransformer(settings: settings)
        do {
            try client.start { input in
                transformer.transform(input)
            }
            tap = client
            lastError = nil
        } catch {
            let message = String(describing: error)
            state = .degraded(reason: "Could not install event tap: \(message). Scroll events are not being modified.")
            lastError = message
            logger.error("Event tap install failed: \(message)")
        }
    }

    // MARK: - Hotkey

    private func registerHotkey() {
        guard let definition = settings.hotkey else { return }
        let hotkey = GlobalHotkey(definition: definition) { [weak self] in
            self?.togglePause()
        }
        do {
            try hotkey.register()
            self.hotkey = hotkey
        } catch let error as GlobalHotkey.RegistrationError {
            let display = definition.displayString
            switch error {
            case .installHandlerFailed(let status):
                logger.warning("Could not install hotkey handler for \(display) (\(status))")
            case .registerFailed(let status):
                logger.warning("Could not register hotkey \(display) (Carbon error \(status)). Toggle from the menu bar instead.")
            }
        } catch {
            logger.warning("Hotkey registration failed: \(error)")
        }
    }

    private func unregisterHotkey() {
        hotkey?.unregister()
        hotkey = nil
    }
}
