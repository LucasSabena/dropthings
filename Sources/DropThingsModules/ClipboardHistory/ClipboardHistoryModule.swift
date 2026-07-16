import AppKit
import Combine
import SwiftUI
import DropThingsCore
import DropThingsDesignSystem
import DropThingsPlatform
import os

/// Keeps a rolling, searchable, on-device history of copied content. The
/// history survives app restarts and bundle replacement, while age, count and
/// image-storage limits keep disk use bounded.
public final class ClipboardHistoryModule: DropThingsModule {
    public let id = ModuleID.clipboardHistory
    public let name = "Clipboard History"
    public let summary = "Searchable history of copied text and files."
    public let requiredPermissions: [SystemPermission] = []

    @Published public private(set) var state: ModuleState = .off
    @Published public private(set) var settings: ClipboardHistorySettings
    @Published public internal(set) var items: [ClipboardItem] = []
    @Published public private(set) var storageBytes: Int64 = 0
    @Published public private(set) var omittedImageCount: Int = 0
    @Published public private(set) var persistenceError: String?

    private let settingsStore: SettingsStore
    private let monitor: ClipboardMonitor
    private let hub: PasteboardHub?
    private let origin = PasteboardHub.OriginToken("modules.clipboard-history")
    private var hubSubscription: PasteboardHub.Subscription?
    private let persistence: any ClipboardHistoryPersisting
    private let transientSurfaces: TransientSurfaceCoordinator?
    private var hotkey: GlobalHotkey?
    private var hotkeyHealth = HotkeyRegistrationHealth()
    private var panel: ClipboardHistoryPanelController?
    private var persistenceTask: Task<Void, Never>?
    private let logger = ModuleLogger(subsystem: "app.dropthings", category: "clipboard-history")

    public convenience init(
        settings: SettingsStore,
        permissions: PermissionCenter,
        transientSurfaces: TransientSurfaceCoordinator? = nil
    ) {
        self.init(
            settings: settings,
            persistence: ClipboardHistoryStore.live(),
            hub: PasteboardHub(backend: ClipboardMonitor()),
            transientSurfaces: transientSurfaces
        )
    }

    /// Compose with an externally owned hub so Clipboard History and Smart
    /// Clipboard share a single pasteboard observer. `permissions` is kept in
    /// the signature to preserve source compatibility with the existing
    /// convenience initializer.
    public convenience init(
        settings: SettingsStore,
        permissions: PermissionCenter,
        hub: PasteboardHub,
        transientSurfaces: TransientSurfaceCoordinator? = nil
    ) {
        self.init(
            settings: settings,
            persistence: ClipboardHistoryStore.live(),
            hub: hub,
            transientSurfaces: transientSurfaces
        )
    }

    internal init(
        settings: SettingsStore,
        persistence: any ClipboardHistoryPersisting,
        hub: PasteboardHub? = nil,
        transientSurfaces: TransientSurfaceCoordinator? = nil
    ) {
        self.settingsStore = settings
        self.persistence = persistence
        self.transientSurfaces = transientSurfaces
        let loadedSettings = settings.loadClipboardHistorySettings()
        self.settings = loadedSettings
        self.items = loadedSettings.pinnedItems
        let monitor = ClipboardMonitor()
        self.monitor = monitor
        self.hub = hub
        let panel = ClipboardHistoryPanelController(module: self)
        self.panel = panel
        monitor.handler = { [weak self] item in
            Task { @MainActor [weak self] in
                self?.handleClipboardItem(item)
            }
        }
    }

    public func start() async throws {
        transientSurfaces?.register(id) { [weak self] in self?.hideHistoryPanel() }
        await restorePersistentHistory()
        registerHotkey()
        if let hub {
            // Shared observer: subscribe and let the hub own the single poller.
            hubSubscription?.cancel()
            hubSubscription = hub.subscribe(origin: origin) { [weak self] snapshot in
                guard let self else { return }
                self.handleClipboardSnapshot(snapshot)
            }
            hub.start(interval: 0.25)
        } else {
            monitor.start(interval: 0.25)
        }
        if case .degraded = state {} else { state = .running }
        logger.info("Clipboard History started")
    }

