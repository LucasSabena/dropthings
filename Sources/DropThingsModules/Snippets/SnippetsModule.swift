import AppKit
import Combine
import SwiftUI
import DropThingsCore
import DropThingsDesignSystem
import DropThingsPlatform
import os

/// Persistent named text snippets. The user summons a searchable picker with a
/// global hotkey, selects a snippet, and its content is copied to the
/// pasteboard. Snippets are also exposed to the Command Palette through
/// `CommandSource`.
public final class SnippetsModule: DropThingsModule, ObservableObject {
    public let id = ModuleID.snippets
    public let name = "Snippets"
    public let summary = "Persistent named text snippets, copied to the clipboard on demand."
    public let requiredPermissions: [SystemPermission] = []

    @Published public private(set) var state: ModuleState = .off
    @Published public private(set) var settings: SnippetsSettings

    private let settingsStore: SettingsStore
    private var hotkey: GlobalHotkey?
    private var panel: SnippetsPanelController?
    private let logger = ModuleLogger(subsystem: "app.dropthings", category: "snippets")

    public init(settings: SettingsStore) {
        self.settingsStore = settings
        self.settings = settings.loadSnippetsSettings()
        let panel = SnippetsPanelController(module: self)
        self.panel = panel
    }

    public func start() async throws {
        registerHotkey()
        state = .running
        logger.info("Snippets started")
    }

    public func stop() async {
        unregisterHotkey()
        panel?.hide()
        state = .off
        logger.info("Snippets stopped")
    }

    // MARK: - Public actions

    public func showPanel() {
        panel?.show()
    }

    public func hidePanel() {
        panel?.hide()
    }

    public func togglePanel() {
        if panel?.isVisible == true {
            hidePanel()
        } else {
            showPanel()
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

    public func addSnippet(title: String, content: String, keyword: String?) {
        let snippet = Snippet(title: title, content: content, keyword: keyword)
        guard !snippet.isEmpty else { return }
        var new = settings
        new.snippets.insert(snippet, at: 0)
        applySettings(new)
        logger.notice("Added snippet \(snippet.id)")
    }

    public func updateSnippet(id: UUID, title: String, content: String, keyword: String?) {
        guard let index = settings.snippets.firstIndex(where: { $0.id == id }) else { return }
        let snippet = Snippet(id: id, title: title, content: content, keyword: keyword)
        guard !snippet.isEmpty else {
            deleteSnippet(id: id)
            return
        }
        var new = settings
        new.snippets[index] = snippet
        applySettings(new)
        logger.notice("Updated snippet \(id)")
    }

    public func deleteSnippet(id: UUID) {
        var new = settings
        new.snippets.removeAll { $0.id == id }
        applySettings(new)
        logger.notice("Deleted snippet \(id)")
    }

    public func copyToPasteboard(_ snippet: Snippet) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(snippet.content, forType: .string)
        logger.notice("Copied snippet \(snippet.id) to pasteboard")
    }

    // MARK: - SwiftUI surface

    public func makeSettingsView() -> AnyView {
        AnyView(SnippetsSettingsView(module: self))
    }

    // MARK: - Settings

    private func applySettings(_ new: SnippetsSettings) {
        let sanitized = SnippetsSettings.sanitized(
            hotkeyEnabled: new.hotkeyEnabled,
            hotkey: new.hotkey,
            snippets: new.snippets
        )
        let hotkeyChanged = settings.hotkey != sanitized.hotkey
            || settings.hotkeyEnabled != sanitized.hotkeyEnabled
        settings = sanitized
        settingsStore.saveSnippetsSettings(sanitized)
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
                state = .degraded(reason: "Hotkey installer failed (\(status)) for \(display). Use the Open snippets button.")
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

    private func handleHotkeyFire() {
        showPanel()
    }
}

// MARK: - Command Palette

extension SnippetsModule: CommandSource {
    public var commands: [CommandDescriptor] {
        settings.snippets.map { snippet in
            CommandDescriptor(
                id: "snippets.\(snippet.id.uuidString)",
                title: snippet.title,
                subtitle: snippet.contentPreview,
                iconName: "doc.text",
                action: { [weak self] in
                    Task { @MainActor [weak self] in
                        self?.copyToPasteboard(snippet)
                    }
                }
            )
        }
    }
}
