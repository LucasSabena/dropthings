import Foundation
import CoreGraphics
import DropThingsCore
import DropThingsPlatform

/// Direction the user wants scroll to move for a given device category.
public enum ScrollDirection: String, Codable, Sendable, CaseIterable {
    /// Default macOS behavior for the device — "natural" for trackpads,
    /// inverted from the user's hand motion for a mouse wheel.
    case natural
    /// Invert the natural direction. Used so a mouse wheel can feel like a
    /// Windows trackpad for users who came from Windows.
    case inverted
}

/// Per-device-category scroll preferences. Magic Mouse is grouped with
/// trackpads by default because it sends scroll events with momentum.
public struct ScrollSettings: Sendable, Equatable, Codable {
    public var trackpadDirection: ScrollDirection
    public var mouseWheelDirection: ScrollDirection
    public var magicMouseDirection: ScrollDirection
    public var horizontalScrollEnabled: Bool
    public var scrollMultiplier: Double
    public var hotkey: GlobalHotkey.Definition?

    public init(
        trackpadDirection: ScrollDirection = .natural,
        mouseWheelDirection: ScrollDirection = .inverted,
        magicMouseDirection: ScrollDirection = .natural,
        horizontalScrollEnabled: Bool = true,
        scrollMultiplier: Double = 1.0,
        hotkey: GlobalHotkey.Definition? = nil
    ) {
        self.trackpadDirection = trackpadDirection
        self.mouseWheelDirection = mouseWheelDirection
        self.magicMouseDirection = magicMouseDirection
        self.horizontalScrollEnabled = horizontalScrollEnabled
        self.scrollMultiplier = scrollMultiplier
        self.hotkey = hotkey
    }

    enum CodingKeys: String, CodingKey {
        case trackpadDirection, mouseWheelDirection, magicMouseDirection
        case horizontalScrollEnabled, scrollMultiplier, hotkey
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.trackpadDirection = try c.decodeIfPresent(ScrollDirection.self, forKey: .trackpadDirection) ?? .natural
        self.mouseWheelDirection = try c.decodeIfPresent(ScrollDirection.self, forKey: .mouseWheelDirection) ?? .inverted
        self.magicMouseDirection = try c.decodeIfPresent(ScrollDirection.self, forKey: .magicMouseDirection) ?? .natural
        self.horizontalScrollEnabled = try c.decodeIfPresent(Bool.self, forKey: .horizontalScrollEnabled) ?? true
        self.scrollMultiplier = try c.decodeIfPresent(Double.self, forKey: .scrollMultiplier) ?? 1.0
        self.hotkey = try c.decodeIfPresent(GlobalHotkey.Definition.self, forKey: .hotkey)
    }

    public static let multiplierMin: Double = 0.1
    public static let multiplierMax: Double = 5.0

    public static func sanitized(
        trackpadDirection: ScrollDirection,
        mouseWheelDirection: ScrollDirection,
        magicMouseDirection: ScrollDirection,
        horizontalScrollEnabled: Bool,
        scrollMultiplier: Double,
        hotkey: GlobalHotkey.Definition?
    ) -> ScrollSettings {
        let clampedMultiplier = min(max(scrollMultiplier, multiplierMin), multiplierMax)
        return ScrollSettings(
            trackpadDirection: trackpadDirection,
            mouseWheelDirection: mouseWheelDirection,
            magicMouseDirection: magicMouseDirection,
            horizontalScrollEnabled: horizontalScrollEnabled,
            scrollMultiplier: clampedMultiplier,
            hotkey: hotkey
        )
    }

    public func direction(for kind: ScrollDeviceKind) -> ScrollDirection {
        switch kind {
        case .trackpad: return trackpadDirection
        case .mouseWheel: return mouseWheelDirection
        case .magicMouse: return magicMouseDirection
        case .unknown: return .natural
        }
    }
}

public enum ScrollSettingsKey {
    public static let settings = SettingsKey("modules.scroll-control.settings")
}

public extension SettingsStore {
    func loadScrollSettings() -> ScrollSettings {
        guard let data = self.data(ScrollSettingsKey.settings) else {
            return ScrollSettings()
        }
        return (try? JSONDecoder().decode(ScrollSettings.self, from: data))
            ?? ScrollSettings()
    }

    func saveScrollSettings(_ settings: ScrollSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        self.setData(data, ScrollSettingsKey.settings)
    }
}
