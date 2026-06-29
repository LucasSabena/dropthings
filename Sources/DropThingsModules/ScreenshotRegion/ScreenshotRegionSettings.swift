import Foundation
import Carbon.HIToolbox
import DropThingsCore
import DropThingsPlatform

/// User-tunable settings for the Screenshot Region module. Persisted as JSON
/// to a single Settings key.
public struct ScreenshotRegionSettings: Sendable, Equatable, Codable {
    public var hotkeyEnabled: Bool
    public var hotkey: GlobalHotkey.Definition?
    /// Absolute file-system path for saved captures. `nil` means the user's
    /// Desktop directory.
    public var saveLocationPath: String?
    public var copyPreviewToPasteboard: Bool

    public init(
        hotkeyEnabled: Bool = true,
        hotkey: GlobalHotkey.Definition? = ScreenshotRegionSettings.defaultHotkey,
        saveLocationPath: String? = nil,
        copyPreviewToPasteboard: Bool = true
    ) {
        self.hotkeyEnabled = hotkeyEnabled
        self.hotkey = hotkey
        self.saveLocationPath = saveLocationPath
        self.copyPreviewToPasteboard = copyPreviewToPasteboard
    }

    enum CodingKeys: String, CodingKey {
        case hotkeyEnabled, hotkey, saveLocationPath, copyPreviewToPasteboard
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.hotkeyEnabled = try c.decodeIfPresent(Bool.self, forKey: .hotkeyEnabled) ?? true
        self.hotkey = try c.decodeIfPresent(GlobalHotkey.Definition.self, forKey: .hotkey)
            ?? ScreenshotRegionSettings.defaultHotkey
        self.saveLocationPath = try c.decodeIfPresent(String.self, forKey: .saveLocationPath)
        self.copyPreviewToPasteboard = try c.decodeIfPresent(Bool.self, forKey: .copyPreviewToPasteboard) ?? true
    }

    public static let defaultHotkey = GlobalHotkey.Definition(
        keyCode: UInt32(kVK_ANSI_4),
        modifiers: UInt32(controlKey | optionKey),
        id: 4
    )

    public static func sanitized(
        hotkeyEnabled: Bool,
        hotkey: GlobalHotkey.Definition?,
        saveLocationPath: String?,
        copyPreviewToPasteboard: Bool
    ) -> ScreenshotRegionSettings {
        let trimmed = saveLocationPath?.trimmingCharacters(in: .whitespacesAndNewlines)
        let validPath = (trimmed?.isEmpty == false) ? trimmed : nil
        return ScreenshotRegionSettings(
            hotkeyEnabled: hotkeyEnabled,
            hotkey: hotkey,
            saveLocationPath: validPath,
            copyPreviewToPasteboard: copyPreviewToPasteboard
        )
    }
}

public enum ScreenshotRegionSettingsKey {
    public static let settings = SettingsKey("modules.screenshot-region.settings")
}

public extension SettingsStore {
    func loadScreenshotRegionSettings() -> ScreenshotRegionSettings {
        guard let data = self.data(ScreenshotRegionSettingsKey.settings) else {
            return ScreenshotRegionSettings()
        }
        return (try? JSONDecoder().decode(ScreenshotRegionSettings.self, from: data))
            ?? ScreenshotRegionSettings()
    }

    func saveScreenshotRegionSettings(_ settings: ScreenshotRegionSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        self.setData(data, ScreenshotRegionSettingsKey.settings)
    }
}
