import Foundation
import Carbon.HIToolbox
import DropThingsCore
import DropThingsPlatform

public enum ClipboardItemType: String, Codable, Sendable, CaseIterable {
    case plainText
    case url
    case filePath
}

public struct ClipboardItem: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public let timestamp: Date
    public let type: ClipboardItemType
    public let content: String
    public let sourceBundleID: String?
    public var isPinned: Bool
    public var isFavorite: Bool

    public init(id: UUID = UUID(), timestamp: Date = Date(), type: ClipboardItemType, content: String, sourceBundleID: String? = nil, isPinned: Bool = false, isFavorite: Bool = false) {
        self.id = id
        self.timestamp = timestamp
        self.type = type
        self.content = content
        self.sourceBundleID = sourceBundleID
        self.isPinned = isPinned
        self.isFavorite = isFavorite
    }

    public var displayTitle: String {
        switch type {
        case .plainText: return content
        case .url: return content
        case .filePath: return (URL(fileURLWithPath: content).lastPathComponent)
        }
    }

    public var displaySubtitle: String {
        switch type {
        case .plainText:
            let count = content.count
            return "\(count) character\(count == 1 ? "" : "s")"
        case .url:
            return "URL"
        case .filePath:
            return URL(fileURLWithPath: content).path
        }
    }
}

public struct ClipboardHistorySettings: Sendable, Equatable, Codable {
    public var hotkeyEnabled: Bool
    public var hotkey: GlobalHotkey.Definition?
    public var maxHistory: Int
    public var pinnedItems: [ClipboardItem]
    public var excludedBundleIDs: [String]
    public var incognito: Bool

    public init(
        hotkeyEnabled: Bool = true,
        hotkey: GlobalHotkey.Definition? = GlobalHotkey.defaultClipboardHistoryHotkey,
        maxHistory: Int = 50,
        pinnedItems: [ClipboardItem] = [],
        excludedBundleIDs: [String] = [
            "com.1password.7-desktop",
            "com.agilebits.onepassword7",
            "com.bitwarden.desktop",
            "com.laserweb.LastPass",
            "com.apple.keychainaccess"
        ],
        incognito: Bool = false
    ) {
        self.hotkeyEnabled = hotkeyEnabled
        self.hotkey = hotkey
        self.maxHistory = maxHistory
        self.pinnedItems = pinnedItems
        self.excludedBundleIDs = excludedBundleIDs
        self.incognito = incognito
    }

    enum CodingKeys: String, CodingKey {
        case hotkeyEnabled, hotkey, maxHistory, pinnedItems, excludedBundleIDs, incognito
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.hotkeyEnabled = try c.decodeIfPresent(Bool.self, forKey: .hotkeyEnabled) ?? true
        self.hotkey = try c.decodeIfPresent(GlobalHotkey.Definition.self, forKey: .hotkey)
            ?? GlobalHotkey.defaultClipboardHistoryHotkey
        self.maxHistory = try c.decodeIfPresent(Int.self, forKey: .maxHistory) ?? 50
        self.pinnedItems = try c.decodeIfPresent([ClipboardItem].self, forKey: .pinnedItems) ?? []
        self.excludedBundleIDs = try c.decodeIfPresent([String].self, forKey: .excludedBundleIDs)
            ?? [
                "com.1password.7-desktop",
                "com.agilebits.onepassword7",
                "com.bitwarden.desktop",
                "com.laserweb.LastPass",
                "com.apple.keychainaccess"
            ]
        self.incognito = try c.decodeIfPresent(Bool.self, forKey: .incognito) ?? false
    }

    public static let maxHistoryMin = 10
    public static let maxHistoryMax = 500
    public static let maxHistoryDefault = 50
    public static let contentLengthMax = 10_240

    public static func sanitized(
        hotkeyEnabled: Bool,
        hotkey: GlobalHotkey.Definition?,
        maxHistory: Int,
        pinnedItems: [ClipboardItem],
        excludedBundleIDs: [String],
        incognito: Bool
    ) -> ClipboardHistorySettings {
        let clampedMax = min(max(maxHistory, maxHistoryMin), maxHistoryMax)
        let clampedPinned = Array(pinnedItems.suffix(clampedMax))
        return ClipboardHistorySettings(
            hotkeyEnabled: hotkeyEnabled,
            hotkey: hotkey,
            maxHistory: clampedMax,
            pinnedItems: clampedPinned,
            excludedBundleIDs: Array(Set(excludedBundleIDs)).sorted(),
            incognito: incognito
        )
    }
}

public enum ClipboardHistorySettingsKey {
    public static let settings = SettingsKey("modules.clipboard-history.settings")
    public static let pinnedData = SettingsKey("modules.clipboard-history.pinned-data")
}

public extension SettingsStore {
    func loadClipboardHistorySettings() -> ClipboardHistorySettings {
        guard let data = self.data(ClipboardHistorySettingsKey.settings) else {
            return ClipboardHistorySettings()
        }
        return (try? JSONDecoder().decode(ClipboardHistorySettings.self, from: data)) ?? ClipboardHistorySettings()
    }

    func saveClipboardHistorySettings(_ settings: ClipboardHistorySettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        self.setData(data, ClipboardHistorySettingsKey.settings)
    }
}

public extension GlobalHotkey {
    static var defaultClipboardHistoryHotkey: Definition? {
        Definition(keyCode: UInt32(kVK_ANSI_V), modifiers: UInt32(cmdKey | optionKey), id: 301)
    }
}
