import AppKit
import Combine
import SwiftUI
import DropThingsCore
import DropThingsDesignSystem
import DropThingsPlatform
import os

/// A local content-aware action layer for the current clipboard. Smart
/// Clipboard complements Clipboard History instead of duplicating it: it
/// reads the current pasteboard once (through the shared `PasteboardHub`),
/// classifies it, offers deterministic local transforms, and writes a result
/// back only when the user explicitly commits one.
///
/// No permission is required for inspect/copy actions. Optional paste-back
/// requests Accessibility only when the user enables it in settings.
public final class SmartClipboardModule: DropThingsModule {
    public let id = ModuleID.smartClipboard
    public let name = "Smart Clipboard"
    public let summary = "Content-aware actions for the current clipboard."
    public let requiredPermissions: [SystemPermission] = []

    @Published public private(set) var state: ModuleState = .off
    @Published public private(set) var settings: SmartClipboardSettings
    @Published public private(set) var lastResult: String?
    @Published public private(set) var lastError: String?
    @Published public private(set) var pinnedActionIDs: [String] = []

    private let settingsStore: SettingsStore
    private let permissions: PermissionCenter
    private let hub: PasteboardHub
    private let pasteboard: NSPasteboard
    private let fileActionRegistry: FileActionRegistry?
    private let urlTitleFetcher: SmartClipboardURLTitleFetching
    let origin = PasteboardHub.OriginToken("modules.smart-clipboard")
    private var hubSubscription: PasteboardHub.Subscription?
    private var hotkey: GlobalHotkey?
    private var hotkeyHealth = HotkeyRegistrationHealth()
    private var panel: SmartClipboardPanelController?
    private let logger = ModuleLogger(subsystem: "app.dropthings", category: "smart-clipboard")
    /// Snapshot of the pasteboard before a Smart Clipboard copy, kept for the
    /// bounded undo-copy window so the user can restore the previous clipboard.
    private var preCopySnapshot: NSPasteboardSnapshot?
    /// Timer that clears `preCopySnapshot` when the undo window elapses so a
    /// stale snapshot never lingers beyond the configured period.
    private var undoExpiryTimer: Timer?

    public convenience init(settings: SettingsStore, permissions: PermissionCenter) {
        self.init(
            settings: settings,
            permissions: permissions,
            hub: PasteboardHub(backend: ClipboardMonitor()),
            pasteboard: .general,
            fileActionRegistry: nil,
            urlTitleFetcher: SystemURLTitleFetcher()
        )
    }

    /// Compose with an externally owned hub and file-action registry so Smart
    /// Clipboard shares the single pasteboard observer with Clipboard History
    /// and can invoke cross-module file actions through Core.
    public convenience init(
        settings: SettingsStore,
        permissions: PermissionCenter,
        hub: PasteboardHub,
        fileActionRegistry: FileActionRegistry?
    ) {
        self.init(
            settings: settings,
            permissions: permissions,
            hub: hub,
            pasteboard: .general,
            fileActionRegistry: fileActionRegistry,
            urlTitleFetcher: SystemURLTitleFetcher()
        )
    }

    public init(
        settings: SettingsStore,
        permissions: PermissionCenter,
        hub: PasteboardHub,
        pasteboard: NSPasteboard = .general,
        fileActionRegistry: FileActionRegistry?,
        urlTitleFetcher: SmartClipboardURLTitleFetching
    ) {
        self.settingsStore = settings
        self.permissions = permissions
        self.hub = hub
        self.pasteboard = pasteboard
        self.fileActionRegistry = fileActionRegistry
        self.urlTitleFetcher = urlTitleFetcher
        self.settings = settings.loadSmartClipboardSettings()
        self.panel = SmartClipboardPanelController(module: self)
        loadPinned()
    }

    // MARK: - Lifecycle

    public func start() async throws {
        registerHotkey()
        hubSubscription?.cancel()
        hubSubscription = hub.subscribe(origin: origin) { [weak self] _ in
            // The panel polls the hub on demand; we only refresh the live
            // snapshot when the panel is open. This keeps a background module
            // cheap and avoids touching the pasteboard on every change.
            Task { @MainActor [weak self] in self?.panel?.refreshIfOpen() }
        }
        hub.start(interval: 0.25)
        if case .degraded = state {} else { state = .running }
        logger.info("Smart Clipboard started")
    }

