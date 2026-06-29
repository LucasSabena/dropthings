import AppKit
import Combine
import SwiftUI
import DropThingsCore
import DropThingsDesignSystem
import DropThingsPlatform
import os

/// Snaps the frontmost window to halves, quarters, or fullscreen using a
/// global hotkey. Uses Accessibility APIs to read and write the focused
/// window's frame.
public final class WindowSnapModule: DropThingsModule, ObservableObject {
    public let id = ModuleID.windowSnap
    public let name = "WindowSnap"
    public let summary = "Snap the frontmost window with keyboard shortcuts."
    public let requiredPermissions: [SystemPermission] = [.accessibility]

    @Published public private(set) var state: ModuleState = .off
    @Published public private(set) var settings: WindowSnapSettings
    @Published public private(set) var lastError: String?

    private let settingsStore: SettingsStore
    private let permissions: PermissionCenter
    private let snapper: WindowSnapperProtocol
    private let logger = ModuleLogger(subsystem: "app.dropthings", category: "window-snap")
    private var hotkeys: [GlobalHotkey] = []

    public init(
        settings: SettingsStore,
        permissions: PermissionCenter,
        snapper: WindowSnapperProtocol = WindowSnapper()
    ) {
        self.settingsStore = settings
        self.permissions = permissions
        self.snapper = snapper
        self.settings = settings.loadWindowSnapSettings()
    }

    public func start() async throws {
        guard permissions.state(for: .accessibility) == .granted else {
            let missing = permissions.missing(from: requiredPermissions)
            state = .needsPermission(missing: missing)
            logger.notice("Start blocked: Accessibility not granted")
            return
        }
        registerHotkeys()
        if case .degraded = state { return }
        state = .running
        logger.info("WindowSnap started")
    }

    public func stop() async {
        unregisterHotkeys()
        state = .off
        lastError = nil
        logger.info("WindowSnap stopped")
    }

    // MARK: - Public actions

    public func snap(_ action: WindowSnapAction) {
        guard state == .running else { return }
        let result = snapper.snap(action)
        switch result {
        case .success:
            lastError = nil
            logger.info("Snapped window: \(action.displayName)")
        case .failure(let error):
            let message = error.localizedDescription
            lastError = message
            logger.warning("Snap failed for \(action.displayName): \(message)")
            if error == .accessibilityDenied {
                state = .needsPermission(missing: [.accessibility])
            }
        }
    }

    public var windowSnapSettings: WindowSnapSettings { settings }

    public func setHotkey(_ action: WindowSnapAction, _ hotkey: GlobalHotkey.Definition?) {
        var new = settings
        new.setHotkey(hotkey, for: action)
        applySettings(new)
    }

    // MARK: - Settings surface

    public func makeSettingsView() -> AnyView {
        AnyView(WindowSnapSettingsView(module: self))
    }

    private func applySettings(_ new: WindowSnapSettings) {
        settings = new
        settingsStore.saveWindowSnapSettings(new)
        if state.isStarted {
            unregisterHotkeys()
            registerHotkeys()
        }
    }

    // MARK: - Hotkeys

    private func registerHotkeys() {
        var registered: [GlobalHotkey] = []
        for action in WindowSnapAction.allCases {
            guard let definition = settings.hotkey(for: action) else { continue }
            let hotkey = GlobalHotkey(definition: definition) { [weak self] in
                self?.snap(action)
            }
            do {
                try hotkey.register()
                registered.append(hotkey)
            } catch let error as GlobalHotkey.RegistrationError {
                let display = definition.displayString
                switch error {
                case .installHandlerFailed(let status):
                    state = .degraded(reason: "Could not install hotkey handler for \(display) (\(status)).")
                case .registerFailed(let status):
                    state = .degraded(reason: "\(display) is already taken (Carbon error \(status)). Pick a different shortcut.")
                }
                logger.warning("Could not register \(display): \(error)")
            } catch {
                state = .degraded(reason: "Hotkey registration failed: \(error)")
                logger.warning("Hotkey registration failed: \(error)")
            }
        }
        self.hotkeys = registered
    }

    private func unregisterHotkeys() {
        hotkeys.forEach { $0.unregister() }
        hotkeys = []
    }
}
