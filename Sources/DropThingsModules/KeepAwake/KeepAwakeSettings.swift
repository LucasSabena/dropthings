import Foundation
import DropThingsCore

/// User-tunable Keep Awake settings. v1 collapses to a single toggle:
/// "Keep Mac awake". On, the module holds a `PreventUserIdleSystemSleep`
/// assertion; off, normal power behavior.
public struct KeepAwakeSettings: Sendable, Equatable, Codable {
    public var enabled: Bool
    public var keepDisplayAwake: Bool
    /// `nil` means until manually disabled. Presets are expressed in minutes.
    public var durationMinutes: Int?
    /// Absolute end date lets a timed session continue correctly across an app
    /// relaunch instead of silently becoming indefinite.
    public var activeUntil: Date?

    public init(
        enabled: Bool = false,
        keepDisplayAwake: Bool = false,
        durationMinutes: Int? = nil,
        activeUntil: Date? = nil
    ) {
        self.enabled = enabled
        self.keepDisplayAwake = keepDisplayAwake
        self.durationMinutes = durationMinutes
        self.activeUntil = activeUntil
    }

    enum CodingKeys: String, CodingKey {
        case enabled, keepDisplayAwake, durationMinutes, activeUntil
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? false
        self.keepDisplayAwake = try c.decodeIfPresent(Bool.self, forKey: .keepDisplayAwake) ?? false
        self.durationMinutes = try c.decodeIfPresent(Int.self, forKey: .durationMinutes)
        self.activeUntil = try c.decodeIfPresent(Date.self, forKey: .activeUntil)
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
