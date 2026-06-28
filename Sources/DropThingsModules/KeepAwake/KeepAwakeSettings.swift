import Foundation
import DropThingsCore

/// User-tunable Keep Awake settings. v1 collapses to a single toggle:
/// "Keep Mac awake". On, the module holds a `PreventUserIdleSystemSleep`
/// assertion; off, normal power behavior.
public struct KeepAwakeSettings: Sendable, Equatable, Codable {
    public var enabled: Bool

    public init(enabled: Bool = false) {
        self.enabled = enabled
    }

    enum CodingKeys: String, CodingKey {
        case enabled
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? false
    }
}

public enum KeepAwakeSettingsKey {
    public static let settings = SettingsKey("modules.keep-awake.settings")
}

public extension SettingsStore {
    func loadKeepAwakeSettings() -> KeepAwakeSettings {
        guard let data = self.data(KeepAwakeSettingsKey.settings) else {
            return KeepAwakeSettings()
        }
        return (try? JSONDecoder().decode(KeepAwakeSettings.self, from: data))
            ?? KeepAwakeSettings()
    }

    func saveKeepAwakeSettings(_ settings: KeepAwakeSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        self.setData(data, KeepAwakeSettingsKey.settings)
    }
}
