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
public final class ScrollControlModule: DropThingsModule {
    public let id = ModuleID.scrollControl
    public let name = "Scroll Control"
    public let summary = "Different scroll direction per input device."
    public let requiredPermissions: [SystemPermission] = [.accessibility]

    @Published public private(set) var state: ModuleState = .off
    @Published public private(set) var settings: ScrollSettings
    @Published public private(set) var lastError: String?
    @Published public private(set) var isPaused: Bool = false
    /// Bundle ID of the frontmost app, refreshed via `NSWorkspace`. The
    /// transformer reads this on every scroll event so per-app overrides
    /// take effect immediately when the user switches apps.
    @Published public private(set) var activeBundleID: String?
    @Published public private(set) var lastExternalBundleID: String?

    private let settingsStore: SettingsStore
    private let permissions: PermissionCenter
    private let logger = ModuleLogger(subsystem: "app.dropthings", category: "scroll-control")
    private var tap: EventTapClient?
    private var hotkey: GlobalHotkey?
    private var hotkeyHealth = HotkeyRegistrationHealth()
    private var workspaceObserver: NSObjectProtocol?
    private var tapFailureReason: String?
    private var transformer: ScrollEventTransformer

    public init(settings: SettingsStore, permissions: PermissionCenter) {
        self.settingsStore = settings
        self.permissions = permissions
        let loadedSettings = settings.loadScrollSettings()
        self.settings = loadedSettings
        self.activeBundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        self.transformer = ScrollEventTransformer(settings: loadedSettings)
        if activeBundleID != Bundle.main.bundleIdentifier {
            self.lastExternalBundleID = activeBundleID
        }
    }

    public func start() async throws {
        guard permissions.state(for: .accessibility) == .granted else {
            let missing = permissions.missing(from: requiredPermissions)
            state = .needsPermission(missing: missing)
            logger.notice("Start blocked: Accessibility not granted")
            return
        }
        startObservingFrontmostApp()
        installTap()
        registerHotkey()
        if case .failed = state { return }
        applyPauseOnLaunchIfNeeded()
        if case .degraded = state { return }
        state = .running
        logger.info("Scroll Control started")
    }

    public func stop() async {
        unregisterHotkey()
        stopObservingFrontmostApp()
        tap?.stop()
        tap = nil
        state = .off
        isPaused = false
        logger.info("Scroll Control stopped")
    }