    public func stop() async {
        unregisterHotkey()
        hubSubscription?.cancel()
        hubSubscription = nil
        cancelUndoExpiry()
        preCopySnapshot = nil
        lastResult = nil
        panel?.hide()
        state = .off
        logger.info("Smart Clipboard stopped")
    }

    // MARK: - Presentation

    public var primaryAction: ModulePrimaryAction? {
        ModulePrimaryAction(
            title: "Open Smart Clipboard",
            iconName: iconName,
            action: { [weak self] in
                Task { @MainActor [weak self] in self?.showPanel() }
            }
        )
    }

    public var commands: [CommandDescriptor] {
        [
            CommandDescriptor(
                id: "smart-clipboard.open",
                title: "Open Smart Clipboard",
                subtitle: name,
                iconName: iconName,
                action: { [weak self] in
                    Task { @MainActor [weak self] in self?.showPanel() }
                }
            )
        ]
    }

    public func makeSettingsView() -> AnyView {
        AnyView(SmartClipboardSettingsView(module: self))
    }

    // MARK: - Public actions

    public func showPanel() {
        panel?.show()
    }

    public func hidePanel() {
        panel?.hide()
    }

    public func togglePanel() {
        if panel?.isVisible == true { hidePanel() } else { showPanel() }
    }

    public var smartClipboardSettings: SmartClipboardSettings { settings }

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

    public func setColorFormat(_ format: SmartClipboardColorFormat) {
        var new = settings
        new.colorFormat = format
        applySettings(new)
    }

    public func setHideSensitivePreview(_ enabled: Bool) {
        var new = settings
        new.hideSensitivePreview = enabled
        applySettings(new)
    }

    public func setPasteBackEnabled(_ enabled: Bool) {
        var new = settings
        new.pasteBackEnabled = enabled
        applySettings(new)
    }

    public func setUndoCopyWindow(seconds: Int) {
        var new = settings
        new.undoCopyWindowSeconds = seconds
        applySettings(new)
    }

    public func togglePinned(actionID: String) {
        if pinnedActionIDs.contains(actionID) {
            pinnedActionIDs.removeAll { $0 == actionID }
        } else {
            pinnedActionIDs.append(actionID)
        }
        persistPinned()
    }

    // MARK: - Snapshot reading

    /// The current pasteboard snapshot, classified. Used by the panel to
    /// render the live preview and the action list.
    public func currentSnapshot() -> SmartClipboardSnapshot? {
        guard let snapshot = hub.latestSnapshot else { return nil }
        return makeSnapshot(from: snapshot)
    }

    /// Force a fresh read of the pasteboard for the panel. Useful after the
    /// user copies something while the panel is open but before the hub poll
    /// has fired.
    public func refreshSnapshot() {
        // Reading NSPasteboard directly here is intentional: the hub polls at
        // a bounded interval, but the panel's explicit refresh should reflect
        // the very latest state. The next hub poll will catch up.
        guard let item = SmartClipboardReader.read(pasteboard: pasteboard) else { return }
        let snapshot = PasteboardHub.Snapshot(
            changeCount: pasteboard.changeCount,
            text: item.text,
            url: item.url,
            fileURLs: item.fileURLs,
            imageData: item.imageData,
            colorHex: item.colorHex,
            isTransient: item.isTransient,
            isConcealed: item.isConcealed,
            sourceBundleID: item.sourceBundleID
        )
        hub.overrideLatest(snapshot)
    }

    // MARK: - Action application

    /// Outcome of applying an action. The panel uses this to decide what to
    /// show and whether to copy automatically.
    public struct ActionOutcome: Sendable, Equatable {
        public let preview: String
        public let copyableText: String?
        public let notice: String?
    }

