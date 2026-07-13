import AppKit
import Combine
import SwiftUI
import DropThingsCore
import DropThingsDesignSystem
import DropThingsPlatform

@MainActor
public final class ScreenshotStudioModule: DropThingsModule {
    public let id = ModuleID.screenshotStudio
    public let name = "Screenshot Studio"
    public let summary = "Capture regions, windows, and displays with independent shortcuts."
    public let requiredPermissions: [SystemPermission] = [.screenRecording]

    @Published public private(set) var state: ModuleState = .off
    @Published public private(set) var settings: ScreenshotStudioSettings
    @Published public private(set) var lastSavedURL: URL?
    @Published public private(set) var lastCaptureSize: CGSize?
    @Published public private(set) var scrollState: ScrollCaptureState = .idle

    private let settingsStore: SettingsStore
    private let permissions: PermissionCenter
    private let captureService: any ScreenCaptureService
    private let fileManager: FileManager
    private let pasteboard: NSPasteboard
    private let captureArchive: CaptureArchive
    private var hotkeys: [ScreenshotCaptureMode: GlobalHotkey] = [:]
    private var overlay: RegionCaptureOverlay?
    private var isCapturing = false
    private var activationObserver: NSObjectProtocol?
    private var editors: [UUID: ScreenshotEditorWindowController] = [:]
    private var thumbnails: [UUID: FloatingCaptureThumbnailController] = [:]
    private var pinnedImages: [UUID: PinnedImageController] = [:]
    private let scrollCoordinator = ScrollCaptureCoordinator()
    private let logger = ModuleLogger(subsystem: "app.dropthings", category: "screenshot-studio")

    public init(
        settings: SettingsStore,
        permissions: PermissionCenter,
        captureService: any ScreenCaptureService = ScreenCaptureKitService(),
        fileManager: FileManager = .default,
        pasteboard: NSPasteboard = .general,
        captureArchive: CaptureArchive = CaptureArchive()
    ) {
        self.settingsStore = settings
        self.permissions = permissions
        self.captureService = captureService
        self.fileManager = fileManager
        self.pasteboard = pasteboard
        self.captureArchive = captureArchive
        self.settings = settings.loadScreenshotStudioSettings()
    }

    public func start() async throws {
        guard permissions.state(for: .screenRecording) == .granted else {
            state = .needsPermission(missing: [.screenRecording])
            return
        }
        registerHotkeys()
        subscribeToActivation()
        if case .degraded = state { } else { state = .running }
    }

    public func stop() async {
        unregisterHotkeys()
        overlay?.cancel(); overlay = nil
        isCapturing = false
        if let activationObserver { NotificationCenter.default.removeObserver(activationObserver) }
        activationObserver = nil
        state = .off
    }

    public var primaryAction: ModulePrimaryAction? {
        ModulePrimaryAction(title: "Capture region", iconName: iconName) { [weak self] in
            Task { @MainActor in self?.capture(.region) }
        }
    }

    public var commands: [CommandDescriptor] {
        ScreenshotCaptureMode.allCases.map { mode in
            CommandDescriptor(id: "screenshot-studio.capture.\(mode.rawValue)", title: "Capture \(mode.title)", subtitle: name, iconName: iconName) { [weak self] in
                Task { @MainActor in self?.capture(mode) }
            }
        }
    }

    public func capture(_ mode: ScreenshotCaptureMode) {
        guard !isCapturing else { return }
        guard permissions.state(for: .screenRecording) == .granted else {
            state = .needsPermission(missing: [.screenRecording])
            return
        }
        NotificationCenter.default.post(name: .dropThingsCaptureWillBegin, object: nil)
        switch mode {
        case .region: beginRegionCapture()
        case .window: beginWindowCapture()
        case .display: beginDisplayCapture()
        case .scrolling: beginScrollingCapture()
        }
    }

    public func setShortcut(_ shortcut: GlobalHotkey.Definition?, for mode: ScreenshotCaptureMode) {
        var next = settings
        next.shortcuts[mode] = shortcut
        apply(settings: next)
    }

    public func setShortcutsEnabled(_ enabled: Bool) { var next = settings; next.shortcutsEnabled = enabled; apply(settings: next) }
    public func setOutput(_ output: ScreenshotOutputAction, for mode: ScreenshotCaptureMode) { var next = settings; next.outputs[mode] = output; apply(settings: next) }
    public func setCapturePreviewVisible(_ visible: Bool) { var next = settings; next.showCapturePreview = visible; apply(settings: next) }
    public func setSaveLocation(_ url: URL?) { var next = settings; next.saveLocationPath = url?.path; apply(settings: next) }
    public func setIncludeWindowShadow(_ enabled: Bool) { var next = settings; next.includeWindowShadow = enabled; apply(settings: next) }
    public func setFileFormat(_ format: ScreenshotFileFormat) { var next = settings; next.fileFormat = format; apply(settings: next) }
    public func setJPEGQuality(_ quality: Double) { var next = settings; next.jpegQuality = quality; apply(settings: next) }
    public func setThumbnailDuration(_ duration: Double) { var next = settings; next.thumbnailDuration = duration; apply(settings: next) }

