import Foundation
import DropThingsCore
import DropThingsPlatform

/// Per-item hide preferences. Persisted as a set of `MenuBarItem.id`
/// values; everything else is left at whatever the OS chose to render.
public struct MenuBarCleanerSettings: Sendable, Equatable, Codable {
    public var hiddenItemIds: Set<String>

    public init(hiddenItemIds: Set<String> = []) {
        self.hiddenItemIds = hiddenItemIds
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