    public func stop() async {
        transientSurfaces?.unregister(id)
        persistenceTask?.cancel()
        persistenceTask = nil
        await persist(items)
        unregisterHotkey()
        hubSubscription?.cancel()
        hubSubscription = nil
        monitor.stop()
        panel?.hide()
        state = .off
        logger.info("Clipboard History stopped")
    }

    /// One-tap entry point from the menu bar.
    public var primaryAction: ModulePrimaryAction? {
        ModulePrimaryAction(
            title: "Open Clipboard History",
            iconName: iconName,
            action: { [weak self] in
                Task { @MainActor [weak self] in
                    self?.showHistoryPanel()
                }
            }
        )
    }

    public var commands: [CommandDescriptor] {
        [
            CommandDescriptor(
                id: "clipboard-history.open",
                title: "Open Clipboard History",
                subtitle: name,
                iconName: iconName,
                action: { [weak self] in
                    Task { @MainActor [weak self] in self?.showHistoryPanel() }
                }
            ),
            CommandDescriptor(
                id: "clipboard-history.incognito",
                title: settings.incognito ? "Resume Clipboard Recording" : "Pause Clipboard Recording",
                subtitle: name,
                iconName: settings.incognito ? "eye" : "eye.slash",
                action: { [weak self] in
                    Task { @MainActor [weak self] in self?.toggleIncognito() }
                }
            )
        ]
    }

    // MARK: - Public actions

    public func showHistoryPanel() {
        transientSurfaces?.prepareToPresent(id)
        panel?.show()
    }

    public func hideHistoryPanel() {
        panel?.hide()
    }

    public func toggleHistoryPanel() {
        if panel?.isVisible == true {
            hideHistoryPanel()
        } else {
            showHistoryPanel()
        }
    }

    public func toggleIncognito() {
        var new = settings
        new.incognito.toggle()
        applySettings(new)
        logger.notice("Incognito mode \(new.incognito ? "enabled" : "disabled")")
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

    public func setMaxHistory(_ maxHistory: Int) {
        var new = settings
        new.maxHistory = maxHistory
        applySettings(new)
    }

    public func setPasteOnEnter(_ enabled: Bool) {
        var new = settings
        new.pasteOnEnter = enabled
        applySettings(new)
    }

    public func setRetentionDays(_ days: Int) {
        var new = settings
        new.retentionDays = days
        applySettings(new)
    }

    public func setMaxStorageMB(_ megabytes: Int) {
        var new = settings
        new.maxStorageMB = megabytes
        applySettings(new)
    }

    // MARK: - Paste / copy actions

    /// Copy an item to the pasteboard without closing the panel. Bound to `C`.
    public func copyItem(_ item: ClipboardItem) {
        copyToPasteboard(item)
    }

    /// The primary action (Enter). When `pasteOnEnter` is on and Accessibility
    /// is granted, this copies the item, hides the panel, reactivates the app
    /// that had focus, and synthesizes ⌘V so it lands at the cursor. When the
    /// permission is missing or the feature is off, it falls back to copying
    /// and surfaces what happened via the returned result so the UI can show a
    /// hint instead of failing silently.
    @discardableResult
    public func pasteOrCopy(_ item: ClipboardItem) -> PasteResult {
        copyToPasteboard(item)
        guard settings.pasteOnEnter else {
            return .copiedOnly
        }
        guard KeystrokeSynthesizer.isAccessibilityGranted() else { return .needsAccessibility }
        panel?.hide()
        panel?.reactivatePreviousApp()
        // Small delay so the target app is frontmost before we post the key.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            KeystrokeSynthesizer.postPaste()
        }
        return .pasted
    }