    private func startObservingFrontmostApp() {
        guard workspaceObserver == nil else { return }
        let center = NSWorkspace.shared.notificationCenter
        workspaceObserver = center.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.activeBundleID = app.bundleIdentifier
                if app.bundleIdentifier != Bundle.main.bundleIdentifier {
                    self.lastExternalBundleID = app.bundleIdentifier
                }
            }
        }
    }

    private func stopObservingFrontmostApp() {
        if let observer = workspaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            workspaceObserver = nil
        }
    }

    /// One-tap entry point from the menu bar.
    public var primaryAction: ModulePrimaryAction? {
        ModulePrimaryAction(
            title: isPaused ? "Resume Scroll Control" : "Pause Scroll Control",
            iconName: iconName,
            action: { [weak self] in
                Task { @MainActor [weak self] in
                    self?.togglePause()
                }
            }
        )
    }

    public var commands: [CommandDescriptor] {
        [
            CommandDescriptor(
                id: "scroll-control.toggle-pause",
                title: isPaused ? "Resume Scroll Control" : "Pause Scroll Control",
                subtitle: name,
                iconName: iconName,
                action: { [weak self] in
                    Task { @MainActor [weak self] in self?.togglePause() }
                }
            )
        ]
    }

    // MARK: - Public actions

    /// Pause the event tap so scroll events pass through unmodified, or
    /// resume if already paused. No-op when the module is not running.
    public func togglePause() {
        guard state.isStarted, permissions.state(for: .accessibility) == .granted else { return }
        if isPaused {
            installTap()
            isPaused = false
            setPauseOnLaunch(false)
            logger.info("Scroll Control resumed")
        } else {
            tap?.stop()
            tap = nil
            isPaused = true
            logger.info("Scroll Control paused — events pass through unchanged")
        }
    }

    public func setPauseOnLaunch(_ value: Bool) {
        guard settings.pauseOnLaunch != value else { return }
        var new = settings
        new.pauseOnLaunch = value
        settings = new
        settingsStore.saveScrollSettings(new)
    }

    private func applyPauseOnLaunchIfNeeded() {
        guard settings.pauseOnLaunch else { return }
        tap?.stop()
        tap = nil
        isPaused = true
        logger.info("Scroll Control started paused — events pass through unchanged")
    }

    // MARK: - Settings surface

    public func updateSettings(_ newSettings: ScrollSettings) {
        let sanitized = ScrollSettings.sanitized(
            trackpadDirection: newSettings.trackpadDirection,
            mouseWheelDirection: newSettings.mouseWheelDirection,
            magicMouseDirection: newSettings.magicMouseDirection,
            horizontalScrollEnabled: newSettings.horizontalScrollEnabled,
            scrollMultiplier: newSettings.scrollMultiplier,
            hotkey: newSettings.hotkey,
            pauseOnLaunch: newSettings.pauseOnLaunch,
            appOverrides: newSettings.appOverrides
        )
        let hotkeyChanged = sanitized.hotkey != settings.hotkey
        settings = sanitized
        transformer = ScrollEventTransformer(settings: sanitized)
        settingsStore.saveScrollSettings(sanitized)
        if hotkeyChanged && state.isStarted {
            unregisterHotkey()
            registerHotkey()
        }
    }

    public func updateAppOverride(bundleID: String, direction: ScrollDirection, multiplier: Double) {
        var new = settings
        var overrides = new.appOverrides.filter { $0.bundleID != bundleID }
        overrides.append(ScrollAppOverride(bundleID: bundleID, direction: direction, multiplier: multiplier))
        new.appOverrides = overrides
        updateSettings(new)
    }

    public func removeAppOverride(bundleID: String) {
        var new = settings
        new.appOverrides.removeAll { $0.bundleID == bundleID }
        updateSettings(new)
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
        do {
            try client.start { [weak self] input in
                guard let self else { return nil }
                return self.transformer.transform(input, activeBundleID: self.activeBundleID)
            }
            tap = client
            lastError = nil
            recoverFromTapFailureIfNeeded()
        } catch {
            let message = String(describing: error)
            let reason = "Could not install event tap: \(message). Scroll events are not being modified."
            tapFailureReason = reason
            state = .degraded(reason: reason)
            lastError = message
            logger.error("Event tap install failed: \(message)")
        }
    }

    private func recoverFromTapFailureIfNeeded() {
        guard let tapFailureReason else { return }
        self.tapFailureReason = nil
        if case .degraded(let reason) = state, reason == tapFailureReason {
            state = .running
        }
    }

    // MARK: - Hotkey

    private func registerHotkey() {
        guard let definition = settings.hotkey else {
            state = hotkeyHealth.recovered(current: state)
            return
        }
        let hotkey = GlobalHotkey(definition: definition) { [weak self] in
            self?.togglePause()
        }
        do {
            try hotkey.register()
            self.hotkey = hotkey
            state = hotkeyHealth.recovered(current: state)
        } catch let error as GlobalHotkey.RegistrationError {
            let display = definition.displayString
            let reason: String
            switch error {
            case .installHandlerFailed(let status):
                reason = "Hotkey installer failed (\(status)) for \(display). Pause and resume from the menu bar instead."
            case .registerFailed(let status):
                reason = "\(display) is already taken by another app (Carbon error \(status)). Pick a different shortcut or use the menu bar."
            }
            state = hotkeyHealth.failed(reason: reason)
            logger.warning("Could not register \(display): \(error)")
        } catch {
            state = hotkeyHealth.failed(reason: "Hotkey registration failed: \(error)")
            logger.warning("Hotkey registration failed: \(error)")
        }
    }

    private func unregisterHotkey() {
        hotkey?.unregister()
        hotkey = nil
    }
}
