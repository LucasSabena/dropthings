import AppKit
import SwiftUI
import DropThingsCore
import DropThingsDesignSystem
import DropThingsPlatform
import os

/// Floating drop-target shelf for files, folders, and text in transit. This
/// is the first real module built on top of Phase 0 — it owns an `NSPanel`,
/// receives drops from AppKit, parses them with `PasteboardItemReader`, and
/// keeps an in-memory list with dedup and a hard cap.
public final class FileShelfModule: DropThingsModule, ObservableObject {
    public let id = ModuleID.fileShelf
    public let name = "File Shelf"
    public let summary = "Drop files here. Pick them up in any app."
    public let requiredPermissions: [SystemPermission] = []

    @Published public private(set) var state: ModuleState = .off
    @Published public private(set) var items: [FileShelfItem] = []
    @Published public private(set) var isPanelVisible: Bool = false

    private let settingsStore: SettingsStore
    private var settings: FileShelfSettings
    private let logger = ModuleLogger(subsystem: "app.dropthings", category: "file-shelf")
    private let reader = PasteboardItemReader()
    private let persistence = ShelfPersistence.shared
    private var panel: ShelfPanel?
    private var contentView: ShelfContentView?
    private var hotkey: GlobalHotkey?
    private var mouseMonitor: MousePositionMonitor?
    private var shakeDetector = ShakeDetector()

    public init(settings: SettingsStore) {
        self.settingsStore = settings
        self.settings = settings.loadFileShelfSettings()
    }

    public func start() async throws {
        loadPinnedFromDisk()
        registerHotkey()
        if settings.shakeToShow {
            startShakeDetection()
        }
        if case .degraded = state {
            logger.notice("File Shelf started in degraded mode (hotkey conflict)")
        } else {
            state = .running
            logger.info("File Shelf started; \(self.items.count) items (\(self.pinnedCount) pinned)")
        }
    }

    public func stop() async {
        unregisterHotkey()
        stopShakeDetection()
        closePanel()
        savePinnedToDisk()
        if settings.clearOnQuit {
            items.removeAll()
        }
        state = .off
        logger.info("File Shelf stopped")
    }

    // MARK: - Hotkey

    private func registerHotkey() {
        guard let definition = settings.hotkey else { return }
        let hotkey = GlobalHotkey(definition: definition) { [weak self] in
            self?.handleHotkeyFire()
        }
        do {
            try hotkey.register()
            self.hotkey = hotkey
        } catch let error as GlobalHotkey.RegistrationError {
            let display = definition.displayString
            logger.warning("Could not register \(display): \(error)")
            switch error {
            case .installHandlerFailed(let status):
                state = .degraded(reason: "Hotkey installer failed (\(status)) for \(display). Use the menu bar instead.")
            case .registerFailed(let status):
                state = .degraded(reason: "\(display) is already taken by another app (Carbon error \(status)). Pick a different shortcut or use the menu bar.")
            }
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
        logger.info("Hotkey ⌥⌘S pressed")
        togglePanel()
    }

    // MARK: - Shake-to-show

    private func startShakeDetection() {
        let monitor = MousePositionMonitor { [weak self] location in
            guard let self else { return }
            self.processShakeSample(location: location)
        }
        monitor.start()
        mouseMonitor = monitor
        logger.notice("Shake-to-show armed (3 flips, 60pt min, 0.6s window). Move mouse left-right-left-right to test.")
    }

    private func stopShakeDetection() {
        mouseMonitor?.stop()
        mouseMonitor = nil
        shakeDetector.reset()
    }

    private func processShakeSample(location: CGPoint) {
        let sample = ShakeDetector.Sample(
            timestamp: Date().timeIntervalSinceReferenceDate,
            x: location.x
        )
        shakeDetector.record(sample)
        guard shakeDetector.shouldFire() else { return }
        shakeDetector.reset()
        logger.info("Shake detected at \(Int(location.x)),\(Int(location.y)), showing shelf")
        showPanel(near: location)
    }

    public func updateShakeToShow(_ enabled: Bool) {
        var new = settings
        new.shakeToShow = enabled
        applySettings(new)
        if enabled && mouseMonitor == nil && state == .running {
            startShakeDetection()
        } else if !enabled {
            stopShakeDetection()
        }
    }

    // MARK: - Settings surface

    public var itemsLimit: Int { settings.maxItems }
    public var clearOnQuit: Bool { settings.clearOnQuit }
    public var shakeToShow: Bool { settings.shakeToShow }
    public var fileShelfSettings: FileShelfSettings { settings }

    public func updateItemsLimit(_ value: Int) {
        var new = settings
        new.maxItems = FileShelfSettings.sanitized(
            maxItems: value,
            clearOnQuit: settings.clearOnQuit,
            shakeToShow: settings.shakeToShow,
            hotkey: settings.hotkey
        ).maxItems
        applySettings(new)
    }

    public func updateClearOnQuit(_ value: Bool) {
        var new = settings
        new.clearOnQuit = value
        applySettings(new)
    }

    private func applySettings(_ new: FileShelfSettings) {
        let hotkeyChanged = settings.hotkey != new.hotkey
        settings = new
        settingsStore.saveFileShelfSettings(new)
        if items.count > new.maxItems {
            items.removeFirst(items.count - new.maxItems)
        }
        if hotkeyChanged {
            unregisterHotkey()
            if state == .running {
                registerHotkey()
            }
        }
    }

    public func setHotkey(_ hotkey: GlobalHotkey.Definition?) {
        var new = settings
        new.hotkey = hotkey
        applySettings(new)
    }

    // MARK: - Panel

    public func showPanel(near location: CGPoint? = nil) {
        if panel == nil {
            createPanel()
        }
        guard let panel else { return }
        positionPanel(panel, near: location ?? NSEvent.mouseLocation)
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil as Any?)
        isPanelVisible = true
        logger.info("Shelf panel shown at \(panel.frame.origin.x), \(panel.frame.origin.y)")
    }

