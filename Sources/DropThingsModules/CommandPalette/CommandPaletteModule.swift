import AppKit
import Combine
import SwiftUI
import DropThingsCore
import DropThingsDesignSystem
import DropThingsPlatform
import os

/// Global hotkey-invokable floating search panel that aggregates commands from
/// all modules. Each module exposes `commands: [CommandDescriptor]` via the
/// `CommandSource` protocol; this module receives an aggregation closure
/// injected from the app composition root so it never imports other modules.
public final class CommandPaletteModule: DropThingsModule, ObservableObject {
    public let id = ModuleID.commandPalette
    public let name = "Command Palette"
    public let summary = "Global hotkey-invokable floating search for module commands."
    public let requiredPermissions: [SystemPermission] = []

    @Published public private(set) var state: ModuleState = .off
    @Published public private(set) var settings: CommandPaletteSettings

    private let settingsStore: SettingsStore
    private let commandSource: @MainActor () -> [CommandDescriptor]
    private var hotkey: GlobalHotkey?
    private var panel: CommandPalettePanelController?
    private let logger = ModuleLogger(subsystem: "app.dropthings", category: "command-palette")

    public init(
        settings: SettingsStore,
        permissions: PermissionCenter,
        commandSource: @escaping @MainActor () -> [CommandDescriptor]
    ) {
        self.settingsStore = settings
        self.commandSource = commandSource
        self.settings = settings.loadCommandPaletteSettings()
        self.panel = CommandPalettePanelController(commandSource: commandSource)
    }

    public func start() async throws {
        registerHotkey()
        state = .running
        logger.info("Command Palette started")
    }

    public func stop() async {
        unregisterHotkey()
        panel?.hide()
        state = .off
        logger.info("Command Palette stopped")
    }

    // MARK: - Public actions

    public func show() {
        panel?.show()
    }

    public func hide() {
        panel?.hide()
    }

    public func toggle() {
        if panel?.isVisible == true {
            hide()
        } else {
            show()
        }
    }

    public func setHotkeyEnabled(_ enabled: Bool) {
        var new = settings
        new.hotkeyEnabled = enabled
        applySettings(new)
    }

    public func setHotkey(_ hotkey: GlobalHotkey.Definition?) {
        var new = settings
        new.hotkey = hotkey
        applySettings(new)
    }

    public func makeSettingsView() -> AnyView {
        AnyView(CommandPaletteSettingsView(module: self))
    }

    // MARK: - Settings

    private func applySettings(_ new: CommandPaletteSettings) {
        let sanitized = CommandPaletteSettings.sanitized(
            hotkeyEnabled: new.hotkeyEnabled,
            hotkey: new.hotkey
        )
        let hotkeyChanged = settings.hotkey != sanitized.hotkey
            || settings.hotkeyEnabled != sanitized.hotkeyEnabled
        settings = sanitized
        settingsStore.saveCommandPaletteSettings(sanitized)
        if hotkeyChanged && state.isStarted {
            unregisterHotkey()
            registerHotkey()
        }
    }

    // MARK: - Hotkey

    private func registerHotkey() {
        guard settings.hotkeyEnabled, let definition = settings.hotkey else { return }
        let hotkey = GlobalHotkey(definition: definition) { [weak self] in
            self?.toggle()
        }
        do {
            try hotkey.register()
            self.hotkey = hotkey
        } catch let error as GlobalHotkey.RegistrationError {
            let display = definition.displayString
            switch error {
            case .installHandlerFailed(let status):
                state = .degraded(reason: "Hotkey installer failed (\(status)) for \(display). Use settings to change it.")
            case .registerFailed(let status):
                state = .degraded(reason: "\(display) is already taken by another app (Carbon error \(status)). Pick a different shortcut.")
            }
            logger.warning("Could not register \(display): \(error)")
        } catch {
            state = .degraded(reason: "Hotkey registration failed: \(error)")
            logger.warning("Hotkey registration failed: \(error)")
        }
    }

    private func unregisterHotkey() {
        hotkey?.unregister()
        hotkey = nil
    }
}
