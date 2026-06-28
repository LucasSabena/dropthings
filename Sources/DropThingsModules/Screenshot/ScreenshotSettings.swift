import Foundation
import DropThingsCore
import DropThingsPlatform

/// User-tunable Screenshot Capture settings.
public struct ScreenshotSettings: Sendable, Equatable, Codable {
    public var hotkeyEnabled: Bool
    public var saveFolderBookmark: Data?
    public var lastSavePath: String?
    public var hotkey: GlobalHotkey.Definition?

    public init(
        hotkeyEnabled: Bool = true,
        saveFolderBookmark: Data? = nil,
        lastSavePath: String? = nil,
        hotkey: GlobalHotkey.Definition? = GlobalHotkey.defaultScreenshotHotkey
    ) {
        self.hotkeyEnabled = hotkeyEnabled
        self.saveFolderBookmark = saveFolderBookmark
        self.lastSavePath = lastSavePath
        self.hotkey = hotkey
    }

    enum CodingKeys: String, CodingKey {
        case hotkeyEnabled, saveFolderBookmark, lastSavePath, hotkey
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.hotkeyEnabled = try c.decodeIfPresent(Bool.self, forKey: .hotkeyEnabled) ?? true
        self.saveFolderBookmark = try c.decodeIfPresent(Data.self, forKey: .saveFolderBookmark)
        self.lastSavePath = try c.decodeIfPresent(String.self, forKey: .lastSavePath)
        self.hotkey = try c.decodeIfPresent(GlobalHotkey.Definition.self, forKey: .hotkey)
            ?? GlobalHotkey.defaultScreenshotHotkey
    }
}

public enum ScreenshotSettingsKey {
    public static let settings = SettingsKey("modules.screenshot.settings")
}

public extension SettingsStore {
    func loadScreenshotSettings() -> ScreenshotSettings {
        guard let data = self.data(ScreenshotSettingsKey.settings) else {
            return ScreenshotSettings()
        }
        return (try? JSONDecoder().decode(ScreenshotSettings.self, from: data))
            ?? ScreenshotSettings()
    }

    func saveScreenshotSettings(_ settings: ScreenshotSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        self.setData(data, ScreenshotSettingsKey.settings)
    }
}