    private func positionPanel(_ panel: ShelfPanel, near location: CGPoint) {
        guard let screen = screen(containing: location) ?? NSScreen.main else { return }
        let visible = screen.visibleFrame
        let size = panel.frame.size
        let margin: CGFloat = 12
        let preferredOffset: CGFloat = 18
        var x = location.x + preferredOffset
        if x + size.width > visible.maxX - margin {
            x = location.x - size.width - preferredOffset
        }
        let y = location.y - size.height / 2
        panel.setFrameOrigin(NSPoint(
            x: Self.clamped(x, min: visible.minX + margin, max: visible.maxX - size.width - margin),
            y: Self.clamped(y, min: visible.minY + margin, max: visible.maxY - size.height - margin)
        ))
    }

    private func screen(containing point: CGPoint) -> NSScreen? {
        NSScreen.screens.first { screen in
            NSMouseInRect(point, screen.frame, false)
        }
    }

    private static func clamped(_ value: CGFloat, min lower: CGFloat, max upper: CGFloat) -> CGFloat {
        guard lower <= upper else { return lower }
        return Swift.min(Swift.max(value, lower), upper)
    }

    public func hidePanel() {
        panel?.orderOut(nil as Any?)
        isPanelVisible = false
    }

    public func togglePanel() {
        if let panel, panel.isVisible {
            hidePanel()
        } else {
            showPanel()
        }
    }

    // MARK: - Items

    public func clearItems() {
        guard !items.isEmpty else { return }
        items.removeAll()
        savePinnedToDisk()
        logger.info("Shelf cleared")
    }

    public func removeItem(id: String) {
        items.removeAll { $0.id == id }
        savePinnedToDisk()
    }

    // MARK: - Pin

    public var pinnedCount: Int {
        items.filter(\.isPinned).count
    }

