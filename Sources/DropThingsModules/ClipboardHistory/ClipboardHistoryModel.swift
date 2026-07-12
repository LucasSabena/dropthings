import Foundation
import AppKit
import Carbon.HIToolbox
import DropThingsCore
import DropThingsPlatform

/// Kinds of content the clipboard history can capture. File-backed entries and
/// colors can persist when pinned; raw image bytes remain session-only.
public enum ClipboardItemType: String, Codable, Sendable, CaseIterable {
    case plainText
    case url
    case filePath
    case folder
    case image
    case video
    case audio
    case color
}

public struct ClipboardItem: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public let timestamp: Date
    public let type: ClipboardItemType
    public let content: String
    /// TIFF image data for `.image` items. Held in memory only — it is
    /// deliberately excluded from `Codable` so copied images are never written
    /// to disk or settings. Images do not survive a restart unless re-copied.
    public let imageData: Data?
    public let sourceBundleID: String?
    public var isPinned: Bool
    public var isFavorite: Bool

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        type: ClipboardItemType,
        content: String,
        imageData: Data? = nil,
        sourceBundleID: String? = nil,
        isPinned: Bool = false,
        isFavorite: Bool = false
    ) {
        self.id = id
        self.timestamp = timestamp
        self.type = type
        self.content = content
        self.imageData = imageData
        self.sourceBundleID = sourceBundleID
        self.isPinned = isPinned
        self.isFavorite = isFavorite
    }

    // MARK: Codable (imageData intentionally excluded)

    enum CodingKeys: String, CodingKey {
        case id, timestamp, type, content, sourceBundleID, isPinned, isFavorite
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(UUID.self, forKey: .id)
        self.timestamp = try c.decode(Date.self, forKey: .timestamp)
        self.type = try c.decode(ClipboardItemType.self, forKey: .type)
        self.content = try c.decode(String.self, forKey: .content)
        self.sourceBundleID = try c.decodeIfPresent(String.self, forKey: .sourceBundleID)
        self.isPinned = try c.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
        self.isFavorite = try c.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
        self.imageData = nil
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(timestamp, forKey: .timestamp)
        try c.encode(type, forKey: .type)
        try c.encode(content, forKey: .content)
        try c.encodeIfPresent(sourceBundleID, forKey: .sourceBundleID)
        try c.encode(isPinned, forKey: .isPinned)
        try c.encode(isFavorite, forKey: .isFavorite)
    }

    // MARK: Persistence

    /// `true` for types that survive a restart when pinned. Raw image bytes are
    /// memory-only by design; file-backed images are restored through paths.
    public static func isPersistable(type: ClipboardItemType) -> Bool {
        switch type {
        case .plainText, .url, .filePath, .folder, .video, .audio, .color: return true
        case .image: return false
        }
    }

    public static func isPersistable(_ item: ClipboardItem) -> Bool {
        if item.type == .image {
            return item.imageData == nil && item.fileURL != nil
        }
        return isPersistable(type: item.type)
    }

    // MARK: Display helpers

    public var displayTitle: String {
        switch type {
        case .plainText: return content
        case .url: return content
        case .filePath: return URL(fileURLWithPath: content).lastPathComponent
        case .folder: return URL(fileURLWithPath: content).lastPathComponent
        case .image:
            return fileURL?.lastPathComponent ?? "Image"
        case .video, .audio:
            return URL(fileURLWithPath: content).lastPathComponent
        case .color: return content
        }
    }

    public var displaySubtitle: String {
        switch type {
        case .plainText:
            let count = content.count
            return "\(count) character\(count == 1 ? "" : "s")"
        case .url:
            if let host = URL(string: content)?.host { return host }
            return "URL"
        case .filePath:
            return URL(fileURLWithPath: content).path
        case .folder:
            return "Folder · \(URL(fileURLWithPath: content).path)"
        case .image:
            if let size = imagePixelSize() {
                return "\(size.width) × \(size.height) px"
            }
            return "Image"
        case .video:
            return fileInfo?.byteCount.map(Self.byteCountString) ?? "Video"
        case .audio:
            return fileInfo?.byteCount.map(Self.byteCountString) ?? "Audio"
        case .color:
            return "Color"
        }
    }

    /// Decoded image for previews/thumbnails. Cheap to call; the decode is
    /// fast for the small images we store.
    public var nsImage: NSImage? {
        if let data = imageData {
            return NSImage(data: data)
        }
        guard type == .image, let fileURL else { return nil }
        return NSImage(contentsOf: fileURL)
    }

    /// Parsed color for `.color` items; nil for everything else. The hex
    /// string is parsed via the Platform color adapter.
    public var nsColor: NSColor? {
        guard type == .color else { return nil }
        return ClipboardColorHex.color(from: content)
    }

    public func imagePixelSize() -> NSSize? {
        if let image = nsImage {
            // Use the best bitmap rep available; falls back to the image's
            // pixel size when no rep reports explicit dimensions.
            let reps = image.representations.compactMap { $0 as? NSBitmapImageRep }
            if let rep = reps.first(where: { $0.pixelsWide > 0 }) {
                return NSSize(width: rep.pixelsWide, height: rep.pixelsHigh)
            }
        }
        return nil
    }

    /// Local URL for file-backed entries. Raw clipboard images have no URL;
    /// copied image files do, which lets Quick Look and drag-out preserve the
    /// original file rather than flattening it to TIFF.
    public var fileURL: URL? {
        switch type {
        case .filePath, .folder, .video, .audio:
            return URL(fileURLWithPath: content)
        case .image where imageData == nil && content.hasPrefix("/"):
            return URL(fileURLWithPath: content)
        default:
            return nil
        }
    }

    public var fileInfo: FileContentInfo? {
        fileURL.map { FileContentInfo.inspect($0) }
    }

    public var systemImageName: String {
        switch type {
        case .plainText: return "text.quote"
        case .url: return "link"
        case .filePath: return fileInfo?.kind.systemImageName ?? "doc"
        case .folder: return "folder.fill"
        case .image: return "photo"
        case .video: return "film"
        case .audio: return "waveform"
        case .color: return "paintpalette"
        }
    }

    private static func byteCountString(_ count: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: count, countStyle: .file)
    }
}

