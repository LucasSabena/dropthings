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
    @Published public private(set) var isPanelVisible: Bool = false
    @Published public private(set) var selectedItemIDs: Set<String> = []

    /// All shelf collections (tabs). The source of truth; `items` is a
    /// computed view over the active collection so the rest of the module
    /// and the UI keep working without knowing about collections.
    @Published public private(set) var collections: [ShelfCollection] = []
    @Published public private(set) var activeCollectionID: String?

    /// The collection currently being renamed, if any. Drives an inline
    /// text field in the tab bar; `nil` means no rename in progress.
    @Published public private(set) var renamingID: String?

    /// Items of the currently active collection, in storage order. The
    /// selection logic and views read this; mutations go through
    /// `mutateActiveItems` so they always land in the right collection.
    public var items: [FileShelfItem] {
        activeCollection?.items ?? []
    }

    /// One-tap entry point from the menu bar.
    public var primaryAction: ModulePrimaryAction? {
        ModulePrimaryAction(
            title: "Show File Shelf",
            iconName: iconName,
            action: { [weak self] in
                Task { @MainActor [weak self] in
                    self?.showPanel()
                }
            }
        )
    }

    /// The collection the user is currently looking at.
    public var activeCollection: ShelfCollection? {
        guard let id = activeCollectionID else {
            return collections.first
        }
        return collections.first { $0.id == id } ?? collections.first
    }

    /// Applies `transform` to the active collection's items in place and
    /// publishes the change. Every item mutation routes through here so the
    /// collections model stays the single source of truth.
    private func mutateActiveItems(_ transform: (inout [FileShelfItem]) -> Void) {
        guard let id = activeCollectionID ?? collections.first?.id else { return }
        guard let index = collections.firstIndex(where: { $0.id == id }) else { return }
        transform(&collections[index].items)
    }

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
    private var flickDetector = FlickDetector()
    private let ingestCoordinator = ShelfIngestCoordinator(
        downloader: WebItemDownloader(),
        imageSaver: ImageSaver()
    )

    /// One-line ingest error surfaced to the UI so a failed browser drop
    /// is never silent. Cleared on the next successful ingest.
    @Published public private(set) var ingestError: String?

    public init(settings: SettingsStore) {
        self.settingsStore = settings
        self.settings = settings.loadFileShelfSettings()
    }

    public func start() async throws {
        loadPinnedFromDisk()
        ensureDefaultCollection()
        registerHotkey()
        if settings.shakeToShow || settings.flickToShow {
            startGestureDetection()
        }
        if case .degraded = state {
            logger.notice("File Shelf started in degraded mode (hotkey conflict)")
        } else {
            state = .running
            logger.info("File Shelf started; \(self.collections.count) collection(s), \(self.items.count) items in active (\(self.pinnedCount) pinned)")
        }
    }

    public func stop() async {
        unregisterHotkey()
        stopGestureDetection()
        closePanel()
        savePinnedToDisk()
        if settings.clearOnQuit {
            for index in collections.indices {
                collections[index].items.removeAll()
            }
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

    // MARK: - Gesture detection (shake + flick)

    /// One cooldown window after any gesture fires so a single motion
    /// cannot double-trigger. Half a second is long enough to feel
    /// deliberate, short enough to allow a follow-up.
    private var lastGestureFire: Date?
    private static let gestureCooldown: TimeInterval = 0.5

    private func startGestureDetection() {
        let monitor = MousePositionMonitor { [weak self] location in
            guard let self else { return }
            self.processGestureSample(location: location)
        }
        monitor.start()
        mouseMonitor = monitor
        logger.notice("Gesture detection armed (shake=\(self.settings.shakeToShow), flick=\(self.settings.flickToShow)).")
    }

    private func stopGestureDetection() {
        mouseMonitor?.stop()
        mouseMonitor = nil
        shakeDetector.reset()
        flickDetector.reset()
    }

    private func processGestureSample(location: CGPoint) {
        // Cooldown guard shared by both gestures.
        if let last = lastGestureFire, Date().timeIntervalSince(last) < Self.gestureCooldown {
            return
        }
        let now = Date().timeIntervalSinceReferenceDate

        // Shake (any orientation via dominant axis).
        if settings.shakeToShow {
            let sample = ShakeDetector.Sample(timestamp: now, x: location.x, y: location.y)
            shakeDetector.record(sample)
            if shakeDetector.shouldFire() {
                shakeDetector.reset()
                lastGestureFire = Date()
                logger.info("Shake detected at \(Int(location.x)),\(Int(location.y)); showing shelf near pointer")
                showPanel(near: location)
                return
            }
        }

        // Flick up to the top of the screen → drop from the notch.
        if settings.flickToShow, let screen = screen(containing: location) {
            let sample = FlickDetector.Sample(
                timestamp: now,
                y: location.y,
                ceilingY: screen.frame.maxY
            )
            flickDetector.record(sample)
            if flickDetector.shouldFire() {
                flickDetector.reset()
                lastGestureFire = Date()
                logger.info("Flick detected at top of screen; showing shelf from notch")
                showPanelFromNotch(on: screen)
                return
            }
        }
    }

    public func updateShakeToShow(_ enabled: Bool) {
        var new = settings
        new.shakeToShow = enabled
        applySettings(new)
        reconcileGestureMonitor()
    }

    public func updateFlickToShow(_ enabled: Bool) {
        var new = settings
        new.flickToShow = enabled
        applySettings(new)
        reconcileGestureMonitor()
    }

    /// Start the shared monitor only when at least one gesture is on;
    /// stop it when neither is, so we never poll the mouse for nothing.
    private func reconcileGestureMonitor() {
        let anyOn = settings.shakeToShow || settings.flickToShow
        if anyOn && mouseMonitor == nil && state == .running {
            startGestureDetection()
        } else if !anyOn {
            stopGestureDetection()
        }
    }

    // MARK: - Settings surface

    public var itemsLimit: Int { settings.maxItems }
    public var clearOnQuit: Bool { settings.clearOnQuit }
    public var shakeToShow: Bool { settings.shakeToShow }
    public var flickToShow: Bool { settings.flickToShow }
    public var shakeSensitivity: ShakeSensitivity { settings.shakeSensitivity }
    public var layout: ShelfLayout { settings.layout }
    public var fileShelfSettings: FileShelfSettings { settings }

    /// Clear the last ingest error banner.
    public func dismissIngestError() {
        ingestError = nil
    }

    public func updateItemsLimit(_ value: Int) {
        var new = settings
        new.maxItems = FileShelfSettings.sanitized(
            maxItems: value,
            clearOnQuit: settings.clearOnQuit,
            shakeToShow: settings.shakeToShow,
            flickToShow: settings.flickToShow,
            shakeSensitivity: settings.shakeSensitivity,
            layout: settings.layout,
            hotkey: settings.hotkey
        ).maxItems
        applySettings(new)
    }

    public func updateClearOnQuit(_ value: Bool) {
        var new = settings
        new.clearOnQuit = value
        applySettings(new)
    }

    public func setLayout(_ layout: ShelfLayout) {
        var new = settings
        new.layout = layout
        applySettings(new)
    }

    public func setShakeSensitivity(_ sensitivity: ShakeSensitivity) {
        var new = settings
        new.shakeSensitivity = sensitivity
        applySettings(new)
        // Rebuild the live detector so the new thresholds take effect now.
        if shakeDetector.sensitivity != sensitivity {
            shakeDetector = ShakeDetector(sensitivity: sensitivity)
        }
    }

    private func applySettings(_ new: FileShelfSettings) {
        let hotkeyChanged = settings.hotkey != new.hotkey
        settings = new
        settingsStore.saveFileShelfSettings(new)
        if items.count > new.maxItems {
            mutateActiveItems { $0 = Self.trimmed($0, maxItems: new.maxItems) }
        }
        if hotkeyChanged {
            unregisterHotkey()
            // Re-register even when the module is `.degraded` from an
            // earlier hotkey conflict — the user is trying a new combo
            // precisely to recover. We only skip modules that are off
            // or still waiting on a permission grant.
            if state.isStarted {
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

    /// Summon the shelf so it drops down from the top center of `screen`
    /// (under the notch / menu bar), with a short slide animation. This is
    /// the payoff for the flick gesture: throw the mouse to the top, the
    /// shelf appears where the eye already is.
    public func showPanelFromNotch(on screen: NSScreen) {
        if panel == nil {
            createPanel()
        }
        guard let panel else { return }
        NSApp.activate(ignoringOtherApps: true)
        let size = panel.frame.size
        let visible = screen.visibleFrame
        // Centered horizontally, just below the menu bar / notch.
        let finalX = visible.midX - size.width / 2
        let finalY = visible.maxY - size.height - Self.notchTopGap
        let finalFrame = NSRect(x: finalX, y: finalY, width: size.width, height: size.height)

        // Animate a short drop from just above the final position.
        let startY = visible.maxY + size.height
        panel.setFrame(NSRect(x: finalX, y: startY, width: size.width, height: size.height), display: false)
        panel.makeKeyAndOrderFront(nil as Any?)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.22
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().setFrame(finalFrame, display: true)
        }
        isPanelVisible = true
        logger.info("Shelf panel dropped from notch at \(finalX), \(finalY)")
    }

    /// Pixels to leave between the shelf's top edge and the visible top of
    /// the screen, so it sits under the menu bar rather than glued to it.
    private static let notchTopGap: CGFloat = 6

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
        guard !(activeCollection?.items.isEmpty ?? true) else { return }
        mutateActiveItems { $0.removeAll() }
        savePinnedToDisk()
        logger.info("Shelf cleared")
    }

    public func removeItem(id: String) {
        mutateActiveItems { $0.removeAll { $0.id == id } }
        selectedItemIDs.remove(id)
        savePinnedToDisk()
    }

    // MARK: - Selection

    /// Items currently selected, in display order (matches `sortedItems`).
    public var selectedItems: [FileShelfItem] {
        let ordered = ShelfDisplayOrder.sort(items)
        return ordered.filter { selectedItemIDs.contains($0.id) }
    }

    /// Plain click (no modifier): select only this item.
    /// ⌘-click: toggle this item in the selection.
    /// ⇧-click: select a range from the anchor to this item.
    public func handleSelect(id: String, command: Bool, shift: Bool) {
        let ordered = ShelfDisplayOrder.sort(items).map(\.id)
        if shift, let anchor = selectionAnchor {
            selectedItemIDs = Set(Self.range(from: anchor, to: id, in: ordered))
            return
        }
        if command {
            if selectedItemIDs.contains(id) {
                selectedItemIDs.remove(id)
            } else {
                selectedItemIDs.insert(id)
            }
            selectionAnchor = id
            return
        }
        selectedItemIDs = [id]
        selectionAnchor = id
    }

    public func clearSelection() {
        selectedItemIDs.removeAll()
        selectionAnchor = nil
    }

    /// The id from which a ⇧-click range extends. Reset on plain click.
    private var selectionAnchor: String?

    /// Pure range helper: returns the set of ids spanning from `anchor` to
    /// `target` in `ordered` (inclusive on both ends). Exposed as static so
    /// the shift-click semantics are unit-testable without UI state.
    nonisolated static func range(from anchor: String, to target: String, in ordered: [String]) -> Set<String> {
        guard let a = ordered.firstIndex(of: anchor),
              let b = ordered.firstIndex(of: target) else {
            return [target]
        }
        let lower = Swift.min(a, b)
        let upper = Swift.max(a, b)
        return Set(ordered[lower...upper])
    }

    // MARK: - Batch actions on selection

    /// Remove every selected item. No-op when nothing is selected.
    public func removeSelected() {
        guard !selectedItemIDs.isEmpty else { return }
        mutateActiveItems { $0.removeAll { selectedItemIDs.contains($0.id) } }
        selectedItemIDs.removeAll()
        selectionAnchor = nil
        savePinnedToDisk()
    }

    /// Reveal every selected file/folder in Finder. Text items are skipped.
    public func revealSelected() {
        let urls = selectedItems.compactMap(\.fileURL)
        guard !urls.isEmpty else { return }
        NSWorkspace.shared.activateFileViewerSelecting(urls)
    }

    /// Copy the paths of every selected file/folder to the pasteboard,
    /// one path per line.
    public func copyPathsSelected() {
        let paths = selectedItems.compactMap(\.fileURL).map(\.path)
        guard !paths.isEmpty else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(paths.joined(separator: "\n"), forType: .string)
    }

    // MARK: - Collections (tabs)

    /// Add a fresh collection and make it active. The name is auto-picked
    /// so it never collides with an existing tab.
    public func addCollection() {
        let existingNames = collections.map(\.name)
        let collection = ShelfCollection.newDefault(existingNames: existingNames)
        collections.append(collection)
        activeCollectionID = collection.id
        selectedItemIDs.removeAll()
        selectionAnchor = nil
        logger.info("Added collection '\(collection.name)'")
    }

    /// Rename the active collection. No-op when the name is empty.
    public func renameActiveCollection(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let id = activeCollectionID,
              let index = collections.firstIndex(where: { $0.id == id }) else { return }
        collections[index].name = trimmed
    }

    /// Remove the active collection. Keeps at least one tab: if this is
    /// the last one, it is cleared instead of deleted.
    public func removeActiveCollection() {
        guard let id = activeCollectionID else { return }
        if collections.count <= 1 {
            mutateActiveItems { $0.removeAll() }
            savePinnedToDisk()
            return
        }
        collections.removeAll { $0.id == id }
        activeCollectionID = collections.first?.id
        selectedItemIDs.removeAll()
        selectionAnchor = nil
        savePinnedToDisk()
        logger.info("Removed collection \(id)")
    }

    /// Switch the active tab. No-op if the id is unknown.
    public func selectCollection(id: String) {
        guard collections.contains(where: { $0.id == id }) else { return }
        activeCollectionID = id
        selectedItemIDs.removeAll()
        selectionAnchor = nil
    }

    /// Start an inline rename of the given collection.
    public func beginRename(id: String) {
        guard collections.contains(where: { $0.id == id }) else { return }
        renamingID = id
    }

    /// Commit a rename. `newName` empty cancels the rename without changes.
    public func commitRename(_ newName: String) {
        guard let id = renamingID else { return }
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty,
           let index = collections.firstIndex(where: { $0.id == id }) {
            collections[index].name = trimmed
        }
        renamingID = nil
    }

    /// Cancel an in-progress rename.
    public func cancelRename() {
        renamingID = nil
    }

    public var pinnedCount: Int {
        (activeCollection?.items ?? []).filter(\.isPinned).count
    }

    public func setPinned(_ id: String, pinned: Bool) {
        var changed = false
        mutateActiveItems { items in
            guard let index = items.firstIndex(where: { $0.id == id }) else { return }
            guard items[index].isPinned != pinned else { return }
            items[index] = items[index].pinning(pinned)
            changed = true
        }
        guard changed else { return }
        savePinnedToDisk()
        logger.info("Item \(id) \(pinned ? "pinned" : "unpinned")")
    }

    public func clearUnpinned() {
        let before = activeCollection?.items.count ?? 0
        mutateActiveItems { $0.removeAll { !$0.isPinned } }
        let removed = before - (activeCollection?.items.count ?? 0)
        if removed > 0 {
            logger.info("Cleared \(removed) unpinned item(s)")
        }
    }

    private func loadPinnedFromDisk() {
        let loaded = persistence.loadCollections()
        guard !loaded.isEmpty else { return }
        // Preserve any in-memory collections (e.g. a fresh empty default)
        // by merging: on-disk collections seed the list; an existing
        // in-memory collection with the same id keeps its identity but
        // adopts the loaded pinned items.
        var existing = collections
        for loadedCollection in loaded {
            if let index = existing.firstIndex(where: { $0.id == loadedCollection.id }) {
                let memoryItems = existing[index].items
                let memoryIds = Set(memoryItems.map(\.id))
                let merged = memoryItems + loadedCollection.items.filter { !memoryIds.contains($0.id) }
                existing[index].items = merged
            } else {
                existing.append(loadedCollection)
            }
        }
        collections = existing
        if activeCollectionID == nil { activeCollectionID = collections.first?.id }
        let restored = loaded.flatMap(\.items).count
        if restored > 0 {
            logger.info("Restored \(restored) pinned item(s) from disk across \(loaded.count) collection(s)")
        }
    }

    private func savePinnedToDisk() {
        // Persist every collection's pinned items. Unpinned items stay
        // session-only, exactly as before the collections change.
        let toSave = collections.map { collection in
            ShelfCollection(
                id: collection.id,
                name: collection.name,
                items: collection.items.filter(\.isPinned),
                createdAt: collection.createdAt
            )
        }
        do {
            try persistence.saveCollections(toSave)
            if case .degraded = state {
                state = .running
            }
        } catch {
            logger.error("Could not save pinned items: \(error)")
            state = .degraded(reason: "Could not save pinned items to disk: \(error.localizedDescription). Pinned items will be lost when the app quits.")
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

    /// Provider for a drag that starts on `item`. When `item` is part of
    /// the current selection, the drag carries *all* selected items so the
    /// user can drop a whole batch into another app at once. When it is
    /// not selected, the drag carries just that single item (and the
    /// selection is narrowed to it, matching Finder behavior).
    public func dragItemProviderForDrag(from item: FileShelfItem) -> NSItemProvider {
        let dragging: [FileShelfItem]
        if selectedItemIDs.contains(item.id) {
            dragging = selectedItems
        } else {
            // Dragging an unselected item narrows selection to it.
            selectedItemIDs = [item.id]
            selectionAnchor = item.id
            dragging = [item]
        }
        return Self.itemProvider(for: dragging)
    }

    /// Builds a single `NSItemProvider` that advertises every item. For
    /// a single item it wraps that item directly; for many it uses
    /// `NSItemProvider(loadingItem:)`-style multi-attachment via a
    /// `suggestedName` and registered objects. URLs and strings both
    /// conform to `NSItemProviderWriting`, so we register one provider
    /// per item and rely on the system pasteboard to multiplex them at
    /// drag time through the row's `.onDrag`.
    nonisolated static func itemProvider(for items: [FileShelfItem]) -> NSItemProvider {
        guard let first = items.first else { return NSItemProvider() }
        if items.count == 1 {
            switch first.kind {
            case .file(let url), .folder(let url):
                return NSItemProvider(object: url as NSURL)
            case .text(let text):
                return NSItemProvider(object: text as NSString)
            }
        }
        // Multi-item: attach every writable object to the same provider.
        let provider = NSItemProvider()
        for item in items {
            switch item.kind {
            case .file(let url), .folder(let url):
                provider.registerObject(url as NSURL, visibility: .all)
            case .text(let text):
                provider.registerObject(text as NSString, visibility: .all)
            }
        }
        return provider
    }

    /// Called from `ShelfContentView.performDragOperation`. Reads rich
    /// candidates so a browser image drop is downloaded to disk (not just
    /// kept as a URL), resolves them via the ingest coordinator, then
    /// dedups/caps and shows the panel. Failures set `ingestError` instead
    /// of disappearing.
    public func handleDrop(pasteboard: NSPasteboard) {
        let candidates = reader.candidates(from: pasteboard)
        guard !candidates.isEmpty else {
            logger.notice("Drop ignored: pasteboard had no supported items")
            return
        }
        showPanel()
        Task { @MainActor [weak self] in
            await self?.resolveAndIngest(candidates)
        }
    }

    /// Resolves each candidate (downloading/saving as needed) and ingests
    /// the resulting kinds in one batch.
    @MainActor
    private func resolveAndIngest(_ candidates: [PasteboardCandidate]) async {
        var kinds: [FileShelfItemKind] = []
        var failures: [String] = []
        for candidate in candidates {
            let outcome = await ingestCoordinator.resolve(candidate) { _ in }
            switch outcome {
            case .item(let kind):
                kinds.append(kind)
            case .failed(let url, let error):
                let what = url?.lastPathComponent ?? "item"
                failures.append("\(what): \(error.localizedDescription)")
                logger.warning("Ingest failed for \(what): \(error)")
            }
        }
        if !kinds.isEmpty {
            ingest(kinds)
            ingestError = nil
        }
        if !failures.isEmpty {
            ingestError = "Could not add \(failures.count) item(s): " + failures.joined(separator: "; ")
        }
    }

    private func ingest(_ kinds: [FileShelfItemKind]) {
        ensureDefaultCollection()
        let original = Set(items.map(\.id))
        let merged = Self.merged(items, with: kinds, maxItems: settings.maxItems)
        mutateActiveItems { $0 = merged }
        let added = merged.filter { !original.contains($0.id) }.count
        if added > 0 {
            logger.info("Ingested \(added) item(s); shelf size now \(merged.count)")
        }
    }

    /// Make sure there is at least one collection to drop into. A fresh
    /// install starts with one default-named collection.
    private func ensureDefaultCollection() {
        guard collections.isEmpty else { return }
        let collection = ShelfCollection(name: ShelfCollection.defaultName)
        collections = [collection]
        activeCollectionID = collection.id
    }

    /// Pure merge + cap logic. Dedups by `FileShelfItem.id`, then trims from
    /// the unpinned end first so pinned items never get pushed off by a
    /// flood of transient drops. Exposed as `static` so the trimming
    /// strategy is unit-testable without a live pasteboard. `nonisolated`
    /// because it touches no instance state.
    nonisolated static func merged(
        _ items: [FileShelfItem],
        with kinds: [FileShelfItemKind],
        maxItems: Int
    ) -> [FileShelfItem] {
        var result = items
        let existing = Set(result.map(\.id))
        for kind in kinds {
            let candidate = FileShelfItem(kind: kind)
            guard !existing.contains(candidate.id) else { continue }
            result.append(candidate)
        }
        return Self.trimmed(result, maxItems: maxItems)
    }

    /// Pure cap enforcement: trims unpinned items from the end first; only
    /// falls back to removing the oldest item when every item is pinned.
    nonisolated static func trimmed(_ items: [FileShelfItem], maxItems: Int) -> [FileShelfItem] {
        guard items.count > maxItems else { return items }
        var result = items
        let trimCount = result.count - maxItems
        for _ in 0..<trimCount {
            if let lastUnpinned = result.lastIndex(where: { !$0.isPinned }) {
                result.remove(at: lastUnpinned)
            } else {
                result.removeFirst()
            }
        }
        return result
    }

    // MARK: - SwiftUI surface

    public func makeSettingsView() -> AnyView {
        AnyView(FileShelfSettingsView(module: self))
    }

    /// Test-only hook to seed items without going through the AppKit drop
    /// path. `internal` so it is visible to `@testable import` but never
    /// reaches the public module surface that callers depend on.
    internal func setItemsForTesting(_ newItems: [FileShelfItem]) {
        ensureDefaultCollection()
        mutateActiveItems { $0 = newItems }
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
