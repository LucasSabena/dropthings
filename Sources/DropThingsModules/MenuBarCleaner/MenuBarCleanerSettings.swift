import Foundation
import DropThingsCore

/// User preferences for the Hidden-Bar-style overflow area. The user decides
/// what belongs in that area by holding Command and dragging menu bar items
/// to the left of DropThings' divider.
public struct MenuBarCleanerSettings: Sendable, Equatable, Codable {
    public var collapseOnLaunch: Bool
    /// Delay before hover reveals the overflow area. `0` means hover reveal
    /// is disabled; `0.5` and `1.0` are the supported presets.
    public var hoverRevealDelay: TimeInterval
    /// Named profiles that remember collapse state. The active profile is
    /// the user's explicit choice; switching profiles updates collapse.
    public var profiles: [MenuBarCleanerProfile]
    public var activeProfileID: UUID?
    /// Bundle identifiers of status items that should stay visible even when
    /// the overflow area is collapsed.
    public var alwaysVisibleBundleIDs: [String]

    public init(
        collapseOnLaunch: Bool = false,
        hoverRevealDelay: TimeInterval = 0,
        profiles: [MenuBarCleanerProfile] = [MenuBarCleanerProfile(id: .work), MenuBarCleanerProfile(id: .focus), MenuBarCleanerProfile(id: .presentation)],
        activeProfileID: UUID? = nil,
        alwaysVisibleBundleIDs: [String] = []
    ) {
        self.collapseOnLaunch = collapseOnLaunch
        self.hoverRevealDelay = hoverRevealDelay
        self.profiles = profiles
        self.activeProfileID = activeProfileID
        self.alwaysVisibleBundleIDs = alwaysVisibleBundleIDs
    }

    enum CodingKeys: String, CodingKey {
        case collapseOnLaunch, hoverRevealDelay, profiles, activeProfileID, alwaysVisibleBundleIDs
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.collapseOnLaunch = try c.decodeIfPresent(Bool.self, forKey: .collapseOnLaunch) ?? false
        self.hoverRevealDelay = try c.decodeIfPresent(TimeInterval.self, forKey: .hoverRevealDelay) ?? 0
        self.profiles = try c.decodeIfPresent([MenuBarCleanerProfile].self, forKey: .profiles)
            ?? [MenuBarCleanerProfile(id: .work), MenuBarCleanerProfile(id: .focus), MenuBarCleanerProfile(id: .presentation)]
        self.activeProfileID = try c.decodeIfPresent(UUID.self, forKey: .activeProfileID)
        self.alwaysVisibleBundleIDs = try c.decodeIfPresent([String].self, forKey: .alwaysVisibleBundleIDs) ?? []
    }

    public var activeProfile: MenuBarCleanerProfile? {
        profiles.first { $0.id == activeProfileID }
    }
}

/// A profile remembers whether the overflow area should be collapsed. Built-in
/// profiles cover common contexts; the user can rename them and switch quickly.
public struct MenuBarCleanerProfile: Sendable, Equatable, Codable, Identifiable {
    public let id: UUID
    public var name: String
    public var collapsed: Bool

    public init(id: UUID, name: String, collapsed: Bool) {
        self.id = id
        self.name = name
        self.collapsed = collapsed
    }

    public init(id: ProfileID) {
        self.id = id.id
        self.name = id.defaultName
        self.collapsed = id.defaultCollapsed
    }

    public enum ProfileID: String, CaseIterable, Sendable {
        case work, focus, presentation

        public var id: UUID {
            switch self {
            case .work: return UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
            case .focus: return UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
            case .presentation: return UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
            }
        }

        public var defaultName: String {
            switch self {
            case .work: return "Work"
            case .focus: return "Focus"
            case .presentation: return "Presentation"
            }
        }

        public var defaultCollapsed: Bool {
            switch self {
            case .work: return true
            case .focus: return false
            case .presentation: return true
            }
        }
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
