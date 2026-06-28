import Foundation
import DropThingsCore
import DropThingsPlatform

/// One color the user picked via the Color Picker module. Stored in a
/// rolling history capped by `Settings.historyLimit`.
public struct PickedColor: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let r: Int
    public let g: Int
    public let b: Int

    public init(id: UUID = UUID(), timestamp: Date = Date(), r: Int, g: Int, b: Int) {
        self.id = id
        self.timestamp = timestamp
        self.r = r
        self.g = g
        self.b = b
    }

    public var hex: String { String(format: "#%02X%02X%02X", r, g, b) }
    public var rgbString: String { "rgb(\(r), \(g), \(b))" }

    public var rgb: PixelSampler.RGB {
        PixelSampler.RGB(r: r, g: g, b: b)
    }

    public static func from(rgb: PixelSampler.RGB, timestamp: Date = Date()) -> PickedColor {
        PickedColor(timestamp: timestamp, r: rgb.r, g: rgb.g, b: rgb.b)
    }
}

/// User-tunable Color Picker settings. Persisted as JSON to a single
/// Settings key so the history moves with the user across launches.
public struct ColorPickerSettings: Sendable, Equatable, Codable {
    public var hotkeyEnabled: Bool
    public var history: [PickedColor]
    public var historyLimit: Int
    public var hotkey: GlobalHotkey.Definition?

    public init(
        hotkeyEnabled: Bool = true,
        history: [PickedColor] = [],
        historyLimit: Int = 24,
        hotkey: GlobalHotkey.Definition? = GlobalHotkey.defaultColorPickerHotkey
    ) {
        self.hotkeyEnabled = hotkeyEnabled
        self.history = history
        self.historyLimit = historyLimit
        self.hotkey = hotkey
    }

    public static let historyLimitDefault = 24
    public static let historyLimitMax = 200

    enum CodingKeys: String, CodingKey {
        case hotkeyEnabled, history, historyLimit, hotkey
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.hotkeyEnabled = try c.decodeIfPresent(Bool.self, forKey: .hotkeyEnabled) ?? true
        self.history = try c.decodeIfPresent([PickedColor].self, forKey: .history) ?? []
        self.historyLimit = try c.decodeIfPresent(Int.self, forKey: .historyLimit) ?? ColorPickerSettings.historyLimitDefault
        self.hotkey = try c.decodeIfPresent(GlobalHotkey.Definition.self, forKey: .hotkey)
            ?? GlobalHotkey.defaultColorPickerHotkey
    }

    public static func sanitized(
        hotkeyEnabled: Bool,
        history: [PickedColor],
        historyLimit: Int,
        hotkey: GlobalHotkey.Definition?
    ) -> ColorPickerSettings {
        let clamped = min(max(historyLimit, 1), historyLimitMax)
        return ColorPickerSettings(
            hotkeyEnabled: hotkeyEnabled,
            history: Array(history.prefix(clamped)),
            historyLimit: clamped,
            hotkey: hotkey
        )
    }
}

public enum ColorPickerSettingsKey {
    public static let settings = SettingsKey("modules.color-picker.settings")
}

public extension SettingsStore {
    func loadColorPickerSettings() -> ColorPickerSettings {
        guard let data = self.data(ColorPickerSettingsKey.settings) else {
            return ColorPickerSettings()
        }
        return (try? JSONDecoder().decode(ColorPickerSettings.self, from: data))
            ?? ColorPickerSettings()
    }

    func saveColorPickerSettings(_ settings: ColorPickerSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        self.setData(data, ColorPickerSettingsKey.settings)
    }
}