    public func setPinned(_ id: String, pinned: Bool) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        let item = items[index]
        guard item.isPinned != pinned else { return }
        items[index] = item.pinning(pinned)
        savePinnedToDisk()
        logger.info("Item \(item.displayName) \(pinned ? "pinned" : "unpinned")")
    }

    public func clearUnpinned() {
        let before = items.count
        items.removeAll { !$0.isPinned }
        let removed = before - items.count
        if removed > 0 {
            logger.info("Cleared \(removed) unpinned item(s)")
        }
    }

    private func loadPinnedFromDisk() {
        let pinned = persistence.loadPinnedItems()
        guard !pinned.isEmpty else { return }
        var existingIds = Set(items.map(\.id))
        var restored = 0
        for pin in pinned {
            if !existingIds.contains(pin.id) {
                items.append(pin)
                existingIds.insert(pin.id)
                restored += 1
            }
        }
        if restored > 0 {
            logger.info("Restored \(restored) pinned item(s) from disk")
        }
    }

    private func savePinnedToDisk() {
        let pinned = items.filter(\.isPinned)
        do {
            try persistence.savePinnedItems(pinned)
        } catch {
            logger.error("Could not save pinned items: \(error)")
        }
    }

    /// Reveal a file/folder item in Finder. No-op for text items.
    public func revealInFinder(_ item: FileShelfItem) {
        guard let url = item.fileURL else {
            logger.notice("Reveal ignored: \(item.displayName) has no file URL")
            return
        }
        NSWorkspace.shared.activateFileViewerSelecting([url])
        logger.info("Revealed \(url.path) in Finder")
    }

    /// Copy the file path to the general pasteboard. No-op for text items.
    public func copyPath(_ item: FileShelfItem) {
        guard let url = item.fileURL else {
            logger.notice("Copy path ignored: \(item.displayName) has no file URL")
            return
        }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(url.path, forType: .string)
        logger.info("Copied path \(url.path) to pasteboard")
    }

    /// Build an `NSItemProvider` for a shelf item so the row can act as a
    /// drag source. Returns one provider; macOS advertises the right
    /// pasteboard types based on the wrapped object.
    public func dragItemProvider(for item: FileShelfItem) -> NSItemProvider {
        switch item.kind {
        case .file(let url), .folder(let url):
            return NSItemProvider(object: url as NSURL)
        case .text(let text):
            return NSItemProvider(object: text as NSString)
        }
    }

    /// Called from `ShelfContentView.performDragOperation`. Dedups, enforces
    /// the cap, and ensures the panel is visible so the user sees what landed.
    public func handleDrop(pasteboard: NSPasteboard) {
        let kinds = reader.read(from: pasteboard)
        guard !kinds.isEmpty else {
            logger.notice("Drop ignored: pasteboard had no supported items")
            return
        }
        ingest(kinds)
        showPanel()
    }

    private func ingest(_ kinds: [FileShelfItemKind]) {
        let existing = Set(items.map(\.id))
        var addedCount = 0
        for kind in kinds {
            let candidate = FileShelfItem(kind: kind)
            guard !existing.contains(candidate.id) else { continue }
            items.append(candidate)
            addedCount += 1
        }
        if items.count > settings.maxItems {
            // Trim from the unpinned end first so pinned items never get
            // pushed off by a flood of transient drops.
            let trimCount = items.count - settings.maxItems
            for _ in 0..<trimCount {
                if let lastUnpinned = items.lastIndex(where: { !$0.isPinned }) {
                    items.remove(at: lastUnpinned)
                } else {
                    items.removeFirst()
                }
            }
        }
        if addedCount > 0 {
            logger.info("Ingested \(addedCount) item(s); shelf size now \(self.items.count)")
        }
    }

    // MARK: - SwiftUI surface

    public func makeSettingsView() -> AnyView {
        AnyView(FileShelfSettingsView(module: self))
    }

    // MARK: - Internal

    private func createPanel() {
        let panel = ShelfPanel()
        let view = ShelfView(module: self)
        let content = ShelfContentView(rootView: AnyView(view))
        content.onDrop = { [weak self] pasteboard in
            self?.handleDrop(pasteboard: pasteboard)
        }
        panel.contentView = content
        self.contentView = content
        self.panel = panel
    }

    private func closePanel() {
        contentView?.onDrop = nil
        contentView = nil
        panel?.contentView = nil
        panel?.orderOut(nil as Any?)
        panel = nil
        isPanelVisible = false
    }
}