    /// Apply an action against the given snapshot. Returns a preview and an
    /// optional copyable payload. Does NOT write to the pasteboard; the caller
    /// commits with `commitResult(_:)`.
    public func apply(action: SmartClipboardAction, to snapshot: SmartClipboardSnapshot) -> ActionOutcome {
        switch action.body {
        case .textCase(let t):
            let out = SmartClipboardTextEngine.applyCase(t, to: snapshot.text ?? "")
            return ActionOutcome(preview: out, copyableText: out, notice: nil)
        case .textWhitespace(let t):
            let out = SmartClipboardTextEngine.applyWhitespace(t, to: snapshot.text ?? "")
            return ActionOutcome(preview: out, copyableText: out, notice: nil)
        case .textLines(let t):
            let out = SmartClipboardTextEngine.applyLine(t, to: snapshot.text ?? "")
            return ActionOutcome(preview: out, copyableText: out, notice: nil)
        case .textEncoding(let t):
            let out = SmartClipboardTextEngine.applyEncoding(t, to: snapshot.text ?? "")
            return ActionOutcome(preview: out, copyableText: out, notice: nil)
        case .textCounts:
            let counts = SmartClipboardTextEngine.counts(for: snapshot.text ?? "")
            let text = "\(counts.characters) characters · \(counts.words) words · \(counts.lines) lines"
            return ActionOutcome(preview: text, copyableText: text, notice: nil)
        case .jsonValidate:
            if let failure = SmartClipboardJSONEngine.validate(snapshot.text ?? "") {
                return ActionOutcome(preview: "Invalid JSON", copyableText: nil, notice: failure.message)
            }
            return ActionOutcome(preview: "Valid JSON", copyableText: nil, notice: nil)
        case .jsonPretty(let sortKeys):
            guard let result = SmartClipboardJSONEngine.prettyPrint(snapshot.text ?? "", sortKeys: sortKeys) else {
                return ActionOutcome(preview: "Invalid JSON", copyableText: nil, notice: "Could not parse JSON.")
            }
            return ActionOutcome(preview: result.output, copyableText: result.output, notice: nil)
        case .jsonMinify(let sortKeys):
            guard let result = SmartClipboardJSONEngine.minify(snapshot.text ?? "", sortKeys: sortKeys) else {
                return ActionOutcome(preview: "Invalid JSON", copyableText: nil, notice: "Could not parse JSON.")
            }
            return ActionOutcome(preview: result.output, copyableText: result.output, notice: nil)
        case .urlNormalize:
            guard let url = snapshot.url else { return unavailable(snapshot) }
            let normalized = SmartClipboardURLEngine.normalize(url)
            let text = normalized.url.absoluteString
            let note = normalized.removedParameters.isEmpty ? nil
                : "Removed: \(normalized.removedParameters.joined(separator: ", "))"
            return ActionOutcome(preview: text, copyableText: text, notice: note)
        case .urlMarkdownLink:
            guard let url = snapshot.url else { return unavailable(snapshot) }
            let md = SmartClipboardURLEngine.markdownLink(url: url)
            return ActionOutcome(preview: md, copyableText: md, notice: nil)
        case .urlStripTracking:
            guard let url = snapshot.url else { return unavailable(snapshot) }
            let normalized = SmartClipboardURLEngine.normalize(url)
            let text = normalized.url.absoluteString
            let note: String? = normalized.removedParameters.isEmpty
                ? "No tracking parameters found."
                : "Removed: \(normalized.removedParameters.joined(separator: ", "))"
            return ActionOutcome(preview: text, copyableText: text, notice: note)
        case .urlTitleFetch:
            // Network action: the panel triggers this explicitly and shows a
            // phase. The synchronous preview is a placeholder.
            return ActionOutcome(preview: "Fetching title…", copyableText: nil, notice: nil)
        case .colorFormat(let format):
            guard let color = snapshot.color else { return unavailable(snapshot) }
            let text = format.string(from: color)
            return ActionOutcome(preview: text, copyableText: text, notice: nil)
        case .filesReveal:
            return ActionOutcome(preview: "Reveal \(snapshot.fileURLs.count) item(s) in Finder", copyableText: nil, notice: nil)
        case .filesCopyNames:
            let names = snapshot.fileURLs.map(\.lastPathComponent)
            let text = names.joined(separator: "\n")
            return ActionOutcome(preview: text, copyableText: text, notice: nil)
        case .filesCopyPaths:
            let paths = snapshot.fileURLs.map(\.path)
            let text = paths.joined(separator: "\n")
            return ActionOutcome(preview: text, copyableText: text, notice: nil)
        case .filesInfo:
            let lines = snapshot.fileURLs.map { url -> String in
                let info = FileContentInfo.inspect(url)
                let size = info.byteCount.map { ByteCountFormatter.string(fromByteCount: $0, countStyle: .file) } ?? "—"
                return "\(info.kind.displayName) · \(size) · \(url.lastPathComponent)"
            }
            let text = lines.joined(separator: "\n")
            return ActionOutcome(preview: text, copyableText: text, notice: nil)
        case .filesSaveRepresentation:
            return ActionOutcome(preview: "Choose a destination to save.", copyableText: nil, notice: nil)
        case .filesAction(let ref):
            return ActionOutcome(preview: ref.title, copyableText: nil, notice: nil)
        }
    }

