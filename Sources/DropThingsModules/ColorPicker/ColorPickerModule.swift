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
    private let permissions: PermissionCenter
    private var hotkey: GlobalHotkey?
    private var activeSampler: NSColorSampler?
    private var loupe: ColorSamplerLoupe?
    private var loupeWindow: ColorPickerLoupeWindowController?
    private let logger = ModuleLogger(subsystem: "app.dropthings", category: "color-picker")

    public init(settings: SettingsStore, permissions: PermissionCenter) {
        self.settingsStore = settings
        self.permissions = permissions
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
        stopLoupe()
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
        startLoupe()
        sampler.show { [weak self] color in
            Task { @MainActor in
                guard let self else { return }
                self.activeSampler = nil
                self.stopLoupe()
                guard let color else {
                    self.logger.notice("Picking cancelled")
                    return
                }
                self.handlePickedColor(color)
            }
        }
        logger.info("Native color sampler opened")
    }

    private func startLoupe() {
        let window = ColorPickerLoupeWindowController()
        loupeWindow = window
        let loupe = ColorSamplerLoupe(regionSize: 96) { [weak self] sample in
            guard let self else { return }
            let bridge = LoupeViewSample(
                image: sample.image,
                zoom: 8,
                rgb: sample.centerRGB.map { PixelSample(r: $0.r, g: $0.g, b: $0.b) },
                location: sample.location
            )
            self.loupeWindow?.show(sample: bridge)
        }
        loupe.start()
        self.loupe = loupe
    }

    private func stopLoupe() {
        loupe?.stop()
        loupe = nil
        loupeWindow?.hide()
        loupeWindow = nil
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
            hotkey: settings.hotkey,
            copyFormat: settings.copyFormat
        ).historyLimit
        new.history = ColorPickerSettings.sanitized(
            hotkeyEnabled: settings.hotkeyEnabled,
            history: settings.history,
            historyLimit: new.historyLimit,
            hotkey: settings.hotkey,
            copyFormat: settings.copyFormat
        ).history
        applySettings(new)
    }

    public func setCopyFormat(_ format: ColorCopyFormat) {
        var new = settings
        new.copyFormat = format
        applySettings(new)
    }

    public func toggleFavorite(id: UUID) {
        var new = settings
        guard let index = new.history.firstIndex(where: { $0.id == id }) else { return }
        new.history[index].isFavorite.toggle()
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
            hotkey: new.hotkey,
            copyFormat: new.copyFormat
        )
        let hotkeyChanged = settings.hotkey != sanitized.hotkey
            || settings.hotkeyEnabled != sanitized.hotkeyEnabled
        settings = sanitized
        settingsStore.saveColorPickerSettings(sanitized)
        if hotkeyChanged && state.isStarted {
            unregisterHotkey()
            registerHotkey()
        }
    }

    public func copyToPasteboard(_ picked: PickedColor) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(settings.copyFormat.string(r: picked.r, g: picked.g, b: picked.b), forType: .string)
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
        // New picks go to the front of the non-favorite section so
        // favorites pinned to the top stay put.
        let firstNonFavorite = new.history.firstIndex(where: { !$0.isFavorite }) ?? new.history.count
        new.history.insert(picked, at: firstNonFavorite)
        // Enforce the cap, but never evict favorites.
        let sanitized = ColorPickerSettings.sanitized(
            hotkeyEnabled: new.hotkeyEnabled,
            history: new.history,
            historyLimit: new.historyLimit,
            hotkey: new.hotkey,
            copyFormat: new.copyFormat
        )
        new.history = sanitized.history
        applySettings(new)
    }

    private static func componentToByte(_ value: CGFloat) -> Int {
        min(max(Int((value * 255).rounded()), 0), 255)
    }
}
