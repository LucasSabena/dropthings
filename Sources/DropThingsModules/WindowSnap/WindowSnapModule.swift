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
public final class WindowSnapModule: DropThingsModule {
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
    private var hotkeyHealth = HotkeyRegistrationHealth()

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
        guard state.isStarted,
              permissions.state(for: .accessibility) == .granted else { return }
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

    public var commands: [CommandDescriptor] {
        WindowSnapAction.allCases.map { action in
            CommandDescriptor(
                id: "window-snap.\(action.rawValue)",
                title: "Snap Window: \(action.displayName)",
                subtitle: name,
                iconName: iconName,
                action: { [weak self] in
                    Task { @MainActor [weak self] in self?.snap(action) }
                }
            )
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
        guard hotkeys.isEmpty else { return }
        var registered: [GlobalHotkey] = []
        var failureReason: String?
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
                    failureReason = "Could not install hotkey handler for \(display) (\(status))."
                case .registerFailed(let status):
                    failureReason = "\(display) is already taken (Carbon error \(status)). Pick a different shortcut. Other Window Snap shortcuts remain available."
                }
                logger.warning("Could not register \(display): \(error)")
            } catch {
                failureReason = "Hotkey registration failed: \(error)"
                logger.warning("Hotkey registration failed: \(error)")
            }
        }
        self.hotkeys = registered
        if let failureReason {
            state = hotkeyHealth.failed(reason: failureReason)
        } else {
            state = hotkeyHealth.recovered(current: state)
        }
    }

    private func unregisterHotkeys() {
        hotkeys.forEach { $0.unregister() }
        hotkeys = []
    }
}