    /// Explicitly trigger a network action (URL title fetch). Returns the
    /// markdown link with the fetched title, or an error notice.
    public func fetchURLTitle(for snapshot: SmartClipboardSnapshot) async -> ActionOutcome {
        guard let url = snapshot.url else { return unavailable(snapshot) }
        do {
            let title = try await urlTitleFetcher.fetchTitle(url: url)
            let md = SmartClipboardURLEngine.markdownLink(url: url, label: title)
            return ActionOutcome(preview: md, copyableText: md, notice: title == nil ? "No <title> found." : nil)
        } catch {
            logger.warning("URL title fetch failed for \(url.absoluteString): \(error)")
            return ActionOutcome(
                preview: "Could not fetch title",
                copyableText: nil,
                notice: error.localizedDescription
            )
        }
    }

    // MARK: - Commit / copy / paste / undo

    /// Write a text result to the pasteboard. Records the origin token so the
    /// hub (and Clipboard History, if subscribed through the same hub) does
    /// not treat Smart Clipboard's own write as a new external change.
    public func copyResult(_ text: String) {
        let pb = pasteboard
        preCopySnapshot = NSPasteboardSnapshot.capture(from: pb)
        pb.clearContents()
        pb.setString(text, forType: .string)
        hub.recordWrite(origin: origin)
        lastResult = text
        scheduleUndoExpiry()
        logger.notice("Copied Smart Clipboard result (\(text.count) characters)")
    }

    /// Write a color result, publishing both the native color and a string
    /// representation so paste targets that understand colors (Xcode) and
    /// plain text editors both work.
    public func copyColor(_ color: SmartClipboardColor, as format: SmartClipboardColorFormat) {
        let pb = pasteboard
        preCopySnapshot = NSPasteboardSnapshot.capture(from: pb)
        pb.clearContents()
        let value = format.string(from: color)
        if let nsColor = color.nsColor {
            pb.writeObjects([nsColor])
        }
        pb.setString(value, forType: .string)
        hub.recordWrite(origin: origin)
        lastResult = value
        scheduleUndoExpiry()
        logger.notice("Copied color \(value)")
    }

