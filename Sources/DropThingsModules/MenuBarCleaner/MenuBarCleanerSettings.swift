import Foundation
import DropThingsCore

/// User preferences for the Hidden-Bar-style overflow area. The user decides
/// what belongs in that area by holding Command and dragging menu bar items
/// to the left of DropThings' divider.
public struct MenuBarCleanerSettings: Sendable, Equatable, Codable {
    public var collapseOnLaunch: Bool

    public init(collapseOnLaunch: Bool = false) {
        self.collapseOnLaunch = collapseOnLaunch
    }

    enum CodingKeys: String, CodingKey {
        case collapseOnLaunch
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.collapseOnLaunch = try c.decodeIfPresent(Bool.self, forKey: .collapseOnLaunch) ?? false
    }
}

public enum MenuBarCleanerSettingsKey {
    public static let settings = SettingsKey("modules.menu-bar-cleaner.settings")
}

public extension SettingsStore {
    func loadMenuBarCleanerSettings() -> MenuBarCleanerSettings {
        guard let data = self.data(MenuBarCleanerSettingsKey.settings) else {
            return MenuBarCleanerSettings()
        }
        return (try? JSONDecoder().decode(MenuBarCleanerSettings.self, from: data))
            ?? MenuBarCleanerSettings()
    }

    func saveMenuBarCleanerSettings(_ settings: MenuBarCleanerSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        self.setData(data, MenuBarCleanerSettingsKey.settings)
    }
}
