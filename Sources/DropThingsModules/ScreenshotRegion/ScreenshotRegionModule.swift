import AppKit
import SwiftUI
import DropThingsCore
import DropThingsDesignSystem
import DropThingsPlatform
import os

/// Captures a user-selected region of the screen to a file and to the
/// pasteboard. Shows a full-screen drag-select overlay when triggered from the
/// settings button or the global hotkey.
public final class ScreenshotRegionModule: DropThingsModule, ObservableObject {
    public let id = ModuleID.screenshotRegion
    public let name = "Screenshot Region"
    public let summary = "Drag to capture any region of your screen."
    public let requiredPermissions: [SystemPermission] = [.screenRecording]

    @Published public private(set) var state: ModuleState = .off
    @Published public private(set) var settings: ScreenshotRegionSettings
    @Published public private(set) var lastSavedURL: URL?

    private let settingsStore: SettingsStore
    private let permissions: PermissionCenter
    private let fileManager: FileManager
    private let pasteboard: NSPasteboard
    private let logger = ModuleLogger(subsystem: "app.dropthings", category: "screenshot-region")
    private var hotkey: GlobalHotkey?
    private var overlay: RegionSelectionOverlay?
    private var isCapturing = false

    public init(
        settings: SettingsStore,
        permissions: PermissionCenter,
        fileManager: FileManager = .default,
        pasteboard: NSPasteboard = .general
    ) {
        self.settingsStore = settings
        self.permissions = permissions
        self.fileManager = fileManager
        self.pasteboard = pasteboard
        self.settings = settings.loadScreenshotRegionSettings()
    }

    public func start() async throws {
        registerHotkey()
        state = .running
        logger.info("Screenshot Region started")
    }

    public func stop() async {
        unregisterHotkey()
        overlay?.cancel()
        overlay = nil
        state = .off
        logger.info("Screenshot Region stopped")
    }

    // MARK: - Public actions

    /// Trigger the region overlay programmatically (settings button or hotkey).
    public func captureRegion() {
        guard !isCapturing else {
            logger.notice("Capture already in progress; ignoring trigger")
            return
        }
        guard permissions.state(for: .screenRecording) == .granted else {
            state = .needsPermission(missing: [.screenRecording])
            logger.notice("Capture blocked: Screen Recording not granted")
            return
        }
        isCapturing = true
        let overlay = RegionSelectionOverlay()
        self.overlay = overlay
        overlay.show { [weak self] result in
            guard let self else { return }
            self.overlay = nil
            self.handleOverlayResult(result)
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

    public func setSaveLocation(_ url: URL?) {
        var new = settings
        new.saveLocationPath = url?.path
        applySettings(new)
    }

    public func setCopyPreviewToPasteboard(_ enabled: Bool) {
        var new = settings
        new.copyPreviewToPasteboard = enabled
        applySettings(new)
    }

    public var screenshotRegionSettings: ScreenshotRegionSettings { settings }

    // MARK: - Command Palette

    public var commands: [CommandDescriptor] {
        [
            CommandDescriptor(
                id: "capture-region",
                title: "Capture Screenshot Region",
                subtitle: "Screenshot Region",
                iconName: "camera.viewfinder",
                action: { [weak self] in
                    Task { @MainActor [weak self] in
                        self?.captureRegion()
                    }
                }
            )
        ]
    }

    // MARK: - SwiftUI surface

    public func makeSettingsView() -> AnyView {
        AnyView(ScreenshotRegionSettingsView(module: self))
    }

    // MARK: - Settings

    private func applySettings(_ new: ScreenshotRegionSettings) {
        let sanitized = ScreenshotRegionSettings.sanitized(
            hotkeyEnabled: new.hotkeyEnabled,
            hotkey: new.hotkey,
            saveLocationPath: new.saveLocationPath,
            copyPreviewToPasteboard: new.copyPreviewToPasteboard
        )
        let hotkeyChanged = settings.hotkey != sanitized.hotkey
            || settings.hotkeyEnabled != sanitized.hotkeyEnabled
        settings = sanitized
        settingsStore.saveScreenshotRegionSettings(sanitized)
        if hotkeyChanged && state.isStarted {
            unregisterHotkey()
            registerHotkey()
        }
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
                state = .degraded(reason: "Hotkey installer failed (\(status)) for \(display). Use the Capture region now button.")
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
        captureRegion()
    }

    // MARK: - Capture flow

    private func handleOverlayResult(_ result: RegionSelectionOverlay.Result) {
        defer { isCapturing = false }

        switch result {
        case .cancelled:
            logger.notice("Region selection cancelled")
            restoreRunningState()
        case .region(let rect):
            captureAndSave(rect: rect)
        }
    }

    private func captureAndSave(rect: CGRect) {
        guard let image = ScreenCapture.rect(rect) else {
            logger.warning("Screen capture returned no image for \(rect)")
            state = .degraded(reason: "Could not capture the selected region. Make sure Screen Recording is granted in System Settings.")
            return
        }

        let saveURL = resolveSaveURL()
        do {
            try createDirectoryIfNeeded(for: saveURL)
            let fileURL = saveURL.appendingPathComponent(filename())
            try save(image: image, to: fileURL)
            lastSavedURL = fileURL
            if settings.copyPreviewToPasteboard {
                copyPreviewToPasteboard(image: image)
            }
            restoreRunningState()
            logger.notice("Saved screenshot to \(fileURL.path)")
        } catch {
            logger.error("Could not save screenshot: \(error)")
            state = .degraded(reason: "Could not save screenshot: \(error.localizedDescription). Check the save location in settings.")
        }
    }

    private func resolveSaveURL() -> URL {
        if let path = settings.saveLocationPath {
            let url = URL(fileURLWithPath: path)
            if fileManager.fileExists(atPath: url.path) {
                return url
            }
        }
        return fileManager.urls(for: .desktopDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
    }

    private func createDirectoryIfNeeded(for url: URL) throws {
        var isDirectory: ObjCBool = false
        let exists = fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory)
        if exists && isDirectory.boolValue { return }
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
    }

    private func filename() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return "Screenshot \(formatter.string(from: Date())).png"
    }

    private func save(image: CGImage, to url: URL) throws {
        let rep = NSBitmapImageRep(cgImage: image)
        guard let data = rep.representation(using: .png, properties: [:]) else {
            throw ScreenshotError.encodingFailed
        }
        try data.write(to: url, options: .atomic)
    }

    private func copyPreviewToPasteboard(image: CGImage) {
        let nsImage = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
        pasteboard.clearContents()
        pasteboard.writeObjects([nsImage])
        logger.notice("Copied screenshot preview to pasteboard")
    }

    private func restoreRunningState() {
        if case .degraded = state {
            state = .running
        }
    }

    private enum ScreenshotError: Error, CustomStringConvertible {
        case encodingFailed

        var description: String {
            switch self {
            case .encodingFailed: return "Image encoding failed"
            }
        }
    }
}
