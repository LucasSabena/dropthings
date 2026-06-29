import Foundation
import Carbon.HIToolbox
import DropThingsCore
import DropThingsPlatform

/// User-tunable Snippets settings. Persisted as JSON to a single Settings key
/// so snippets move with the user across launches and import/export.
public struct SnippetsSettings: Sendable, Equatable, Codable {
    public var hotkeyEnabled: Bool
    public var hotkey: GlobalHotkey.Definition?
    public var snippets: [Snippet]

    public init(
        hotkeyEnabled: Bool = true,
        hotkey: GlobalHotkey.Definition? = GlobalHotkey.defaultSnippetsHotkey,
        snippets: [Snippet] = []
    ) {
        self.hotkeyEnabled = hotkeyEnabled
        self.hotkey = hotkey
        self.snippets = snippets
    }

    public static let snippetsMaxCount = 10_000

    enum CodingKeys: String, CodingKey {
        case hotkeyEnabled, hotkey, snippets
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.hotkeyEnabled = try container.decodeIfPresent(Bool.self, forKey: .hotkeyEnabled) ?? true
        self.hotkey = try container.decodeIfPresent(GlobalHotkey.Definition.self, forKey: .hotkey)
            ?? GlobalHotkey.defaultSnippetsHotkey
        self.snippets = try container.decodeIfPresent([Snippet].self, forKey: .snippets) ?? []
    }

    public static func sanitized(
        hotkeyEnabled: Bool,
        hotkey: GlobalHotkey.Definition?,
        snippets: [Snippet]
    ) -> SnippetsSettings {
        let trimmed = snippets
            .map { Snippet(
                id: $0.id,
                title: $0.title.trimmingCharacters(in: .whitespacesAndNewlines),
                content: $0.content,
                keyword: Snippet.normalizedKeyword($0.keyword)
            ) }
            .filter { !$0.isEmpty }
        let capped = Array(trimmed.suffix(snippetsMaxCount))
        return SnippetsSettings(
            hotkeyEnabled: hotkeyEnabled,
            hotkey: hotkey,
            snippets: capped
        )
    }
}

public enum SnippetsSettingsKey {
    public static let settings = SettingsKey("modules.snippets.settings")
}

public extension SettingsStore {
    func loadSnippetsSettings() -> SnippetsSettings {
        guard let data = self.data(SnippetsSettingsKey.settings) else {
            return SnippetsSettings()
        }
        return (try? JSONDecoder().decode(SnippetsSettings.self, from: data)) ?? SnippetsSettings()
    }

    func saveSnippetsSettings(_ settings: SnippetsSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        self.setData(data, SnippetsSettingsKey.settings)
    }
}

public extension GlobalHotkey {
    static var defaultSnippetsHotkey: Definition? {
        Definition(keyCode: UInt32(kVK_ANSI_S), modifiers: UInt32(controlKey | optionKey), id: 401)
    }
}
