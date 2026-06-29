import Foundation
import Carbon.HIToolbox
import DropThingsCore
import DropThingsPlatform

/// User-tunable Command Palette settings. Persisted as JSON so the migration
/// path stays explicit when fields are added.
public struct CommandPaletteSettings: Sendable, Equatable, Codable {
    public var hotkeyEnabled: Bool
    public var hotkey: GlobalHotkey.Definition?

    public init(
        hotkeyEnabled: Bool = true,
        hotkey: GlobalHotkey.Definition? = GlobalHotkey.defaultCommandPaletteHotkey
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
            ?? GlobalHotkey.defaultCommandPaletteHotkey
    }

    public static func sanitized(
        hotkeyEnabled: Bool,
        hotkey: GlobalHotkey.Definition?
    ) -> CommandPaletteSettings {
        CommandPaletteSettings(
            hotkeyEnabled: hotkeyEnabled,
            hotkey: hotkey
        )
    }
}

public enum CommandPaletteSettingsKey {
    public static let settings = SettingsKey("modules.command-palette.settings")
}

public extension SettingsStore {
    func loadCommandPaletteSettings() -> CommandPaletteSettings {
        guard let data = self.data(CommandPaletteSettingsKey.settings) else {
            return CommandPaletteSettings()
        }
        return (try? JSONDecoder().decode(CommandPaletteSettings.self, from: data))
            ?? CommandPaletteSettings()
    }

    func saveCommandPaletteSettings(_ settings: CommandPaletteSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        self.setData(data, CommandPaletteSettingsKey.settings)
    }
}

public extension GlobalHotkey {
    static var defaultCommandPaletteHotkey: Definition? {
        Definition(keyCode: UInt32(kVK_Space), modifiers: UInt32(controlKey), id: 4)
    }
}