    public enum PasteResult: Sendable {
        case pasted
        case copiedOnly
        case needsAccessibility
    }

    public func addExcludedBundleID(_ bundleID: String) {
        var new = settings
        if !new.excludedBundleIDs.contains(bundleID) {
            new.excludedBundleIDs.append(bundleID)
        }
        applySettings(new)
    }

    public func removeExcludedBundleID(_ bundleID: String) {
        var new = settings
        new.excludedBundleIDs.removeAll { $0 == bundleID }
        applySettings(new)
    }

    public func copyToPasteboard(_ item: ClipboardItem) {
        let pb = NSPasteboard.general
        hub?.recordWrite(origin: origin)
        pb.clearContents()
        switch item.type {
        case .plainText:
            pb.setString(item.content, forType: .string)
        case .url:
            if let url = URL(string: item.content) {
                pb.writeObjects([url as NSPasteboardWriting])
            } else {
                pb.setString(item.content, forType: .string)
            }
        case .filePath:
            if let url = item.fileURL { pb.writeObjects([url as NSPasteboardWriting]) }
        case .folder, .video, .audio:
            if let url = item.fileURL { pb.writeObjects([url as NSPasteboardWriting]) }
        case .image:
            if let url = item.fileURL {
                pb.writeObjects([url as NSPasteboardWriting])
            } else if let image = item.nsImage {
                pb.writeObjects([image as NSPasteboardWriting])
            }
        case .color:
            if let color = item.nsColor {
                pb.writeObjects([color as NSPasteboardWriting])
            }
            // Always also expose the hex string so plain-text paste targets work.
            pb.setString(item.content, forType: .string)
        }
        logger.notice("Copied history item \(item.id) to pasteboard")
    }

    public func togglePin(_ itemID: UUID) {
        guard let index = items.firstIndex(where: { $0.id == itemID }) else { return }
        items[index].isPinned.toggle()
        if items[index].isPinned {
            items[index].isFavorite = false
        }
        persistPinnedAndTrim()
    }

    public func toggleFavorite(_ itemID: UUID) {
        guard let index = items.firstIndex(where: { $0.id == itemID }) else { return }
        items[index].isFavorite.toggle()
        if items[index].isFavorite {
            items[index].isPinned = true
        }
        persistPinnedAndTrim()
    }

    public func remove(_ itemID: UUID) {
        items.removeAll { $0.id == itemID }
        persistPinnedAndTrim()
    }

    public func clearUnpinned() {
        items.removeAll { !$0.isPinned }
        schedulePersistence()
    }

    // MARK: - SwiftUI surface

    public func makeSettingsView() -> AnyView {
        AnyView(ClipboardHistorySettingsView(module: self))
    }

    // MARK: - Pasteboard handling

    private func handleClipboardItem(_ monitorItem: ClipboardMonitor.Item) {
        guard state.isStarted else { return }
        guard !settings.incognito else { return }
        guard !monitorItem.isTransient, !monitorItem.isConcealed else {
            logger.notice("Ignored transient/concealed pasteboard change")
            return
        }
        if let bundleID = monitorItem.sourceBundleID,
           settings.excludedBundleIDs.contains(bundleID) {
            logger.notice("Ignored pasteboard change from excluded app \(bundleID)")
            return
        }

        let candidates: [ClipboardItem] = buildItems(from: monitorItem)
        for candidate in candidates {
            add(candidate)
        }
        schedulePersistence()
    }

    /// Hub path: rebuild the monitor item from a Foundation-only snapshot and
    /// reuse the existing handler so behavior is identical to the legacy
    /// direct-observer path.
    private func handleClipboardSnapshot(_ snapshot: PasteboardHub.Snapshot) {
        let item = ClipboardMonitor.Item(
            text: snapshot.text,
            url: snapshot.url,
            fileURLs: snapshot.fileURLs,
            imageData: snapshot.imageData,
            colorHex: snapshot.colorHex,
            isTransient: snapshot.isTransient,
            isConcealed: snapshot.isConcealed,
            sourceBundleID: snapshot.sourceBundleID
        )
        handleClipboardItem(item)
    }