    public func makeSettingsView() -> AnyView { AnyView(ScreenshotStudioSettingsView(module: self)) }

    internal func saveDirectory() -> URL {
        if let path = settings.saveLocationPath {
            var isDirectory: ObjCBool = false
            if fileManager.fileExists(atPath: path, isDirectory: &isDirectory), isDirectory.boolValue { return URL(fileURLWithPath: path) }
        }
        return fileManager.urls(for: .desktopDirectory, in: .userDomainMask).first ?? fileManager.temporaryDirectory
    }

    internal func nextSaveURL(in directory: URL, date: Date = Date()) -> URL {
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        let stem = settings.filenameTemplate.replacingOccurrences(of: "{date}", with: formatter.string(from: date))
        var suffix = 1
        while true {
            let name = suffix == 1 ? "\(stem).\(settings.fileFormat.fileExtension)" : "\(stem) \(suffix).\(settings.fileFormat.fileExtension)"
            let candidate = directory.appendingPathComponent(name)
            if !fileManager.fileExists(atPath: candidate.path) { return candidate }
            suffix += 1
        }
    }

    private func beginRegionCapture() {
        isCapturing = true
        let overlay = RegionCaptureOverlay(); self.overlay = overlay
        overlay.show { [weak self] result in
            guard let self else { return }
            self.overlay = nil
            switch result {
            case .cancelled: self.isCapturing = false
            case .region(let appKitRect):
                let rect = ScreenCoordinateMapper.current().cgRect(forAppKitRect: appKitRect) ?? appKitRect
                self.performCapture(.region(rect))
            }
        }
    }

    private func beginWindowCapture() {
        isCapturing = true
        let cgPoint = ScreenCoordinateMapper.current().imagePoint(forAppKitPoint: NSEvent.mouseLocation)
        guard let window = ScreenCaptureTargets.window(at: cgPoint) else {
            isCapturing = false; state = .degraded(reason: "No capturable window was found under the pointer."); return
        }
        performCapture(.window(window.id, window.bounds))
    }

    private func beginDisplayCapture() {
        isCapturing = true
        let appKitPoint = NSEvent.mouseLocation
        let displays = ScreenCaptureTargets.displays()
        guard let display = displays.first(where: { screen in
            NSScreen.screens.first(where: { $0.localizedName == screen.name })?.frame.contains(appKitPoint) == true
        }) ?? displays.first else {
            isCapturing = false; state = .degraded(reason: "No active display is available."); return
        }
        performCapture(.display(display.id))
    }

    private func beginScrollingCapture() {
        guard permissions.state(for: .accessibility) == .granted else {
            _ = permissions.requestPermission(.accessibility)
            state = .needsPermission(missing: [.accessibility])
            return
        }
        isCapturing = true
        let overlay = RegionCaptureOverlay(); self.overlay = overlay
        overlay.show { [weak self] result in
            guard let self else { return }; self.overlay = nil
            guard case .region(let appKitRect) = result else { self.isCapturing = false; return }
            let rect = ScreenCoordinateMapper.current().cgRect(forAppKitRect: appKitRect) ?? appKitRect
            Task { [weak self] in
                guard let self else { return }; defer { self.isCapturing = false }
                do {
                    let result = try await scrollCoordinator.capture(region: rect, service: captureService, driver: AccessibilityScrollDriver(), maximumFrames: settings.scrollingMaxFrames, step: settings.scrollingStep) { [weak self] next in
                        Task { @MainActor in self?.scrollState = next }
                    }
                    let captured = CapturedImage(image: result.image, sourceRect: rect)
                    try route(captured, mode: .scrolling)
                    state = result.isPartial ? .degraded(reason: "Scrolling capture returned a clearly marked partial image.") : .running
                } catch { state = .degraded(reason: "Scrolling capture failed: \(error.localizedDescription)") }
            }
        }
    }

    public func stopScrollingCapture() { scrollCoordinator.cancel() }

    private func performCapture(_ request: ScreenCaptureRequest) {
        Task { [weak self] in
            guard let self else { return }
            defer { self.isCapturing = false }
            do {
                let captured = try await captureService.capture(request)
                try route(captured, mode: mode(for: request))
                lastCaptureSize = captured.pixelSize
                state = .running
            } catch let error as ScreenCaptureError {
                state = error == .permissionDenied ? .needsPermission(missing: [.screenRecording]) : .degraded(reason: error.localizedDescription)
            } catch {
                state = .degraded(reason: "Capture failed: \(error.localizedDescription)")
            }
        }
    }

