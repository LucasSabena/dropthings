import AppKit
import Combine
import SwiftUI
import DropThingsCore
import DropThingsDesignSystem
import DropThingsPlatform
import os

/// Floating text transformation utility. No permissions are required; clipboard
/// access is optional and only happens when the user explicitly pastes or copies.
public final class TextToolsModule: DropThingsModule, ObservableObject {
    public let id = ModuleID.textTools
    public let name = "Text Tools"
    public let summary = "Quick case, URL, JSON, Base64, line, and count transforms."
    public let requiredPermissions: [SystemPermission] = []

    @Published public private(set) var state: ModuleState = .off
    @Published public private(set) var settings: TextToolsSettings

    private let settingsStore: SettingsStore
    private let logger = ModuleLogger(subsystem: "app.dropthings", category: "text-tools")
    private var hotkey: GlobalHotkey?
    private var panel: TextToolsPanelController?

    public init(settings: SettingsStore) {
        self.settingsStore = settings
        self.settings = settings.loadTextToolsSettings()
        self.panel = TextToolsPanelController(module: self)
    }

    public func start() async throws {
        registerHotkey()
        state = .running
        logger.info("Text Tools started")
    }

    public func stop() async {
        unregisterHotkey()
        panel?.hide()
        state = .off
        logger.info("Text Tools stopped")
    }

    // MARK: - Public actions

    public func showPanel() {
        panel?.show()
    }

    public func hidePanel() {
        panel?.hide()
    }

    public func togglePanel() {
        panel?.toggle()
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

    public var textToolsSettings: TextToolsSettings { settings }

    // MARK: - Settings

    private func applySettings(_ new: TextToolsSettings) {
        let sanitized = TextToolsSettings.sanitized(
            hotkeyEnabled: new.hotkeyEnabled,
            hotkey: new.hotkey
        )
        let hotkeyChanged = settings.hotkey != sanitized.hotkey
            || settings.hotkeyEnabled != sanitized.hotkeyEnabled
        settings = sanitized
        settingsStore.saveTextToolsSettings(sanitized)
        if hotkeyChanged && state.isStarted {
            unregisterHotkey()
            registerHotkey()
        }
    }

    // MARK: - SwiftUI surface

    public func makeSettingsView() -> AnyView {
        AnyView(TextToolsSettingsView(module: self))
    }

    // MARK: - Hotkey

    private func registerHotkey() {
        guard settings.hotkeyEnabled, let definition = settings.hotkey else { return }
        let hotkey = GlobalHotkey(definition: definition) { [weak self] in
            self?.showPanel()
        }
        do {
            try hotkey.register()
            self.hotkey = hotkey
        } catch let error as GlobalHotkey.RegistrationError {
            let display = definition.displayString
            switch error {
            case .installHandlerFailed(let status):
                state = .degraded(reason: "Hotkey installer failed (\(status)) for \(display). Use the Open Text Tools button.")
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