public struct ClipboardHistorySettings: Sendable, Equatable, Codable {
    public var hotkeyEnabled: Bool
    public var hotkey: GlobalHotkey.Definition?
    public var maxHistory: Int
    public var retentionDays: Int
    public var maxStorageMB: Int
    public var pinnedItems: [ClipboardItem]
    public var excludedBundleIDs: [String]
    public var incognito: Bool
    /// When true, pressing Enter on an item pastes it at the cursor (requires
    /// Accessibility). When false, Enter copies to the pasteboard only.
    public var pasteOnEnter: Bool

    public init(
        hotkeyEnabled: Bool = true,
        hotkey: GlobalHotkey.Definition? = GlobalHotkey.defaultClipboardHistoryHotkey,
        maxHistory: Int = 200,
        retentionDays: Int = 30,
        maxStorageMB: Int = 250,
        pinnedItems: [ClipboardItem] = [],
        excludedBundleIDs: [String] = [
            "com.1password.7-desktop",
            "com.agilebits.onepassword7",
            "com.bitwarden.desktop",
            "com.laserweb.LastPass",
            "com.apple.keychainaccess"
        ],
        incognito: Bool = false,
        pasteOnEnter: Bool = false
    ) {
        self.hotkeyEnabled = hotkeyEnabled
        self.hotkey = hotkey
        self.maxHistory = maxHistory
        self.retentionDays = retentionDays
        self.maxStorageMB = maxStorageMB
        self.pinnedItems = pinnedItems
        self.excludedBundleIDs = excludedBundleIDs
        self.incognito = incognito
        self.pasteOnEnter = pasteOnEnter
    }

    enum CodingKeys: String, CodingKey {
        case hotkeyEnabled, hotkey, maxHistory, retentionDays, maxStorageMB
        case pinnedItems, excludedBundleIDs, incognito, pasteOnEnter
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.hotkeyEnabled = try c.decodeIfPresent(Bool.self, forKey: .hotkeyEnabled) ?? true
        self.hotkey = try c.decodeIfPresent(GlobalHotkey.Definition.self, forKey: .hotkey)
            ?? GlobalHotkey.defaultClipboardHistoryHotkey
        self.maxHistory = try c.decodeIfPresent(Int.self, forKey: .maxHistory) ?? 200
        self.retentionDays = try c.decodeIfPresent(Int.self, forKey: .retentionDays) ?? 30
        self.maxStorageMB = try c.decodeIfPresent(Int.self, forKey: .maxStorageMB) ?? 250
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
        self.pasteOnEnter = try c.decodeIfPresent(Bool.self, forKey: .pasteOnEnter) ?? false
    }

    public static let maxHistoryMin = 10
    public static let maxHistoryMax = 500
    public static let maxHistoryDefault = 200
    public static let retentionDaysMin = 1
    public static let retentionDaysMax = 365
    public static let retentionDaysDefault = 30
    public static let maxStorageMBMin = 25
    public static let maxStorageMBMax = 2_048
    public static let maxStorageMBDefault = 250
    public static let contentLengthMax = 10_240

    public static func sanitized(
        hotkeyEnabled: Bool,
        hotkey: GlobalHotkey.Definition?,
        maxHistory: Int,
        retentionDays: Int,
        maxStorageMB: Int,
        pinnedItems: [ClipboardItem],
        excludedBundleIDs: [String],
        incognito: Bool,
        pasteOnEnter: Bool
    ) -> ClipboardHistorySettings {
        let clampedMax = min(max(maxHistory, maxHistoryMin), maxHistoryMax)
        let clampedRetention = min(max(retentionDays, retentionDaysMin), retentionDaysMax)
        let clampedStorage = min(max(maxStorageMB, maxStorageMBMin), maxStorageMBMax)
        // Only persist types that can survive a restart.
        let clampedPinned = Array(pinnedItems.suffix(clampedMax))
            .filter(ClipboardItem.isPersistable)
        return ClipboardHistorySettings(
            hotkeyEnabled: hotkeyEnabled,
            hotkey: hotkey,
            maxHistory: clampedMax,
            retentionDays: clampedRetention,
            maxStorageMB: clampedStorage,
            pinnedItems: clampedPinned,
            excludedBundleIDs: Array(Set(excludedBundleIDs)).sorted(),
            incognito: incognito,
            pasteOnEnter: pasteOnEnter
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
