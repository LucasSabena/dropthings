import Foundation
import DropThingsCore
import DropThingsPlatform
import Carbon.HIToolbox

/// Display theme for the Markdown preview.
public enum MarkdownTheme: String, CaseIterable, Codable, Sendable {
    case auto
    case light
    case dark

    public var label: String {
        switch self {
        case .auto: return "Match System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
}

/// Window layout for the editor/preview split.
public enum MarkdownLayout: String, CaseIterable, Codable, Sendable {
    case split
    case editor
    case preview

    public var label: String {
        switch self {
        case .split: return "Split"
        case .editor: return "Editor"
        case .preview: return "Preview"
        }
    }
}

/// One entry in the recent-files list. The URL is an absolute path string;
/// no security-scoped bookmark is stored, so a stale entry surfaces a clean
/// error when the file is gone instead of silently re-granting access.
public struct MarkdownRecentFile: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public let url: URL
    public let name: String
    public let lastOpened: Date

    public init(id: UUID = UUID(), url: URL, name: String, lastOpened: Date = Date()) {
        self.id = id
        self.url = url
        self.name = name
        self.lastOpened = lastOpened
    }

    enum CodingKeys: String, CodingKey {
        case id, url, name, lastOpened
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.url = try c.decode(URL.self, forKey: .url)
        self.name = try c.decodeIfPresent(String.self, forKey: .name) ?? url.lastPathComponent
        self.lastOpened = try c.decodeIfPresent(Date.self, forKey: .lastOpened) ?? Date()
    }
}

/// User-tunable Markdown Viewer settings. Persisted as JSON to a single
/// Settings key so the recent-files list and shortcut travel with the user.
public struct MarkdownViewerSettings: Sendable, Equatable, Codable {
    public var hotkeyEnabled: Bool
    public var hotkey: GlobalHotkey.Definition?
    public var theme: MarkdownTheme
    public var fontSize: Int
    public var layout: MarkdownLayout
    public var showLineNumbers: Bool
    public var openFinderSelectionWithHotkey: Bool
    public var recentFiles: [MarkdownRecentFile]

    public init(
        hotkeyEnabled: Bool = true,
        hotkey: GlobalHotkey.Definition? = GlobalHotkey.defaultMarkdownViewerHotkey,
        theme: MarkdownTheme = .auto,
        fontSize: Int = 14,
        layout: MarkdownLayout = .split,
        showLineNumbers: Bool = false,
        openFinderSelectionWithHotkey: Bool = false,
        recentFiles: [MarkdownRecentFile] = []
    ) {
        self.hotkeyEnabled = hotkeyEnabled
        self.hotkey = hotkey
        self.theme = theme
        self.fontSize = fontSize
        self.layout = layout
        self.showLineNumbers = showLineNumbers
        self.openFinderSelectionWithHotkey = openFinderSelectionWithHotkey
        self.recentFiles = recentFiles
    }

    public static let fontSizeMin = 12
    public static let fontSizeMax = 24
    public static let recentFilesMax = 8

    enum CodingKeys: String, CodingKey {
        case hotkeyEnabled, hotkey, theme, fontSize, layout, showLineNumbers
        case openFinderSelectionWithHotkey
        case recentFiles
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.hotkeyEnabled = try c.decodeIfPresent(Bool.self, forKey: .hotkeyEnabled) ?? true
        self.hotkey = try c.decodeIfPresent(GlobalHotkey.Definition.self, forKey: .hotkey)
            ?? GlobalHotkey.defaultMarkdownViewerHotkey
        self.theme = try c.decodeIfPresent(MarkdownTheme.self, forKey: .theme) ?? .auto
        self.fontSize = try c.decodeIfPresent(Int.self, forKey: .fontSize) ?? 14
        self.layout = try c.decodeIfPresent(MarkdownLayout.self, forKey: .layout) ?? .split
        self.showLineNumbers = try c.decodeIfPresent(Bool.self, forKey: .showLineNumbers) ?? false
        self.openFinderSelectionWithHotkey = try c.decodeIfPresent(Bool.self, forKey: .openFinderSelectionWithHotkey) ?? false
        self.recentFiles = try c.decodeIfPresent([MarkdownRecentFile].self, forKey: .recentFiles) ?? []
    }

    public static func sanitized(
        hotkeyEnabled: Bool,
        hotkey: GlobalHotkey.Definition?,
        theme: MarkdownTheme,
        fontSize: Int,
        layout: MarkdownLayout,
        showLineNumbers: Bool,
        openFinderSelectionWithHotkey: Bool,
        recentFiles: [MarkdownRecentFile]
    ) -> MarkdownViewerSettings {
        let clampedFont = min(max(fontSize, fontSizeMin), fontSizeMax)
        let capped = Array(recentFiles.prefix(recentFilesMax))
        return MarkdownViewerSettings(
            hotkeyEnabled: hotkeyEnabled,
            hotkey: hotkey,
            theme: theme,
            fontSize: clampedFont,
            layout: layout,
            showLineNumbers: showLineNumbers,
            openFinderSelectionWithHotkey: openFinderSelectionWithHotkey,
            recentFiles: capped
        )
    }
}

public enum MarkdownViewerSettingsKey {
    public static let settings = SettingsKey("modules.markdown-viewer.settings")
}

public extension SettingsStore {
    func loadMarkdownViewerSettings() -> MarkdownViewerSettings {
        guard let data = self.data(MarkdownViewerSettingsKey.settings) else {
            return MarkdownViewerSettings()
        }
        return (try? JSONDecoder().decode(MarkdownViewerSettings.self, from: data))
            ?? MarkdownViewerSettings()
    }

    func saveMarkdownViewerSettings(_ settings: MarkdownViewerSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        self.setData(data, MarkdownViewerSettingsKey.settings)
    }
}

public extension GlobalHotkey {
    /// `⌥⌘M` — M for Markdown. Free chord per `docs/modules.md`.
    /// `id` 501 follows the Snippets 401 namespace block.
    static var defaultMarkdownViewerHotkey: Definition? {
        Definition(keyCode: UInt32(kVK_ANSI_M), modifiers: UInt32(cmdKey | optionKey), id: 501)
    }
}