    private func buildItems(from monitorItem: ClipboardMonitor.Item) -> [ClipboardItem] {
        var results: [ClipboardItem] = []
        let source = monitorItem.sourceBundleID

        // Real URLs take priority over co-published TIFF icons. This preserves
        // folders, videos, and image files as draggable/openable file entries.
        if !monitorItem.fileURLs.isEmpty {
            return monitorItem.fileURLs.map { url in
                let info = FileContentInfo.inspect(url)
                let type: ClipboardItemType
                switch info.kind {
                case .folder: type = .folder
                case .image: type = .image
                case .video: type = .video
                case .audio: type = .audio
                default: type = .filePath
                }
                return ClipboardItem(type: type, content: url.path, sourceBundleID: source)
            }
        }

        // A raw screenshot/image has no useful string form.
        if let data = monitorItem.imageData {
            results.append(ClipboardItem(type: .image, content: "Image", imageData: data, sourceBundleID: source))
            return results
        }

        // Colors: store as hex so they survive as a plain, comparable string.
        if let hex = monitorItem.colorHex {
            results.append(ClipboardItem(type: .color, content: hex, sourceBundleID: source))
            return results
        }

        if let text = monitorItem.text, !text.isEmpty {
            let trimmed = String(text.prefix(ClipboardHistorySettings.contentLengthMax))
            if monitorItem.url != nil, let urlString = monitorItem.url?.absoluteString {
                results.append(ClipboardItem(type: .url, content: urlString, sourceBundleID: source))
            } else {
                results.append(ClipboardItem(type: .plainText, content: trimmed, sourceBundleID: source))
            }
        }

        return results
    }

    private func add(_ item: ClipboardItem) {
        // Deduplicate: same content, or for images same pixel data, bumps to top.
        if let existingIndex = items.firstIndex(where: { Self.isSameContent($0, item) }) {
            let existing = items.remove(at: existingIndex)
            let updated = ClipboardItem(
                id: existing.id,
                timestamp: Date(),
                type: existing.type,
                content: existing.content,
                imageData: existing.imageData ?? item.imageData,
                sourceBundleID: item.sourceBundleID,
                isPinned: existing.isPinned,
                isFavorite: existing.isFavorite
            )
            insertPrioritized(updated)
        } else {
            insertPrioritized(item)
        }
        trimToMax()
    }

    /// Equality for dedup. Images match by raw pixel data; everything else by
    /// `(type, content)`.
    private static func isSameContent(_ a: ClipboardItem, _ b: ClipboardItem) -> Bool {
        if a.type == .image && b.type == .image {
            return a.imageData == b.imageData
        }
        return a.type == b.type && a.content == b.content
    }

    private func insertPrioritized(_ item: ClipboardItem) {
        // Favorites at the top, then pinned, then newest.
        let firstNonFavorite = items.firstIndex(where: { !$0.isFavorite }) ?? items.count
        if item.isFavorite {
            items.insert(item, at: firstNonFavorite)
            return
        }
        let firstUnpinned = items.firstIndex(where: { !$0.isPinned && !$0.isFavorite }) ?? items.count
        if item.isPinned {
            items.insert(item, at: firstUnpinned)
            return
        }
        items.insert(item, at: firstUnpinned)
    }

    func trimToMax(now: Date = Date()) {
        let cutoff = now.addingTimeInterval(-Double(settings.retentionDays) * 86_400)
        items.removeAll { !$0.isPinned && !$0.isFavorite && $0.timestamp < cutoff }
        while items.count > settings.maxHistory {
            guard let evictionIndex = items.lastIndex(where: { !$0.isPinned && !$0.isFavorite }) else {
                // All remaining overflow items are pinned/favorite; stop evicting
                // rather than silently deleting protected items or looping forever.
                break
            }
            items.remove(at: evictionIndex)
        }
    }

