import AppKit
import Combine
import SwiftUI
import DropThingsCore
import DropThingsDesignSystem
import DropThingsPlatform
import os

/// Picks any pixel color with macOS' native, GPU-backed sampler and writes
/// both a formatted string and a real `NSColor` representation to the
/// pasteboard. The native sampler owns the live magnifier; rebuilding a custom
/// SwiftUI loupe on every mouse tick made the old experience visibly stall.
public final class ColorPickerModule: DropThingsModule {
    public let id = ModuleID.colorPicker
    public let name = "Color Picker"
    public let summary = "Pick a color from anywhere on screen."
    public let requiredPermissions: [SystemPermission] = []

    @Published public private(set) var state: ModuleState = .off
    @Published public private(set) var settings: ColorPickerSettings
    @Published public private(set) var isPicking = false
    @Published public private(set) var lastCopiedValue: String?

    private let settingsStore: SettingsStore
    private let permissions: PermissionCenter
    private var hotkey: GlobalHotkey?
    private var hotkeyHealth = HotkeyRegistrationHealth()
    private var conversionHealth = RecoverableFailureHealth()
    private var activeSampler: NSColorSampler?
    private let feedbackWindow = ColorCopyFeedbackWindowController()
    private let logger = ModuleLogger(subsystem: "app.dropthings", category: "color-picker")

    public typealias ColorConverter = (NSColor) -> NSColor?
    private let colorConverter: ColorConverter

    public nonisolated static func defaultColorConverter(_ color: NSColor) -> NSColor? {
        color.usingColorSpace(.deviceRGB) ?? color.usingColorSpace(.sRGB)
    }

    public init(
        settings: SettingsStore,
        permissions: PermissionCenter,
        colorConverter: @escaping ColorConverter = ColorPickerModule.defaultColorConverter
    ) {
        self.settingsStore = settings
        self.permissions = permissions
        self.colorConverter = colorConverter
        self.settings = settings.loadColorPickerSettings()
    }

    public func start() async throws {
        registerHotkey()
        if case .degraded = state {} else { state = .running }
        logger.info("Color Picker started")
    }

    public func stop() async {
        unregisterHotkey()
        activeSampler = nil
        isPicking = false
        feedbackWindow.hide()
        state = .off
        logger.info("Color Picker stopped")
    }

    /// One-tap entry point from the menu bar.
    public var primaryAction: ModulePrimaryAction? {
        ModulePrimaryAction(
            title: "Pick Color",
            iconName: iconName,
            action: { [weak self] in
                Task { @MainActor [weak self] in
                    self?.startPicking()
                }
            }
        )
    }

    public var commands: [CommandDescriptor] {
        [
            CommandDescriptor(
                id: "color-picker.pick",
                title: "Pick Color",
                subtitle: name,
                iconName: iconName,
                action: { [weak self] in
                    Task { @MainActor [weak self] in self?.startPicking() }
                }
            )
        ]
    }

    // MARK: - Public actions

    /// Trigger one native sampling session. `NSColorSampler` provides the
    /// smooth system magnifier and correct click/Escape behavior without a
    /// screen-recording permission or a polling loop on the main actor.
    public func startPicking() {
        guard activeSampler == nil, !isPicking else { return }
        let sampler = NSColorSampler()
        activeSampler = sampler
        isPicking = true
        sampler.show { [weak self] color in
            Task { @MainActor in
                guard let self else { return }
                self.activeSampler = nil
                self.isPicking = false
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
    }

    public func setHistoryLimit(_ limit: Int) {
        var candidate = settings
        candidate.historyLimit = limit
        let sanitized = ColorPickerSettings.sanitized(
            hotkeyEnabled: candidate.hotkeyEnabled,
            history: candidate.history,
            historyLimit: candidate.historyLimit,
            hotkey: candidate.hotkey,
            copyFormat: candidate.copyFormat
        )
        applySettings(sanitized)
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
        let color = picked.rgb.nsColor
        let value = settings.copyFormat.string(r: picked.r, g: picked.g, b: picked.b)
        // `writeObjects` publishes the native color pasteboard type. Adding a
        // string representation to the same pasteboard makes the result paste
        // naturally into code editors while Clipboard History can still render
        // it as an actual color swatch.
        _ = pb.writeObjects([color])
        _ = pb.setString(value, forType: .string)
        lastCopiedValue = value
        feedbackWindow.show(color: color, value: value, near: NSEvent.mouseLocation)
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
    }

    // MARK: - SwiftUI surface

    public func makeSettingsView() -> AnyView {
        AnyView(ColorPickerSettingsView(module: self))
    }

    // MARK: - Hotkey

    private func registerHotkey() {
        guard hotkey == nil else { return }
        guard settings.hotkeyEnabled, let definition = settings.hotkey else {
            state = hotkeyHealth.recovered(current: state)
            return
        }
        let hotkey = GlobalHotkey(definition: definition) { [weak self] in
            self?.handleHotkeyFire()
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
                reason = "Hotkey installer failed (\(status)) for \(display). Use the Pick color now button."
            case .registerFailed(let status):
                reason = "\(display) is already taken by another app (Carbon error \(status)). Pick a different shortcut or use the button."
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

    private func handleHotkeyFire() {
        startPicking()
    }

    // MARK: - Pick handling

    internal func handlePickedColor(_ color: NSColor) {
        guard let rgbColor = colorConverter(color) else {
            state = conversionHealth.failed(reason: "Picked color could not be converted to RGB.")
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
        state = conversionHealth.recovered(current: state)
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
