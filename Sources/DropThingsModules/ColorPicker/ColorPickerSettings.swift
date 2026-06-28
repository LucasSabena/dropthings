import Foundation
import DropThingsCore
import DropThingsPlatform

/// One color the user picked via the Color Picker module. Stored in a
/// rolling history capped by `Settings.historyLimit`. Favorites are
/// pinned to the top of the history and never evicted by the cap.
public struct PickedColor: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let r: Int
    public let g: Int
    public let b: Int
    public var isFavorite: Bool

    public init(id: UUID = UUID(), timestamp: Date = Date(), r: Int, g: Int, b: Int, isFavorite: Bool = false) {
        self.id = id
        self.timestamp = timestamp
        self.r = r
        self.g = g
        self.b = b
        self.isFavorite = isFavorite
    }

    enum CodingKeys: String, CodingKey {
        case id, timestamp, r, g, b, isFavorite
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.timestamp = try c.decodeIfPresent(Date.self, forKey: .timestamp) ?? Date()
        self.r = try c.decode(Int.self, forKey: .r)
        self.g = try c.decode(Int.self, forKey: .g)
        self.b = try c.decode(Int.self, forKey: .b)
        // Added after the field shipped — older blobs don't have it.
        self.isFavorite = try c.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
    }

    public var hex: String { String(format: "#%02X%02X%02X", r, g, b) }
    public var rgbString: String { "rgb(\(r), \(g), \(b))" }

    public var rgb: PixelSampler.RGB {
        PixelSampler.RGB(r: r, g: g, b: b)
    }

    public var hsl: ColorMath.HSL { ColorMath.rgbToHSL(r: r, g: g, b: b) }

    public var lighter: PickedColor { PickedColor.from(hsl: ColorMath.lighter(hsl, amount: 0.15)) }
    public var darker: PickedColor { PickedColor.from(hsl: ColorMath.darker(hsl, amount: 0.15)) }
    public var saturated: PickedColor { PickedColor.from(hsl: ColorMath.saturated(hsl, amount: 0.2)) }
    public var desaturated: PickedColor { PickedColor.from(hsl: ColorMath.desaturated(hsl, amount: 0.2)) }
    public var complement: PickedColor { PickedColor.from(hsl: ColorMath.complement(hsl)) }
    public var analogues: [PickedColor] { ColorMath.analogues(hsl).map { PickedColor.from(hsl: $0) } }

    public static func from(hsl: ColorMath.HSL, timestamp: Date = Date()) -> PickedColor {
        let rgb = ColorMath.hslToRGB(h: hsl.h, s: hsl.s, l: hsl.l)
        return PickedColor(timestamp: timestamp, r: rgb.r, g: rgb.g, b: rgb.b)
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
    public var copyFormat: ColorCopyFormat

    public init(
        hotkeyEnabled: Bool = true,
        history: [PickedColor] = [],
        historyLimit: Int = 24,
        hotkey: GlobalHotkey.Definition? = GlobalHotkey.defaultColorPickerHotkey,
        copyFormat: ColorCopyFormat = .hex
    ) {
        self.hotkeyEnabled = hotkeyEnabled
        self.history = history
        self.historyLimit = historyLimit
        self.hotkey = hotkey
        self.copyFormat = copyFormat
    }

    public static let historyLimitDefault = 24
    public static let historyLimitMax = 200

    enum CodingKeys: String, CodingKey {
        case hotkeyEnabled, history, historyLimit, hotkey, copyFormat
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.hotkeyEnabled = try c.decodeIfPresent(Bool.self, forKey: .hotkeyEnabled) ?? true
        self.history = try c.decodeIfPresent([PickedColor].self, forKey: .history) ?? []
        self.historyLimit = try c.decodeIfPresent(Int.self, forKey: .historyLimit) ?? ColorPickerSettings.historyLimitDefault
        self.hotkey = try c.decodeIfPresent(GlobalHotkey.Definition.self, forKey: .hotkey)
            ?? GlobalHotkey.defaultColorPickerHotkey
        self.copyFormat = try c.decodeIfPresent(ColorCopyFormat.self, forKey: .copyFormat) ?? .hex
    }

    public static func sanitized(
        hotkeyEnabled: Bool,
        history: [PickedColor],
        historyLimit: Int,
        hotkey: GlobalHotkey.Definition?,
        copyFormat: ColorCopyFormat = .hex
    ) -> ColorPickerSettings {
        let clamped = min(max(historyLimit, 1), historyLimitMax)
        // Favorites always survive the cap. When the cap is larger than
        // the favorite count, fill the rest with the newest non-favorites.
        // When the cap is smaller than the favorite count, keep the
        // newest favorites and drop the oldest + all non-favorites.
        let favorites = history.filter(\.isFavorite)
        let others = history.filter { !$0.isFavorite }
        let keptFavorites: [PickedColor]
        let keptOthers: [PickedColor]
        if favorites.count >= clamped {
            keptFavorites = Array(favorites.suffix(clamped))
            keptOthers = []
        } else {
            keptFavorites = favorites
            keptOthers = Array(others.prefix(clamped - favorites.count))
        }
        return ColorPickerSettings(
            hotkeyEnabled: hotkeyEnabled,
            history: keptFavorites + keptOthers,
            historyLimit: clamped,
            hotkey: hotkey,
            copyFormat: copyFormat
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