    private func persistPinnedAndTrim() {
        let pinned = items.filter { $0.isPinned }
        var new = settings
        new.pinnedItems = pinned
        applySettings(new)
        trimToMax()
        schedulePersistence()
    }

    // MARK: - Settings

    private func applySettings(_ new: ClipboardHistorySettings) {
        let sanitized = ClipboardHistorySettings.sanitized(
            hotkeyEnabled: new.hotkeyEnabled,
            hotkey: new.hotkey,
            maxHistory: new.maxHistory,
            retentionDays: new.retentionDays,
            maxStorageMB: new.maxStorageMB,
            pinnedItems: new.pinnedItems,
            excludedBundleIDs: new.excludedBundleIDs,
            incognito: new.incognito,
            pasteOnEnter: new.pasteOnEnter
        )
        let hotkeyChanged = settings.hotkey != sanitized.hotkey
            || settings.hotkeyEnabled != sanitized.hotkeyEnabled
        settings = sanitized
        settingsStore.saveClipboardHistorySettings(sanitized)
        if hotkeyChanged && state.isStarted {
            unregisterHotkey()
            registerHotkey()
        }
        // Restore pinned items into the live list if missing.
        for pinned in sanitized.pinnedItems where !items.contains(where: { $0.id == pinned.id }) {
            items.insert(pinned, at: 0)
        }
        trimToMax()
        schedulePersistence()
    }

    // MARK: - Persistent history

    private func restorePersistentHistory() async {
        do {
            let restored = try await persistence.load()
            var byID = Dictionary(uniqueKeysWithValues: restored.map { ($0.id, $0) })
            for legacyPinned in items where byID[legacyPinned.id] == nil {
                byID[legacyPinned.id] = legacyPinned
            }
            items = byID.values.sorted(by: Self.displayPriority)
            trimToMax()
            storageBytes = await persistence.storageBytes()
            persistenceError = nil
            await persist(items)
        } catch {
            persistenceError = "Clipboard history could not be loaded: \(error.localizedDescription)"
            state = .degraded(reason: persistenceError!)
            logger.error("Persistent history load failed: \(error)")
        }
    }

    private func schedulePersistence() {
        persistenceTask?.cancel()
        let snapshot = items
        persistenceTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled, let self else { return }
            await self.persist(snapshot)
        }
    }

    private func persist(_ snapshot: [ClipboardItem]) async {
        let maxBytes = Int64(settings.maxStorageMB) * 1_024 * 1_024
        do {
            let result = try await persistence.save(snapshot, maxStorageBytes: maxBytes)
            storageBytes = result.storageBytes
            omittedImageCount = result.omittedImageCount
            persistenceError = nil
        } catch {
            persistenceError = "Clipboard history could not be saved: \(error.localizedDescription)"
            logger.error("Persistent history save failed: \(error)")
        }
    }

    private static func displayPriority(_ lhs: ClipboardItem, _ rhs: ClipboardItem) -> Bool {
        if lhs.isFavorite != rhs.isFavorite { return lhs.isFavorite }
        if lhs.isPinned != rhs.isPinned { return lhs.isPinned }
        return lhs.timestamp > rhs.timestamp
    }

    // MARK: - Hotkey

    private func registerHotkey() {
        guard hotkey == nil else { return }
        guard settings.hotkeyEnabled, let definition = settings.hotkey else {
            state = hotkeyHealth.recovered(current: state)
            return
        }
        let hotkey = GlobalHotkey(definition: definition) { [weak self] in
            self?.showHistoryPanel()
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
                reason = "Hotkey installer failed (\(status)) for \(display). Use the Open history button."
            case .registerFailed(let status):
                reason = "\(display) is already taken by another app (Carbon error \(status)). Pick a different shortcut."
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
}
