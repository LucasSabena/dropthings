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

/// Per-app scroll direction override. Keyed by the frontmost app's
/// bundle identifier so the override survives app relaunches. When the
/// active app has no override, the module falls back to the device
/// category default.
public struct ScrollAppOverride: Sendable, Equatable, Codable, Hashable, Identifiable {
    public var id: String { bundleID }
    public var bundleID: String
    public var direction: ScrollDirection
    public var multiplier: Double

    public init(bundleID: String, direction: ScrollDirection, multiplier: Double = 1.0) {
        self.bundleID = bundleID
        self.direction = direction
        self.multiplier = multiplier
    }
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
    /// Per-app direction overrides. A non-empty entry for the frontmost
    /// app wins over the device category default.
    public var appOverrides: [ScrollAppOverride]

    public init(
        trackpadDirection: ScrollDirection = .natural,
        mouseWheelDirection: ScrollDirection = .inverted,
        magicMouseDirection: ScrollDirection = .natural,
        horizontalScrollEnabled: Bool = true,
        scrollMultiplier: Double = 1.0,
        hotkey: GlobalHotkey.Definition? = nil,
        appOverrides: [ScrollAppOverride] = []
    ) {
        self.trackpadDirection = trackpadDirection
        self.mouseWheelDirection = mouseWheelDirection
        self.magicMouseDirection = magicMouseDirection
        self.horizontalScrollEnabled = horizontalScrollEnabled
        self.scrollMultiplier = scrollMultiplier
        self.hotkey = hotkey
        self.appOverrides = appOverrides
    }

    enum CodingKeys: String, CodingKey {
        case trackpadDirection, mouseWheelDirection, magicMouseDirection
        case horizontalScrollEnabled, scrollMultiplier, hotkey
        case appOverrides
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.trackpadDirection = try c.decodeIfPresent(ScrollDirection.self, forKey: .trackpadDirection) ?? .natural
        self.mouseWheelDirection = try c.decodeIfPresent(ScrollDirection.self, forKey: .mouseWheelDirection) ?? .inverted
        self.magicMouseDirection = try c.decodeIfPresent(ScrollDirection.self, forKey: .magicMouseDirection) ?? .natural
        self.horizontalScrollEnabled = try c.decodeIfPresent(Bool.self, forKey: .horizontalScrollEnabled) ?? true
        self.scrollMultiplier = try c.decodeIfPresent(Double.self, forKey: .scrollMultiplier) ?? 1.0
        self.hotkey = try c.decodeIfPresent(GlobalHotkey.Definition.self, forKey: .hotkey)
        self.appOverrides = try c.decodeIfPresent([ScrollAppOverride].self, forKey: .appOverrides) ?? []
    }

    public static let multiplierMin: Double = 0.1
    public static let multiplierMax: Double = 5.0

    public static func sanitized(
        trackpadDirection: ScrollDirection,
        mouseWheelDirection: ScrollDirection,
        magicMouseDirection: ScrollDirection,
        horizontalScrollEnabled: Bool,
        scrollMultiplier: Double,
        hotkey: GlobalHotkey.Definition?,
        appOverrides: [ScrollAppOverride] = []
    ) -> ScrollSettings {
        let clampedMultiplier = min(max(scrollMultiplier, multiplierMin), multiplierMax)
        // Dedupe overrides by bundle ID, last write wins, so the list
        // never grows unbounded if the user toggles an app repeatedly.
        var seen: [String: ScrollAppOverride] = [:]
        for override in appOverrides {
            var clamped = override
            clamped.multiplier = min(max(clamped.multiplier, multiplierMin), multiplierMax)
            seen[override.bundleID] = clamped
        }
        let deduped = Array(seen.values).sorted { $0.bundleID < $1.bundleID }
        return ScrollSettings(
            trackpadDirection: trackpadDirection,
            mouseWheelDirection: mouseWheelDirection,
            magicMouseDirection: magicMouseDirection,
            horizontalScrollEnabled: horizontalScrollEnabled,
            scrollMultiplier: clampedMultiplier,
            hotkey: hotkey,
            appOverrides: deduped
        )
    }

    /// Multiplier for a device category, with an optional per-app override.
    public func multiplier(for kind: ScrollDeviceKind, activeBundleID: String? = nil) -> Double {
        if let id = activeBundleID,
           let override = appOverrides.first(where: { $0.bundleID == id }) {
            return override.multiplier
        }
        return scrollMultiplier
    }

    /// Direction for a device category, with an optional per-app
    /// override. `activeBundleID` is the frontmost app's bundle
    /// identifier; an override for it wins over the device default.
    public func direction(for kind: ScrollDeviceKind, activeBundleID: String? = nil) -> ScrollDirection {
        if let id = activeBundleID,
           let override = appOverrides.first(where: { $0.bundleID == id }) {
            return override.direction
        }
        return defaultDirection(for: kind)
    }

    /// Device category default, ignoring per-app overrides.
    public func defaultDirection(for kind: ScrollDeviceKind) -> ScrollDirection {
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
