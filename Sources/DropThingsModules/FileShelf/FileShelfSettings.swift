import Foundation
import DropThingsCore
import DropThingsPlatform

/// User-tunable File Shelf settings. Persisted as JSON to a single key
/// so the migration path stays explicit when fields are added.
public struct FileShelfSettings: Sendable, Equatable, Codable {
    public static let maxItemsDefault = 50
    public static let maxItemsHardLimit = 500

    public var maxItems: Int
    public var clearOnQuit: Bool
    public var shakeToShow: Bool
    public var hotkey: GlobalHotkey.Definition?

    public init(
        maxItems: Int = FileShelfSettings.maxItemsDefault,
        clearOnQuit: Bool = true,
        shakeToShow: Bool = true,
        hotkey: GlobalHotkey.Definition? = GlobalHotkey.defaultShelfHotkey
    ) {
        self.maxItems = maxItems
        self.clearOnQuit = clearOnQuit
        self.shakeToShow = shakeToShow
        self.hotkey = hotkey
    }

    enum CodingKeys: String, CodingKey {
        case maxItems, clearOnQuit, shakeToShow, hotkey
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.maxItems = try c.decodeIfPresent(Int.self, forKey: .maxItems) ?? FileShelfSettings.maxItemsDefault
        self.clearOnQuit = try c.decodeIfPresent(Bool.self, forKey: .clearOnQuit) ?? true
        self.shakeToShow = try c.decodeIfPresent(Bool.self, forKey: .shakeToShow) ?? true
        self.hotkey = try c.decodeIfPresent(GlobalHotkey.Definition.self, forKey: .hotkey)
            ?? GlobalHotkey.defaultShelfHotkey
    }

    public static func sanitized(
        maxItems: Int,
        clearOnQuit: Bool,
        shakeToShow: Bool,
        hotkey: GlobalHotkey.Definition?
    ) -> FileShelfSettings {
        let clamped = min(max(maxItems, 1), maxItemsHardLimit)
        return FileShelfSettings(
            maxItems: clamped,
            clearOnQuit: clearOnQuit,
            shakeToShow: shakeToShow,
            hotkey: hotkey
        )
    }
}

public enum FileShelfSettingsKey {
    public static let settings = SettingsKey("modules.file-shelf.settings")
}

public extension SettingsStore {
    func loadFileShelfSettings() -> FileShelfSettings {
        guard let data = self.data(FileShelfSettingsKey.settings) else {
            return FileShelfSettings()
        }
        return (try? JSONDecoder().decode(FileShelfSettings.self, from: data))
            ?? FileShelfSettings()
    }

    func saveFileShelfSettings(_ settings: FileShelfSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        self.setData(data, FileShelfSettingsKey.settings)
    }
}
