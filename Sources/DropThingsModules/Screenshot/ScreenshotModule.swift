import AppKit
import Combine
import SwiftUI
import DropThingsCore
import DropThingsDesignSystem
import DropThingsPlatform
import os

/// Captures the visible screen content and shows it in a floating window
/// the user can save, copy, or close. v0 captures the whole main screen;
/// region selection and annotations land in v2.
public final class ScreenshotModule: DropThingsModule, ObservableObject {
    public let id = ModuleID.screenshot
    public let name = "Screenshot"
    public let summary = "Capture your screen. Save or copy the result."
    public let requiredPermissions: [SystemPermission] = [.screenRecording]

    @Published public private(set) var state: ModuleState = .off
    @Published public private(set) var settings: ScreenshotSettings
    @Published public private(set) var lastSavedURL: URL?

    private let settingsStore: SettingsStore
    private let permissions: PermissionCenter
    private let capture = ScreenCapture()
    private let writer = ScreenshotWriter()
    private var hotkey: GlobalHotkey?
    private var lastImage: CGImage?
    private let logger = ModuleLogger(subsystem: "app.dropthings", category: "screenshot")

    public init(settings: SettingsStore, permissions: PermissionCenter) {
        self.settingsStore = settings
        self.permissions = permissions
        self.settings = settings.loadScreenshotSettings()
    }

    public func start() async throws {
        guard permissions.state(for: .screenRecording) == .granted else {
            state = .needsPermission(missing: [.screenRecording])
            logger.notice("Start blocked: Screen Recording not granted")
            return
        }
        registerHotkey()
        state = .running
        logger.info("Screenshot started")
    }

    public func stop() async {
        unregisterHotkey()
        state = .off
        logger.info("Screenshot stopped")
    }

    // MARK: - Public actions

    /// Capture the full screen and show it in a window. Safe to call when
    /// the Screen Recording permission is missing — the function logs a
    /// notice and returns.
    public func captureFullScreen() {
        guard permissions.state(for: .screenRecording) == .granted else {
            logger.notice("Capture blocked: Screen Recording not granted")
            return
        }
        do {
            let image = try capture.captureScreen()
            lastImage = image
            logger.info("Captured full screen")
            showWindow(with: image)
        } catch {
            logger.error("Capture failed: \(error)")
        }
    }

    public func saveLastCapture() {
        guard let image = lastImage else { return }
        let dir = resolveSaveFolder()
        let stamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        let url = dir.appendingPathComponent("DropThings-\(stamp).png")
        do {
            try writer.savePNG(image, to: url)
            lastSavedURL = url
            updateLastPath(url.path)
            logger.info("Saved \(url.lastPathComponent)")
        } catch {
            logger.error("Save failed: \(error)")
        }
    }

    /// Show an `NSOpenPanel` to pick a save folder. Stores the URL as a
    /// security-scoped bookmark. The picker itself is local; the bookmark
    /// gives us a portable reference for a future sandboxed build.
    public func chooseSaveFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Choose"
        panel.message = "Where should DropThings save screenshots?"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let bookmark = try? url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        var new = settings
        new.saveFolderBookmark = bookmark
        new.lastSavePath = url.path
        applySettings(new)
        logger.info("Save folder set to \(url.path)")
    }

    /// Returns the user-chosen save folder, falling back to the default
    /// `~/Downloads/Screenshots` when no bookmark is set or the bookmark
    /// can no longer be resolved.
    public func resolveSaveFolder() -> URL {
        if let data = settings.saveFolderBookmark {
            var stale = false
            if let url = try? URL(
                resolvingBookmarkData: data,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &stale
            ) {
                _ = url.startAccessingSecurityScopedResource()
                return url
            }
        }
        return writer.resolveFolder()
    }

    public var screenshotSettings: ScreenshotSettings { settings }

    public func copyLastCapture() {
        guard let image = lastImage else { return }
        writer.copyToPasteboard(image)
        logger.info("Copied screenshot to clipboard")
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

    public func setHotkey(_ hotkey: GlobalHotkey.Definition?) {
        var new = settings
        new.hotkey = hotkey
        applySettings(new)
    }

    // MARK: - SwiftUI surface

    public func makeSettingsView() -> AnyView {
        AnyView(ScreenshotSettingsView(module: self))
    }

    // MARK: - Hotkey

    private func registerHotkey() {
        guard settings.hotkeyEnabled, let definition = settings.hotkey else { return }
        let hotkey = GlobalHotkey(definition: definition) { [weak self] in
            self?.captureFullScreen()
        }
        do {
            try hotkey.register()
            self.hotkey = hotkey
        } catch let error as GlobalHotkey.RegistrationError {
            let display = definition.displayString
            switch error {
            case .installHandlerFailed(let status):
                state = .degraded(reason: "Hotkey installer failed (\(status)) for \(display). Use the Capture button.")
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

    // MARK: - Window

    private func showWindow(with image: CGImage) {
        let view = ScreenshotResultView(
            image: image,
            onSave: { [weak self] in self?.saveLastCapture() },
            onCopy: { [weak self] in self?.copyLastCapture() }
        )
        let hosting = NSHostingController(rootView: AnyView(view))
        let window = NSPanel(contentViewController: hosting)
        window.title = "Screenshot"
        window.setContentSize(NSSize(width: 720, height: 480))
        window.styleMask = [.titled, .closable, .resizable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        // Hold a strong reference until the window closes.
        objc_setAssociatedObject(window, &Self.windowKey, hosting, .OBJC_ASSOCIATION_RETAIN)
    }

    private static var windowKey: UInt8 = 0

    private func updateLastPath(_ path: String) {
        var new = settings
        new.lastSavePath = path
        applySettings(new)
    }

    private func applySettings(_ new: ScreenshotSettings) {
        let hotkeyChanged = settings.hotkey != new.hotkey
            || settings.hotkeyEnabled != new.hotkeyEnabled
        settings = new
        settingsStore.saveScreenshotSettings(new)
        if hotkeyChanged && state == .running {
            unregisterHotkey()
            registerHotkey()
        }
    }
}
