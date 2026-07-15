import Foundation
import Carbon.HIToolbox
import DropThingsCore
import DropThingsPlatform

/// User-tunable Smart Clipboard settings. Versioned and sanitized so corrupt
/// blobs never crash module startup. Persisted as a single JSON blob keyed
/// under `modules.smart-clipboard.settings`.
public struct SmartClipboardSettings: Sendable, Equatable, Codable {
    public var schemaVersion: Int
    public var hotkeyEnabled: Bool
    public var hotkey: GlobalHotkey.Definition?
    /// Default color format used when the user copies a color result.
    public var colorFormat: SmartClipboardColorFormat
    /// Hide the preview while the panel is focused so sensitive content does
    /// not stay visible. The user toggles this from the panel.
    public var hideSensitivePreview: Bool
    /// Restore the previous clipboard snapshot for a bounded period after a
    /// Smart Clipboard copy, so the user can undo an accidental transform.
    public var undoCopyWindowSeconds: Int
    /// Optional Accessibility-based paste-back into the prior app. Off by
    /// default; enabling it requests Accessibility.
    public var pasteBackEnabled: Bool

    public init(
        schemaVersion: Int = SmartClipboardSettings.currentSchemaVersion,
        hotkeyEnabled: Bool = true,
        hotkey: GlobalHotkey.Definition? = GlobalHotkey.defaultSmartClipboardHotkey,
        colorFormat: SmartClipboardColorFormat = .hex,
        hideSensitivePreview: Bool = false,
        undoCopyWindowSeconds: Int = SmartClipboardSettings.defaultUndoWindowSeconds,
        pasteBackEnabled: Bool = false
    ) {
        self.schemaVersion = schemaVersion
        self.hotkeyEnabled = hotkeyEnabled
        self.hotkey = hotkey
        self.colorFormat = colorFormat
        self.hideSensitivePreview = hideSensitivePreview
        self.undoCopyWindowSeconds = undoCopyWindowSeconds
        self.pasteBackEnabled = pasteBackEnabled
    }

    public static let currentSchemaVersion = 1
    public static let defaultUndoWindowSeconds = 30
    public static let minUndoWindowSeconds = 0
    public static let maxUndoWindowSeconds = 300

    enum CodingKeys: String, CodingKey {
        case schemaVersion, hotkeyEnabled, hotkey, colorFormat
        case hideSensitivePreview, undoCopyWindowSeconds, pasteBackEnabled
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.schemaVersion = try c.decodeIfPresent(Int.self, forKey: .schemaVersion)
            ?? SmartClipboardSettings.currentSchemaVersion
        self.hotkeyEnabled = try c.decodeIfPresent(Bool.self, forKey: .hotkeyEnabled) ?? true
        self.hotkey = try c.decodeIfPresent(GlobalHotkey.Definition.self, forKey: .hotkey)
            ?? GlobalHotkey.defaultSmartClipboardHotkey
        self.colorFormat = try c.decodeIfPresent(SmartClipboardColorFormat.self, forKey: .colorFormat) ?? .hex
        self.hideSensitivePreview = try c.decodeIfPresent(Bool.self, forKey: .hideSensitivePreview) ?? false
        self.undoCopyWindowSeconds = try c.decodeIfPresent(Int.self, forKey: .undoCopyWindowSeconds)
            ?? SmartClipboardSettings.defaultUndoWindowSeconds
        self.pasteBackEnabled = try c.decodeIfPresent(Bool.self, forKey: .pasteBackEnabled) ?? false
    }

    /// Clamp and normalize every field so corrupt blobs cannot crash startup.
    public static func sanitized(
        hotkeyEnabled: Bool,
        hotkey: GlobalHotkey.Definition?,
        colorFormat: SmartClipboardColorFormat,
        hideSensitivePreview: Bool,
        undoCopyWindowSeconds: Int,
        pasteBackEnabled: Bool
    ) -> SmartClipboardSettings {
        let clampedUndo = min(
            max(undoCopyWindowSeconds, minUndoWindowSeconds),
            maxUndoWindowSeconds
        )
        return SmartClipboardSettings(
            schemaVersion: currentSchemaVersion,
            hotkeyEnabled: hotkeyEnabled,
            hotkey: hotkey,
            colorFormat: colorFormat,
            hideSensitivePreview: hideSensitivePreview,
            undoCopyWindowSeconds: clampedUndo,
            pasteBackEnabled: pasteBackEnabled
        )
    }
}

public enum SmartClipboardSettingsKey {
    public static let settings = SettingsKey("modules.smart-clipboard.settings")
}

public extension SettingsStore {
    func loadSmartClipboardSettings() -> SmartClipboardSettings {
        guard let data = self.data(SmartClipboardSettingsKey.settings) else {
            return SmartClipboardSettings()
        }
        return (try? JSONDecoder().decode(SmartClipboardSettings.self, from: data))
            ?? SmartClipboardSettings()
    }

    func saveSmartClipboardSettings(_ settings: SmartClipboardSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        self.setData(data, SmartClipboardSettingsKey.settings)
    }
}

public extension GlobalHotkey {
    static var defaultSmartClipboardHotkey: Definition? {
        Definition(keyCode: UInt32(kVK_ANSI_V), modifiers: UInt32(cmdKey | shiftKey), id: 401)
    }
}