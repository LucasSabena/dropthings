import Foundation
import Carbon.HIToolbox
import DropThingsCore
import DropThingsPlatform

/// User-tunable Text Tools settings. v1 stores the hotkey and whether the
/// global shortcut is enabled. The floating window size is not persisted so
/// we avoid migrations for a simple utility panel.
public struct TextToolsSettings: Sendable, Equatable, Codable {
    public var hotkeyEnabled: Bool
    public var hotkey: GlobalHotkey.Definition?

    public init(
        hotkeyEnabled: Bool = true,
        hotkey: GlobalHotkey.Definition? = GlobalHotkey.defaultTextToolsHotkey
    ) {
        self.hotkeyEnabled = hotkeyEnabled
        self.hotkey = hotkey
    }

    enum CodingKeys: String, CodingKey {
        case hotkeyEnabled, hotkey
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.hotkeyEnabled = try c.decodeIfPresent(Bool.self, forKey: .hotkeyEnabled) ?? true
        self.hotkey = try c.decodeIfPresent(GlobalHotkey.Definition.self, forKey: .hotkey)
            ?? GlobalHotkey.defaultTextToolsHotkey
    }

    public static func sanitized(
        hotkeyEnabled: Bool,
        hotkey: GlobalHotkey.Definition?
    ) -> TextToolsSettings {
        TextToolsSettings(hotkeyEnabled: hotkeyEnabled, hotkey: hotkey)
    }
}

public enum TextToolsSettingsKey {
    public static let settings = SettingsKey("modules.text-tools.settings")
}

public extension SettingsStore {
    func loadTextToolsSettings() -> TextToolsSettings {
        guard let data = self.data(TextToolsSettingsKey.settings) else {
            return TextToolsSettings()
        }
        return (try? JSONDecoder().decode(TextToolsSettings.self, from: data))
            ?? TextToolsSettings()
    }

    func saveTextToolsSettings(_ settings: TextToolsSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        self.setData(data, TextToolsSettingsKey.settings)
    }
}

public extension GlobalHotkey {
    static var defaultTextToolsHotkey: Definition? {
        Definition(keyCode: UInt32(kVK_ANSI_T), modifiers: UInt32(cmdKey | optionKey), id: 302)
    }
}
