import AppKit
import SwiftUI
import Combine
import DropThingsCore
import DropThingsDesignSystem
import DropThingsPlatform
import UniformTypeIdentifiers
import os

/// Reads and edits Markdown files with a live, GitHub-Flavored preview
/// (tables, fenced code with syntax highlighting, task lists, images, and
/// every CommonMark/GFM construct `marked.js` supports). The preview is a
/// `WKWebView` running the vendored `marked.min.js` and `highlight.min.js`;
/// the editor is a plain `NSTextView`. The window hosts a tab per open
/// document so the user can switch between several files.
///
/// No TCC permission is required for the core: file access is granted per
/// file by `NSOpenPanel` or drag-and-drop. The optional "open the Finder
/// selection with the hotkey" behavior sends an Apple Event to Finder and
/// triggers macOS' Automation prompt; it is gated behind an opt-in setting.
public final class MarkdownViewerModule: DropThingsModule {
    public let id = ModuleID.markdownViewer
    public let name = "Markdown Viewer"
    public let summary = "Read and edit Markdown files with a live preview."
    public let requiredPermissions: [SystemPermission] = []

    @Published public private(set) var state: ModuleState = .off
    @Published public private(set) var settings: MarkdownViewerSettings
    @Published public private(set) var openDocuments: [MarkdownDocument]
    @Published public private(set) var activeDocumentIndex: Int = 0

    public var isWindowVisible: Bool { windowController.isWindowVisible }

    /// The document currently shown in the active tab. The invariant is that
    /// `openDocuments` always has at least one entry (an untitled document
    /// when the window has no file), so this never falls back to a throwaway.
    public var currentDocument: MarkdownDocument {
        guard !openDocuments.isEmpty, activeDocumentIndex < openDocuments.count else {
            return openDocuments.first ?? MarkdownDocument()
        }
        return openDocuments[activeDocumentIndex]
    }

    private let settingsStore: SettingsStore
    private let permissions: PermissionCenter
    private var hotkey: GlobalHotkey?
    private var hotkeyHealth = HotkeyRegistrationHealth()
    private let windowController = MarkdownViewerWindowController()
    private var appearanceObserver: NSKeyValueObservation?
    private let logger = ModuleLogger(subsystem: "app.dropthings", category: "markdown-viewer")

    public init(settings: SettingsStore, permissions: PermissionCenter) {
        self.settingsStore = settings
        self.permissions = permissions
        self.settings = settings.loadMarkdownViewerSettings()
        self.openDocuments = [MarkdownDocument()]
    }

    public func start() async throws {
        registerHotkey()
        observeAppearanceChanges()
        if case .degraded = state {} else { state = .running }
        logger.info("Markdown Viewer started")
    }

    public func stop() async {
        unregisterHotkey()
        appearanceObserver?.invalidate()
        appearanceObserver = nil
        windowController.hide()
        state = .off
        logger.info("Markdown Viewer stopped")
    }

    public var primaryAction: ModulePrimaryAction? {
        ModulePrimaryAction(
            title: "Open Markdown Viewer",
            iconName: iconName,
            action: { [weak self] in
                Task { @MainActor [weak self] in self?.openViewer() }
            }
        )
    }

    public var commands: [CommandDescriptor] {
        [
            CommandDescriptor(
                id: "markdown-viewer.open",
                title: "Open Markdown Viewer",
                subtitle: name,
                iconName: iconName,
                action: { [weak self] in
                    Task { @MainActor [weak self] in self?.openViewer() }
                }
            ),
            CommandDescriptor(
                id: "markdown-viewer.open-file",
                title: "Open Markdown File…",
                subtitle: name,
                iconName: "folder",
                action: { [weak self] in
                    Task { @MainActor [weak self] in self?.openFilePanel() }
                }
            ),
            CommandDescriptor(
                id: "markdown-viewer.new",
                title: "New Markdown Document",
                subtitle: name,
                iconName: "doc",
                action: { [weak self] in
                    Task { @MainActor [weak self] in self?.openNewDocument() }
                }
            )
        ]
    }

    // MARK: - Opening / tabs

    /// Bring the viewer window to the front. The window is created lazily and
    /// reused, so a second invocation keeps the current set of tabs.
    public func openViewer() {
        windowController.show(document: currentDocument, settings: settings, module: self)
    }

