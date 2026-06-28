import AppKit
import Combine
import SwiftUI
import DropThingsCore
import DropThingsDesignSystem
import DropThingsPlatform
import os

/// Picks any pixel color from the screen and copies its hex code to the
/// clipboard. The module uses AppKit's native `NSColorSampler`, which gives
/// the user the standard macOS eyedropper instead of a custom screenshot
/// overlay.
public final class ColorPickerModule: DropThingsModule, ObservableObject {
    public let id = ModuleID.colorPicker
    public let name = "Color Picker"
    public let summary = "Pick a color from anywhere on screen."
    public let requiredPermissions: [SystemPermission] = []

    @Published public private(set) var state: ModuleState = .off
    @Published public private(set) var settings: ColorPickerSettings

    private let settingsStore: SettingsStore
    private var hotkey: GlobalHotkey?
    private var activeSampler: NSColorSampler?
    private let logger = ModuleLogger(subsystem: "app.dropthings", category: "color-picker")

    public init(settings: SettingsStore, permissions: PermissionCenter) {
        self.settingsStore = settings
        self.settings = settings.loadColorPickerSettings()
    }

    public func start() async throws {
        registerHotkey()
        state = .running
        logger.info("Color Picker started")
    }

    public func stop() async {
        unregisterHotkey()
        activeSampler = nil
        state = .off
        logger.info("Color Picker stopped")
    }

    // MARK: - Public actions

    /// Trigger the system color sampler programmatically (settings button or
    /// hotkey). Safe to call repeatedly; the second call is ignored while the
    /// native sampler is already active.
    public func startPicking() {
        guard activeSampler == nil else { return }
        let sampler = NSColorSampler()
        activeSampler = sampler
        sampler.show { [weak self] color in
            Task { @MainActor in
                guard let self else { return }
                self.activeSampler = nil
                guard let color else {
                    self.logger.notice("Picking cancelled")
                    return
                }
                self.handlePickedColor(color)
            }
        }
        logger.info("Native color sampler opened")
    }

    public func clearHistory() {
        var new = settings
        new.history = []
        applySettings(new)
    }

    public func removeHistoryEntry(id: UUID) {
        var new = settings
        new.history.removeAll { $0.id == id }
        applySettings(new)
    }

    public func setHotkeyEnabled(_ enabled: Bool) {
        var new = settings
        new.hotkeyEnabled = enabled
        applySettings(new)
        if enabled && state == .running {
            registerHotkey()
        } else {
            unregisterHotkey()
        }
    }

    public func setHistoryLimit(_ limit: Int) {
        var new = settings
        new.historyLimit = ColorPickerSettings.sanitized(
            hotkeyEnabled: settings.hotkeyEnabled,
            history: settings.history,
            historyLimit: limit,
            hotkey: settings.hotkey
        ).historyLimit
        new.history = Array(new.history.prefix(new.historyLimit))
        applySettings(new)
    }

    public func setHotkey(_ hotkey: GlobalHotkey.Definition?) {
        var new = settings
        new.hotkey = hotkey
        applySettings(new)
    }

    public var colorPickerSettings: ColorPickerSettings { settings }

    private func applySettings(_ new: ColorPickerSettings) {
        let sanitized = ColorPickerSettings.sanitized(
            hotkeyEnabled: new.hotkeyEnabled,
            history: new.history,
            historyLimit: new.historyLimit,
            hotkey: new.hotkey
        )
        let hotkeyChanged = settings.hotkey != sanitized.hotkey
            || settings.hotkeyEnabled != sanitized.hotkeyEnabled
        settings = sanitized
        settingsStore.saveColorPickerSettings(sanitized)
        if hotkeyChanged && state == .running {
            unregisterHotkey()
            registerHotkey()
        }
    }

    public func copyToPasteboard(_ picked: PickedColor) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(picked.hex, forType: .string)
    }

    // MARK: - SwiftUI surface

    public func makeSettingsView() -> AnyView {
        AnyView(ColorPickerSettingsView(module: self))
    }

    // MARK: - Hotkey

    private func registerHotkey() {
        guard settings.hotkeyEnabled, let definition = settings.hotkey else { return }
        let hotkey = GlobalHotkey(definition: definition) { [weak self] in
            self?.handleHotkeyFire()
        }
        do {
            try hotkey.register()
            self.hotkey = hotkey
        } catch let error as GlobalHotkey.RegistrationError {
            let display = definition.displayString
            switch error {
            case .installHandlerFailed(let status):
                state = .degraded(reason: "Hotkey installer failed (\(status)) for \(display). Use the Pick color now button.")
            case .registerFailed(let status):
                state = .degraded(reason: "\(display) is already taken by another app (Carbon error \(status)). Pick a different shortcut or use the button.")
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

    private func handleHotkeyFire() {
        startPicking()
    }

    // MARK: - Pick handling

    private func handlePickedColor(_ color: NSColor) {
        guard let rgbColor = color.usingColorSpace(.deviceRGB) ?? color.usingColorSpace(.sRGB) else {
            logger.warning("Picked color could not be converted to RGB")
            return
        }
        let picked = PickedColor(
            r: Self.componentToByte(rgbColor.redComponent),
            g: Self.componentToByte(rgbColor.greenComponent),
            b: Self.componentToByte(rgbColor.blueComponent)
        )
        recordPick(picked)
        copyToPasteboard(picked)
        logger.notice("Picked \(picked.hex)")
    }

    private func recordPick(_ picked: PickedColor) {
        var new = settings
        new.history.insert(picked, at: 0)
        new.history = Array(new.history.prefix(new.historyLimit))
        applySettings(new)
    }

    private static func componentToByte(_ value: CGFloat) -> Int {
        min(max(Int((value * 255).rounded()), 0), 255)
    }
}
