import Foundation
import DropThingsCore
import DropThingsPlatform

/// User-tunable Keep Awake settings.
public struct KeepAwakeSettings: Sendable, Equatable, Codable {
    public var preferredReason: KeepAwakeAssertion.Reason
    public var restoreOnLaunch: Bool

    public init(
        preferredReason: KeepAwakeAssertion.Reason = .systemSleep,
        restoreOnLaunch: Bool = false
    ) {
        self.preferredReason = preferredReason
        self.restoreOnLaunch = restoreOnLaunch
    }

    enum CodingKeys: String, CodingKey {
        case preferredReason, restoreOnLaunch
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let reasonRaw = try c.decodeIfPresent(String.self, forKey: .preferredReason)
        self.preferredReason = reasonRaw.flatMap(KeepAwakeAssertion.Reason.init(rawValue:)) ?? .systemSleep
        self.restoreOnLaunch = try c.decodeIfPresent(Bool.self, forKey: .restoreOnLaunch) ?? false
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
