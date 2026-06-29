import Foundation
import DropThingsCore
import DropThingsPlatform

/// User-tunable WindowSnap settings. Each snap action has its own optional
/// global shortcut. Clearing a shortcut disables that action while leaving
/// the others active.
public struct WindowSnapSettings: Sendable, Equatable, Codable {
    public var maximizeHotkey: GlobalHotkey.Definition?
    public var leftHalfHotkey: GlobalHotkey.Definition?
    public var rightHalfHotkey: GlobalHotkey.Definition?
    public var topHalfHotkey: GlobalHotkey.Definition?
    public var bottomHalfHotkey: GlobalHotkey.Definition?
    public var topLeftHotkey: GlobalHotkey.Definition?
    public var topRightHotkey: GlobalHotkey.Definition?
    public var bottomLeftHotkey: GlobalHotkey.Definition?
    public var bottomRightHotkey: GlobalHotkey.Definition?

    public init(
        maximizeHotkey: GlobalHotkey.Definition? = WindowSnapAction.maximize.defaultHotkey,
        leftHalfHotkey: GlobalHotkey.Definition? = WindowSnapAction.leftHalf.defaultHotkey,
        rightHalfHotkey: GlobalHotkey.Definition? = WindowSnapAction.rightHalf.defaultHotkey,
        topHalfHotkey: GlobalHotkey.Definition? = WindowSnapAction.topHalf.defaultHotkey,
        bottomHalfHotkey: GlobalHotkey.Definition? = WindowSnapAction.bottomHalf.defaultHotkey,
        topLeftHotkey: GlobalHotkey.Definition? = WindowSnapAction.topLeft.defaultHotkey,
        topRightHotkey: GlobalHotkey.Definition? = WindowSnapAction.topRight.defaultHotkey,
        bottomLeftHotkey: GlobalHotkey.Definition? = WindowSnapAction.bottomLeft.defaultHotkey,
        bottomRightHotkey: GlobalHotkey.Definition? = WindowSnapAction.bottomRight.defaultHotkey
    ) {
        self.maximizeHotkey = maximizeHotkey
        self.leftHalfHotkey = leftHalfHotkey
        self.rightHalfHotkey = rightHalfHotkey
        self.topHalfHotkey = topHalfHotkey
        self.bottomHalfHotkey = bottomHalfHotkey
        self.topLeftHotkey = topLeftHotkey
        self.topRightHotkey = topRightHotkey
        self.bottomLeftHotkey = bottomLeftHotkey
        self.bottomRightHotkey = bottomRightHotkey
    }

    enum CodingKeys: String, CodingKey {
        case maximizeHotkey, leftHalfHotkey, rightHalfHotkey
        case topHalfHotkey, bottomHalfHotkey
        case topLeftHotkey, topRightHotkey
        case bottomLeftHotkey, bottomRightHotkey
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.maximizeHotkey = try c.decodeIfPresent(GlobalHotkey.Definition.self, forKey: .maximizeHotkey)
            ?? WindowSnapAction.maximize.defaultHotkey
        self.leftHalfHotkey = try c.decodeIfPresent(GlobalHotkey.Definition.self, forKey: .leftHalfHotkey)
            ?? WindowSnapAction.leftHalf.defaultHotkey
        self.rightHalfHotkey = try c.decodeIfPresent(GlobalHotkey.Definition.self, forKey: .rightHalfHotkey)
            ?? WindowSnapAction.rightHalf.defaultHotkey
        self.topHalfHotkey = try c.decodeIfPresent(GlobalHotkey.Definition.self, forKey: .topHalfHotkey)
            ?? WindowSnapAction.topHalf.defaultHotkey
        self.bottomHalfHotkey = try c.decodeIfPresent(GlobalHotkey.Definition.self, forKey: .bottomHalfHotkey)
            ?? WindowSnapAction.bottomHalf.defaultHotkey
        self.topLeftHotkey = try c.decodeIfPresent(GlobalHotkey.Definition.self, forKey: .topLeftHotkey)
            ?? WindowSnapAction.topLeft.defaultHotkey
        self.topRightHotkey = try c.decodeIfPresent(GlobalHotkey.Definition.self, forKey: .topRightHotkey)
            ?? WindowSnapAction.topRight.defaultHotkey
        self.bottomLeftHotkey = try c.decodeIfPresent(GlobalHotkey.Definition.self, forKey: .bottomLeftHotkey)
            ?? WindowSnapAction.bottomLeft.defaultHotkey
        self.bottomRightHotkey = try c.decodeIfPresent(GlobalHotkey.Definition.self, forKey: .bottomRightHotkey)
            ?? WindowSnapAction.bottomRight.defaultHotkey
    }

    public func hotkey(for action: WindowSnapAction) -> GlobalHotkey.Definition? {
        switch action {
        case .maximize: return maximizeHotkey
        case .leftHalf: return leftHalfHotkey
        case .rightHalf: return rightHalfHotkey
        case .topHalf: return topHalfHotkey
        case .bottomHalf: return bottomHalfHotkey
        case .topLeft: return topLeftHotkey
        case .topRight: return topRightHotkey
        case .bottomLeft: return bottomLeftHotkey
        case .bottomRight: return bottomRightHotkey
        }
    }

    public mutating func setHotkey(_ hotkey: GlobalHotkey.Definition?, for action: WindowSnapAction) {
        switch action {
        case .maximize: maximizeHotkey = hotkey
        case .leftHalf: leftHalfHotkey = hotkey
        case .rightHalf: rightHalfHotkey = hotkey
        case .topHalf: topHalfHotkey = hotkey
        case .bottomHalf: bottomHalfHotkey = hotkey
        case .topLeft: topLeftHotkey = hotkey
        case .topRight: topRightHotkey = hotkey
        case .bottomLeft: bottomLeftHotkey = hotkey
        case .bottomRight: bottomRightHotkey = hotkey
        }
    }
}

public enum WindowSnapSettingsKey {
    public static let settings = SettingsKey("modules.window-snap.settings")
}

public extension SettingsStore {
    func loadWindowSnapSettings() -> WindowSnapSettings {
        guard let data = self.data(WindowSnapSettingsKey.settings) else {
            return WindowSnapSettings()
        }
        return (try? JSONDecoder().decode(WindowSnapSettings.self, from: data))
            ?? WindowSnapSettings()
    }

    func saveWindowSnapSettings(_ settings: WindowSnapSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        self.setData(data, WindowSnapSettingsKey.settings)
    }
}
