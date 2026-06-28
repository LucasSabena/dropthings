import AppKit
import Combine
import SwiftUI
import DropThingsCore
import DropThingsDesignSystem
import DropThingsPlatform
import os

/// Picks any pixel color from the screen and copies its hex code to the
/// clipboard. The user enters picking mode via ⌥⌘C (configurable later);
/// the screen freezes into a dimmed overlay with a crosshair cursor; the
/// next click samples the pixel under the cursor.
public final class ColorPickerModule: DropThingsModule, ObservableObject {
    public let id = ModuleID.colorPicker
    public let name = "Color Picker"
    public let summary = "Pick a color from anywhere on screen."
    public let requiredPermissions: [SystemPermission] = [.screenRecording]

    @Published public private(set) var state: ModuleState = .off
    @Published public private(set) var settings: ColorPickerSettings

    private let settingsStore: SettingsStore
    private let permissions: PermissionCenter
    private let capture = ScreenCapture()
    private var hotkey: GlobalHotkey?
    private var overlay: ColorPickerOverlayWindow?
    private var capturedImage: CGImage?
    private let logger = ModuleLogger(subsystem: "app.dropthings", category: "color-picker")

    public init(settings: SettingsStore, permissions: PermissionCenter) {
        self.settingsStore = settings
        self.permissions = permissions
        self.settings = settings.loadColorPickerSettings()
    }

    public func start() async throws {
        guard permissions.state(for: .screenRecording) == .granted else {
            state = .needsPermission(missing: [.screenRecording])
            logger.notice("Start blocked: Screen Recording not granted")
            return
        }
        registerHotkey()
        state = .running
        logger.info("Color Picker started")
    }

    public func stop() async {
        unregisterHotkey()
        dismissOverlay()
        state = .off
        logger.info("Color Picker stopped")
    }

    // MARK: - Public actions

    /// Trigger picking mode programmatically (settings button or menu
    /// entry). Safe to call when the screen recording permission is missing
    /// — the function returns silently and logs a notice.
    public func startPicking() {
        guard permissions.state(for: .screenRecording) == .granted else {
            logger.notice("Pick blocked: Screen Recording not granted")
            return
        }
        guard overlay == nil else { return }
        do {
            let image = try capture.captureScreen()
            capturedImage = image
            let overlay = ColorPickerOverlayWindow(capturedImage: image)
            overlay.onPick = { [weak self] location in
                self?.handlePick(at: location)
            }
            overlay.onCancel = { [weak self] in
                self?.dismissOverlay()
            }
            overlay.makeKeyAndOrderFront(nil)
            NSCursor.crosshair.push()
            self.overlay = overlay
            logger.info("Picking mode entered")
        } catch {
            logger.error("Capture failed: \(error)")
        }
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

    private func handlePick(at location: CGPoint) {
        guard let image = capturedImage else {
            dismissOverlay()
            return
        }
        let scale = overlay?.backingScaleFactor ?? 1
        let imagePoint = CGPoint(
            x: location.x * scale,
            y: CGFloat(image.height) - location.y * scale
        )
        guard let rgb = PixelSampler.sample(at: imagePoint, in: image) else {
            dismissOverlay()
            return
        }
        let picked = PickedColor.from(rgb: rgb)
        recordPick(picked)
        copyToPasteboard(picked)
        logger.notice("Picked \(picked.hex)")
        dismissOverlay()
    }

    private func recordPick(_ picked: PickedColor) {
        var new = settings
        new.history.insert(picked, at: 0)
        new.history = Array(new.history.prefix(new.historyLimit))
        applySettings(new)
    }

    private func dismissOverlay() {
        overlay?.orderOut(nil)
        overlay = nil
        capturedImage = nil
        if NSCursor.current == NSCursor.crosshair {
            NSCursor.pop()
        }
    }
}