    /// Run the system open panel (multi-select enabled) and open every chosen
    /// `.md` as its own tab.
    public func openFilePanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.plainText]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.title = "Open Markdown"
        guard panel.runModal() == .OK, !panel.urls.isEmpty else { return }
        openURLs(panel.urls)
    }

    /// Append a new untitled tab and switch to it.
    public func openNewDocument() {
        openDocuments.append(MarkdownDocument())
        activeDocumentIndex = openDocuments.count - 1
        openViewer()
        refreshWindow()
    }

    /// Open Markdown text that did not come from disk (e.g. a drag-and-drop
    /// of a text selection). Opens as an untitled tab.
    public func openPlainText(_ text: String) {
        openDocuments.append(MarkdownDocument(text: text))
        activeDocumentIndex = openDocuments.count - 1
        openViewer()
        refreshWindow()
    }

    /// Open a single file URL as a tab (focusing it if already open).
    public func openURL(_ url: URL) {
        openURLs([url])
    }

    /// Open several file URLs at once — each becomes a tab. Files already
    /// open in a tab are focused instead of duplicated. The last opened (or
    /// focused) tab becomes active. Recents are recorded in one batch.
    public func openURLs(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        _appendDocuments(urls: urls)
        openViewer()
        refreshWindow()
    }

    /// Internal: the pure tab-mutation half of `openURLs`, separated so tests
    /// can exercise it without showing a window.
    internal func _appendDocuments(urls: [URL]) {
        guard !urls.isEmpty else { return }
        var lastIndex = activeDocumentIndex
        var openedURLs: [URL] = []
        for url in urls {
            if let existing = openDocuments.firstIndex(where: { $0.url == url }) {
                lastIndex = existing
                continue
            }
            let doc = MarkdownDocument()
            doc.load(from: url)
            openDocuments.append(doc)
            lastIndex = openDocuments.count - 1
            openedURLs.append(url)
        }
        activeDocumentIndex = lastIndex
        if !openedURLs.isEmpty {
            recordRecentBatch(openedURLs)
        }
    }

    /// Switch the active tab. Clamped to the valid range.
    public func selectDocument(at index: Int) {
        guard openDocuments.indices.contains(index) else { return }
        guard activeDocumentIndex != index else { return }
        activeDocumentIndex = index
        refreshWindow()
    }

    /// Close a tab. If the document is dirty, prompt to save / discard / cancel
    /// before removing. The tab list always keeps at least one document: when
    /// the last real file is closed an untitled document replaces it so the
    /// window never goes empty.
    public func closeDocument(at index: Int) {
        guard openDocuments.indices.contains(index) else { return }
        let doc = openDocuments[index]
        if doc.isDirty {
            switch promptCloseDecision(for: doc) {
            case .cancel:
                return
            case .save:
                guard saveDocument(doc) else { return }
            case .discard:
                break
            }
        }
        let wasActive = index == activeDocumentIndex
        openDocuments.remove(at: index)
        if openDocuments.isEmpty {
            openDocuments.append(MarkdownDocument())
            activeDocumentIndex = 0
        } else if wasActive {
            activeDocumentIndex = min(index, openDocuments.count - 1)
        } else if index < activeDocumentIndex {
            activeDocumentIndex -= 1
        }
        refreshWindow()
    }

    /// Save the active document back to its file (or run Save As if untitled).
    public func saveCurrentDocument() {
        guard saveDocument(currentDocument) else { return }
        if let url = currentDocument.url {
            recordRecentBatch([url])
        }
        refreshWindow()
    }

    /// Marked dirty by the editor's `onChange`. The document already tracks
    /// its own dirty flag via its `@Published` observer; this is a hook for
    /// the module to react if needed in the future.
    public func markDocumentDirty() {}

    // MARK: - Settings mutators

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

    public func setTheme(_ theme: MarkdownTheme) {
        var new = settings
        new.theme = theme
        applySettings(new)
    }

    public func setFontSize(_ size: Int) {
        var new = settings
        new.fontSize = size
        applySettings(new)
    }

    public func setLayout(_ layout: MarkdownLayout) {
        var new = settings
        new.layout = layout
        applySettings(new)
    }

    public func setShowLineNumbers(_ enabled: Bool) {
        var new = settings
        new.showLineNumbers = enabled
        applySettings(new)
    }

    public func setOpenFinderSelectionWithHotkey(_ enabled: Bool) {
        var new = settings
        new.openFinderSelectionWithHotkey = enabled
        applySettings(new)
    }

    public func clearRecentFiles() {
        var new = settings
        new.recentFiles = []
        applySettings(new)
    }

    public func openRecent(_ file: MarkdownRecentFile) {
        openURL(file.url)
    }

    public func removeRecent(_ file: MarkdownRecentFile) {
        var new = settings
        new.recentFiles.removeAll { $0.id == file.id }
        applySettings(new)
    }

    public var viewerSettings: MarkdownViewerSettings { settings }

    // MARK: - SwiftUI surface

    public func makeSettingsView() -> AnyView {
        AnyView(MarkdownViewerSettingsView(module: self))
    }

    // MARK: - Internals

    private func applySettings(_ new: MarkdownViewerSettings) {
        let sanitized = MarkdownViewerSettings.sanitized(
            hotkeyEnabled: new.hotkeyEnabled,
            hotkey: new.hotkey,
            theme: new.theme,
            fontSize: new.fontSize,
            layout: new.layout,
            showLineNumbers: new.showLineNumbers,
            openFinderSelectionWithHotkey: new.openFinderSelectionWithHotkey,
            recentFiles: new.recentFiles
        )
        let hotkeyChanged = settings.hotkey != sanitized.hotkey
            || settings.hotkeyEnabled != sanitized.hotkeyEnabled
        settings = sanitized
        settingsStore.saveMarkdownViewerSettings(sanitized)
        if hotkeyChanged && state.isStarted {
            unregisterHotkey()
            registerHotkey()
        }
        if isWindowVisible {
            windowController.refresh(module: self)
        }
    }

    private func recordRecentBatch(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        var new = settings
        for url in urls {
            new.recentFiles.removeAll { $0.url == url }
            new.recentFiles.insert(
                MarkdownRecentFile(url: url, name: url.lastPathComponent, lastOpened: Date()),
                at: 0
            )
        }
        applySettings(new)
    }

    private func saveDocument(_ doc: MarkdownDocument) -> Bool {
        if doc.url == nil {
            return doc.saveAs()
        }
        return doc.save()
    }

    private enum CloseDecision { case save, discard, cancel }

    private func promptCloseDecision(for doc: MarkdownDocument) -> CloseDecision {
        let alert = NSAlert()
        alert.messageText = "Save changes to “\(doc.displayName)” before closing?"
        alert.informativeText = "Your changes will be lost if you don't save them."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Discard")
        alert.addButton(withTitle: "Cancel")
        switch alert.runModal() {
        case .alertFirstButtonReturn: return .save
        case .alertSecondButtonReturn: return .discard
        default: return .cancel
        }
    }

    private func refreshWindow() {
        guard isWindowVisible else { return }
        windowController.refresh(module: self)
    }

    private func observeAppearanceChanges() {
        guard appearanceObserver == nil else { return }
        appearanceObserver = NSApp.observe(\.effectiveAppearance, options: [.new]) { [weak self] _, _ in
            Task { @MainActor [weak self] in
                guard let self, self.isWindowVisible else { return }
                self.windowController.refresh(module: self)
            }
        }
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
                reason = "Hotkey installer failed (\(status)) for \(display). Use the menu bar action."
            case .registerFailed(let status):
                reason = "\(display) is already taken by another app (Carbon error \(status)). Pick a different shortcut or use the menu bar action."
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

    /// When the hotkey fires: if Finder is frontmost and the opt-in setting
    /// is on, read Finder's selection and open the selected `.md` file(s) as
    /// tabs. Otherwise just bring the viewer to the front with its current
    /// tabs. A denied Automation permission makes the selection read return
    /// nil, which falls back to opening the viewer.
    private func handleHotkeyFire() {
        if settings.openFinderSelectionWithHotkey,
           FinderSelectionReader.isFinderFrontmost(),
           let urls = FinderSelectionReader.selectedPaths(),
           !FinderSelectionReader.markdownOnly(urls).isEmpty {
            openURLs(FinderSelectionReader.markdownOnly(urls))
            return
        }
        openViewer()
    }
}