    /// Paste the last result into the app that had focus before the panel
    /// opened. Requires Accessibility (requested only when the user enables
    /// paste-back). Returns a result the panel can surface.
    @discardableResult
    public func pasteBack() -> PasteBackResult {
        guard settings.pasteBackEnabled else { return .disabled }
        guard KeystrokeSynthesizer.isAccessibilityGranted() else { return .needsAccessibility }
        guard lastResult != nil else { return .nothingToPaste }
        panel?.hide()
        panel?.reactivatePreviousApp()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            KeystrokeSynthesizer.postPaste()
        }
        return .pasted
    }

    public enum PasteBackResult: Sendable, Equatable {
        case pasted
        case disabled
        case needsAccessibility
        case nothingToPaste
    }

    /// Restore the clipboard to what it held before the last Smart Clipboard
    /// copy. Only valid within the bounded undo window.
    @discardableResult
    public func undoCopy() -> UndoResult {
        guard let snapshot = preCopySnapshot else { return .nothingToUndo }
        snapshot.restore(into: pasteboard)
        hub.recordWrite(origin: origin)
        preCopySnapshot = nil
        lastResult = nil
        cancelUndoExpiry()
        return .restored
    }

    public enum UndoResult: Sendable, Equatable {
        case restored
        case nothingToUndo
    }

    /// Clear the undo snapshot after the configured window so a stale
    /// clipboard state never lingers. A window of `0` disables undo: the
    /// snapshot is cleared immediately and `undoCopy()` will report nothing.
    private func scheduleUndoExpiry() {
        cancelUndoExpiry()
        let seconds = settings.undoCopyWindowSeconds
        guard seconds > 0 else {
            preCopySnapshot = nil
            return
        }
        let timer = Timer(timeInterval: TimeInterval(seconds), repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.preCopySnapshot = nil
                self.undoExpiryTimer = nil
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        undoExpiryTimer = timer
    }

    private func cancelUndoExpiry() {
        undoExpiryTimer?.invalidate()
        undoExpiryTimer = nil
    }

    // MARK: - File actions

    public func availableFileActions() -> [FileActionRef] {
        fileActionRegistry?.references() ?? []
    }

    /// Run a registered file action over the snapshot's file URLs. Returns
    /// `false` when the action is missing or unavailable so the panel can
    /// show a message instead of silently no-op'ing.
    @discardableResult
    public func runFileAction(id: String, for snapshot: SmartClipboardSnapshot) -> Bool {
        guard let registry = fileActionRegistry else { return false }
        return registry.run(id: id, for: snapshot.fileURLs)
    }

    /// Reveal the snapshot's files in Finder.
    public func revealInFinder(for snapshot: SmartClipboardSnapshot) {
        guard !snapshot.fileURLs.isEmpty else { return }
        NSWorkspace.shared.activateFileViewerSelecting(snapshot.fileURLs)
    }

    /// Save the snapshot's image data to a user-chosen file.
    public func saveImageRepresentation(for snapshot: SmartClipboardSnapshot) {
        guard let data = snapshot.imageData else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "clipboard-image.png"
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try data.write(to: url)
            logger.notice("Saved image representation to \(url.lastPathComponent)")
        } catch {
            lastError = "Could not save image: \(error.localizedDescription)"
            logger.warning("Save image failed: \(error)")
        }
    }

    // MARK: - Settings persistence

    private func applySettings(_ new: SmartClipboardSettings) {
        let sanitized = SmartClipboardSettings.sanitized(
            hotkeyEnabled: new.hotkeyEnabled,
            hotkey: new.hotkey,
            colorFormat: new.colorFormat,
            hideSensitivePreview: new.hideSensitivePreview,
            undoCopyWindowSeconds: new.undoCopyWindowSeconds,
            pasteBackEnabled: new.pasteBackEnabled
        )
        let hotkeyChanged = settings.hotkey != sanitized.hotkey
            || settings.hotkeyEnabled != sanitized.hotkeyEnabled
        settings = sanitized
        settingsStore.saveSmartClipboardSettings(sanitized)
        if hotkeyChanged && state.isStarted {
            unregisterHotkey()
            registerHotkey()
        }
    }

    private func persistPinned() {
        // Pinned actions are stored separately so they survive a settings
        // schema change and do not bloat the main settings blob.
        settingsStore.setData(
            (try? JSONEncoder().encode(pinnedActionIDs)) ?? Data(),
            SmartClipboardPinnedKey.actions
        )
    }

    private func loadPinned() {
        guard let data = settingsStore.data(SmartClipboardPinnedKey.actions),
              let decoded = try? JSONDecoder().decode([String].self, from: data) else { return }
        pinnedActionIDs = decoded
    }

    // MARK: - Snapshot construction

    private func makeSnapshot(from snapshot: PasteboardHub.Snapshot) -> SmartClipboardSnapshot {
        let kind: SmartClipboardKind
        if let override = panel?.forcedKind {
            kind = override
        } else {
            kind = SmartClipboardClassifier.classify(
                text: snapshot.text,
                fileURLs: snapshot.fileURLs,
                imageData: snapshot.imageData,
                colorHex: snapshot.colorHex
            )
        }
        let color = snapshot.colorHex.flatMap { SmartClipboardColor.parse($0) }
            ?? snapshot.text.flatMap { SmartClipboardColor.parse($0) }
        return SmartClipboardSnapshot(
            changeCount: snapshot.changeCount,
            text: snapshot.text,
            url: snapshot.url,
            fileURLs: snapshot.fileURLs,
            imageData: snapshot.imageData,
            colorHex: snapshot.colorHex,
            color: color,
            isTransient: snapshot.isTransient,
            isConcealed: snapshot.isConcealed,
            sourceBundleID: snapshot.sourceBundleID,
            kind: kind
        )
    }

    private func unavailable(_ snapshot: SmartClipboardSnapshot) -> ActionOutcome {
        ActionOutcome(preview: "Not available for this content", copyableText: nil, notice: nil)
    }

    // MARK: - Hotkey

    private func registerHotkey() {
        guard hotkey == nil else { return }
        guard settings.hotkeyEnabled, let definition = settings.hotkey else {
            state = hotkeyHealth.recovered(current: state)
            return
        }
        let hotkey = GlobalHotkey(definition: definition) { [weak self] in
            self?.showPanel()
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
                reason = "Hotkey installer failed (\(status)) for \(display). Use the Open Smart Clipboard button."
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

/// A snapshot enriched with the classified kind and parsed color, ready for
/// the panel to render and for action application.
public struct SmartClipboardSnapshot: Sendable, Equatable {
    public let changeCount: Int
    public let text: String?
    public let url: URL?
    public let fileURLs: [URL]
    public let imageData: Data?
    public let colorHex: String?
    public let color: SmartClipboardColor?
    public let isTransient: Bool
    public let isConcealed: Bool
    public let sourceBundleID: String?
    public let kind: SmartClipboardKind

    public init(
        changeCount: Int,
        text: String?,
        url: URL?,
        fileURLs: [URL],
        imageData: Data?,
        colorHex: String?,
        color: SmartClipboardColor?,
        isTransient: Bool,
        isConcealed: Bool,
        sourceBundleID: String?,
        kind: SmartClipboardKind
    ) {
        self.changeCount = changeCount
        self.text = text
        self.url = url
        self.fileURLs = fileURLs
        self.imageData = imageData
        self.colorHex = colorHex
        self.color = color
        self.isTransient = isTransient
        self.isConcealed = isConcealed
        self.sourceBundleID = sourceBundleID
        self.kind = kind
    }
}

// MARK: - Pasteboard snapshot capture / restore

/// Captures the pasteboard state before a Smart Clipboard write so the user
/// can undo an accidental transform within a bounded window.
struct NSPasteboardSnapshot {
    let types: [NSPasteboard.PasteboardType]
    let items: [[NSPasteboard.PasteboardType: Data]]

    static func capture(from pb: NSPasteboard) -> NSPasteboardSnapshot? {
        guard let items = pb.pasteboardItems else { return nil }
        let captured: [[NSPasteboard.PasteboardType: Data]] = items.map { item in
            var dict: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) {
                    dict[type] = data
                }
            }
            return dict
        }
        return NSPasteboardSnapshot(types: pb.types ?? [], items: captured)
    }

    func restore(into pb: NSPasteboard) {
        pb.clearContents()
        guard !items.isEmpty else { return }
        let restored: [NSPasteboardItem] = items.map { dict in
            let item = NSPasteboardItem()
            for (type, data) in dict {
                item.setData(data, forType: type)
            }
            return item
        }
        pb.writeObjects(restored)
    }
}

enum SmartClipboardPinnedKey {
    static let actions = SettingsKey("modules.smart-clipboard.pinned-actions")
}

// MARK: - Color format rendering

extension SmartClipboardColorFormat {
    func string(from color: SmartClipboardColor) -> String {
        switch self {
        case .hex: return color.hex
        case .rgb: return color.rgbString
        case .hsl: return color.hslString
        case .css: return color.cssString
        case .swiftUIColor: return color.swiftUIColorString
        }
    }
}