    private func route(_ captured: CapturedImage, mode: ScreenshotCaptureMode) throws {
        archive(captured.image)
        switch settings.output(for: mode) {
        case .editor: openEditor(captured)
        case .copy:
            copy(captured.image)
            showCapturePreviewIfNeeded(captured)
        case .save:
            let directory = saveDirectory()
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            let url = nextSaveURL(in: directory)
            let rep = NSBitmapImageRep(cgImage: captured.image)
            let type: NSBitmapImageRep.FileType = settings.fileFormat == .png ? .png : .jpeg
            let properties: [NSBitmapImageRep.PropertyKey: Any] = settings.fileFormat == .jpeg ? [.compressionFactor: settings.jpegQuality] : [:]
            guard let data = rep.representation(using: type, properties: properties) else { throw ScreenCaptureError.captureFailed }
            try data.write(to: url, options: .atomic)
            lastSavedURL = url
            showCapturePreviewIfNeeded(captured)
        case .thumbnail:
            showThumbnail(captured)
        }
    }

    private func mode(for request: ScreenCaptureRequest) -> ScreenshotCaptureMode {
        switch request {
        case .region: return .region
        case .window: return .window
        case .display: return .display
        }
    }

    private func showCapturePreviewIfNeeded(_ captured: CapturedImage) {
        guard settings.showCapturePreview else { return }
        showThumbnail(captured)
    }

    private func openEditor(_ captured: CapturedImage) {
        let id = UUID()
        let controller = ScreenshotEditorWindowController(document: ScreenshotDocument(source: captured.image)) { [weak self] in
            self?.editors[id] = nil
        }
        editors[id] = controller
        controller.showWindow(nil)
        controller.window?.makeKeyAndOrderFront(nil)
    }

    private func showThumbnail(_ captured: CapturedImage) {
        let id = UUID()
        let controller = FloatingCaptureThumbnailController(
            image: captured.image,
            onEdit: { [weak self] in self?.openEditor(captured) },
            onPin: { [weak self] in self?.pin(captured.image) },
            onDismiss: { [weak self] in self?.thumbnails[id] = nil },
            dismissAfter: settings.thumbnailDuration
        )
        thumbnails[id] = controller
        controller.showWindow(nil)
    }

    private func pin(_ image: CGImage) {
        let id = UUID()
        let controller = PinnedImageController(image: image)
        pinnedImages[id] = controller
        controller.showWindow(nil)
        controller.window?.makeKeyAndOrderFront(nil)
        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: controller.window, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.pinnedImages[id] = nil }
        }
    }

    private func copy(_ image: CGImage) {
        pasteboard.clearContents()
        pasteboard.writeObjects([NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))])
    }

    private func archive(_ image: CGImage) {
        let representation = NSBitmapImageRep(cgImage: image)
        guard let data = representation.representation(using: .png, properties: [:]) else {
            logger.warning("Could not encode capture for File Shelf")
            return
        }
        captureArchive.publish(.png(data))
    }

    private func apply(settings candidate: ScreenshotStudioSettings) {
        let sanitized = ScreenshotStudioSettings.sanitized(candidate)
        let changed = sanitized.shortcuts != settings.shortcuts || sanitized.shortcutsEnabled != settings.shortcutsEnabled
        settings = sanitized; settingsStore.saveScreenshotStudioSettings(sanitized)
        if changed && state.isStarted { unregisterHotkeys(); registerHotkeys() }
    }

    private func registerHotkeys() {
        unregisterHotkeys()
        guard settings.shortcutsEnabled else { return }
        let duplicates = settings.duplicateShortcuts
        guard duplicates.isEmpty else { state = .degraded(reason: "Two Screenshot Studio actions use the same shortcut. Choose distinct shortcuts."); return }
        var registered: [ScreenshotCaptureMode: GlobalHotkey] = [:]
        for mode in ScreenshotCaptureMode.allCases {
            guard let definition = settings.shortcuts[mode] else { continue }
            let hotkey = GlobalHotkey(definition: definition) { [weak self] in self?.capture(mode) }
            do { try hotkey.register(); registered[mode] = hotkey }
            catch { registered.values.forEach { $0.unregister() }; state = .degraded(reason: "\(definition.displayString) is unavailable. Choose another shortcut."); return }
        }
        hotkeys = registered
    }
    private func unregisterHotkeys() { hotkeys.values.forEach { $0.unregister() }; hotkeys = [:] }
    private func subscribeToActivation() {
        guard activationObserver == nil else { return }
        activationObserver = NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.checkPermissionRecovery() }
        }
    }
    private func checkPermissionRecovery() {
        guard case .needsPermission = state, permissions.state(for: .screenRecording) == .granted else { return }
        registerHotkeys(); state = .running
    }
}
