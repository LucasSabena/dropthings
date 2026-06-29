import AppKit
import Combine
import SwiftUI
import DropThingsCore
import DropThingsDesignSystem
import DropThingsPlatform
import os

/// Keeps a rolling, searchable history of copied text and files. Pinned items
/// survive restarts; unpinned items live only in memory. Ignores transient
/// pasteboard data and content from excluded bundle IDs.
public final class ClipboardHistoryModule: DropThingsModule, ObservableObject {
    public let id = ModuleID.clipboardHistory
    public let name = "Clipboard History"
    public let summary = "Searchable history of copied text and files."
    public let requiredPermissions: [SystemPermission] = []

    @Published public private(set) var state: ModuleState = .off
    @Published public private(set) var settings: ClipboardHistorySettings
    @Published public private(set) var items: [ClipboardItem] = []

    private let settingsStore: SettingsStore
    private let monitor: ClipboardMonitor
    private var hotkey: GlobalHotkey?
    private var panel: ClipboardHistoryPanelController?
    private let logger = ModuleLogger(subsystem: "app.dropthings", category: "clipboard-history")

    public init(settings: SettingsStore, permissions: PermissionCenter) {
        self.settingsStore = settings
        self.settings = settings.loadClipboardHistorySettings()
        let monitor = ClipboardMonitor()
        self.monitor = monitor
        let panel = ClipboardHistoryPanelController(module: self)
        self.panel = panel
        monitor.handler = { [weak self] item in
            Task { @MainActor [weak self] in
                self?.handleClipboardItem(item)
            }
        }
    }

    public func start() async throws {
        registerHotkey()
        monitor.start()
        state = .running
        logger.info("Clipboard History started")
    }

    public func stop() async {
        unregisterHotkey()
        monitor.stop()
        panel?.hide()
        state = .off
        logger.info("Clipboard History stopped")
    }

    // MARK: - Public actions

    public func showHistoryPanel() {
        panel?.show()
    }

    public func hideHistoryPanel() {
        panel?.hide()
    }

    public func toggleHistoryPanel() {
        // NSPanel state is tricky from SwiftUI; ask the controller directly.
        panel?.show()
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
            let url = URL(fileURLWithPath: item.content)
            pb.writeObjects([url as NSPasteboardWriting])
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
    }

    // MARK: - SwiftUI surface

    public func makeSettingsView() -> AnyView {
        AnyView(ClipboardHistorySettingsView(module: self))
    }

    // MARK: - Pasteboard handling

    private func handleClipboardItem(_ monitorItem: ClipboardMonitor.Item) {
        guard state == .running else { return }
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
    }

    private func buildItems(from monitorItem: ClipboardMonitor.Item) -> [ClipboardItem] {
        var results: [ClipboardItem] = []
        let source = monitorItem.sourceBundleID

        if let text = monitorItem.text, !text.isEmpty {
            let trimmed = String(text.prefix(ClipboardHistorySettings.contentLengthMax))
            if monitorItem.url != nil, let urlString = monitorItem.url?.absoluteString {
                results.append(ClipboardItem(type: .url, content: urlString, sourceBundleID: source))
            } else {
                results.append(ClipboardItem(type: .plainText, content: trimmed, sourceBundleID: source))
            }
        }

        for url in monitorItem.fileURLs {
            results.append(ClipboardItem(type: .filePath, content: url.path, sourceBundleID: source))
        }

        return results
    }

    private func add(_ item: ClipboardItem) {
        // Deduplicate: if the same content already exists, bump it to top.
        if let existingIndex = items.firstIndex(where: { $0.type == item.type && $0.content == item.content }) {
            let existing = items.remove(at: existingIndex)
            let updated = ClipboardItem(
                id: existing.id,
                timestamp: Date(),
                type: existing.type,
                content: existing.content,
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

    private func trimToMax() {
        guard items.count > settings.maxHistory else { return }
        let overflow = items.count - settings.maxHistory
        var removed = 0
        // Evict from the end (oldest, least important) first.
        while removed < overflow, !items.isEmpty {
            let last = items.removeLast()
            if last.isPinned || last.isFavorite {
                // Don't drop pinned/favorites silently; put them back at front.
                items.insert(last, at: 0)
            } else {
                removed += 1
            }
        }
    }

    private func persistPinnedAndTrim() {
        let pinned = items.filter { $0.isPinned }
        var new = settings
        new.pinnedItems = pinned
        applySettings(new)
        trimToMax()
    }

    // MARK: - Settings

    private func applySettings(_ new: ClipboardHistorySettings) {
        let sanitized = ClipboardHistorySettings.sanitized(
            hotkeyEnabled: new.hotkeyEnabled,
            hotkey: new.hotkey,
            maxHistory: new.maxHistory,
            pinnedItems: new.pinnedItems,
            excludedBundleIDs: new.excludedBundleIDs,
            incognito: new.incognito
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
    }

    // MARK: - Hotkey

    private func registerHotkey() {
        guard settings.hotkeyEnabled, let definition = settings.hotkey else { return }
        let hotkey = GlobalHotkey(definition: definition) { [weak self] in
            self?.showHistoryPanel()
        }
        do {
            try hotkey.register()
            self.hotkey = hotkey
        } catch let error as GlobalHotkey.RegistrationError {
            let display = definition.displayString
            switch error {
            case .installHandlerFailed(let status):
                state = .degraded(reason: "Hotkey installer failed (\(status)) for \(display). Use the Open history button.")
            case .registerFailed(let status):
                state = .degraded(reason: "\(display) is already taken by another app (Carbon error \(status)). Pick a different shortcut.")
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
}
