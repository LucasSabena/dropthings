import Foundation
import Carbon.HIToolbox
import DropThingsCore
import DropThingsPlatform

public enum ScreenshotCaptureMode: String, CaseIterable, Codable, Sendable, Identifiable {
    case region, window, display, scrolling
    public var id: String { rawValue }
    public var title: String { rawValue.capitalized }
}

public enum ScreenshotOutputAction: String, CaseIterable, Codable, Sendable, Identifiable {
    case editor, copy, save, thumbnail
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .editor: return "Open editor"
        case .copy: return "Copy to clipboard"
        case .save: return "Save file"
        case .thumbnail: return "Show thumbnail"
        }
    }
}

public enum ScreenshotFileFormat: String, CaseIterable, Codable, Sendable, Identifiable {
    case png, jpeg
    public var id: String { rawValue }
    public var title: String { rawValue.uppercased() }
    public var fileExtension: String { self == .png ? "png" : "jpg" }
}

/// Versioned settings for Screenshot Studio. Each capture mode owns its own
/// shortcut, allowing users to invoke exactly the capture they need.
public struct ScreenshotStudioSettings: Sendable, Equatable, Codable {
    public static let currentVersion = 2
    public var version: Int
    public var shortcutsEnabled: Bool
    public var shortcuts: [ScreenshotCaptureMode: GlobalHotkey.Definition]
    /// Output behavior is owned by the capture mode. This lets a fast region
    /// capture copy immediately while window and display captures open in the
    /// editor without forcing one global compromise.
    public var outputs: [ScreenshotCaptureMode: ScreenshotOutputAction]
    public var showCapturePreview: Bool
    public var saveLocationPath: String?
    public var includeWindowShadow: Bool
    public var fileFormat: ScreenshotFileFormat
    public var jpegQuality: Double
    public var filenameTemplate: String
    public var thumbnailDuration: Double
    public var scrollingMaxFrames: Int
    public var scrollingStep: Int32

    public init(
        version: Int = currentVersion,
        shortcutsEnabled: Bool = true,
        shortcuts: [ScreenshotCaptureMode: GlobalHotkey.Definition] = Self.defaultShortcuts,
        defaultOutput: ScreenshotOutputAction? = nil,
        outputs: [ScreenshotCaptureMode: ScreenshotOutputAction] = Self.defaultOutputs,
        showCapturePreview: Bool = true,
        saveLocationPath: String? = nil,
        includeWindowShadow: Bool = true,
        fileFormat: ScreenshotFileFormat = .png,
        jpegQuality: Double = 0.92,
        filenameTemplate: String = "Screenshot {date}",
        thumbnailDuration: Double = 8,
        scrollingMaxFrames: Int = 30,
        scrollingStep: Int32 = -640
    ) {
        self.version = version
        self.shortcutsEnabled = shortcutsEnabled
        self.shortcuts = shortcuts
        self.outputs = defaultOutput.map { Self.outputs(using: $0) } ?? outputs
        self.showCapturePreview = showCapturePreview
        self.saveLocationPath = saveLocationPath
        self.includeWindowShadow = includeWindowShadow
        self.fileFormat = fileFormat; self.jpegQuality = jpegQuality; self.filenameTemplate = filenameTemplate; self.thumbnailDuration = thumbnailDuration; self.scrollingMaxFrames = scrollingMaxFrames; self.scrollingStep = scrollingStep
    }

    public static let defaultShortcuts: [ScreenshotCaptureMode: GlobalHotkey.Definition] = [
        .region: .init(keyCode: UInt32(kVK_ANSI_4), modifiers: UInt32(controlKey | optionKey), id: 410),
        .window: .init(keyCode: UInt32(kVK_ANSI_5), modifiers: UInt32(controlKey | optionKey), id: 411),
        .display: .init(keyCode: UInt32(kVK_ANSI_6), modifiers: UInt32(controlKey | optionKey), id: 412),
        .scrolling: .init(keyCode: UInt32(kVK_ANSI_7), modifiers: UInt32(controlKey | optionKey), id: 413)
    ]

    public static let defaultOutputs: [ScreenshotCaptureMode: ScreenshotOutputAction] = [
        .region: .copy,
        .window: .editor,
        .display: .editor,
        .scrolling: .editor
    ]

    /// Compatibility access for the prior single-output setting and migrations.
    public var defaultOutput: ScreenshotOutputAction {
        get { output(for: .region) }
        set { outputs = Self.outputs(using: newValue) }
    }

    public func output(for mode: ScreenshotCaptureMode) -> ScreenshotOutputAction {
        outputs[mode] ?? .editor
    }

    private static func outputs(using output: ScreenshotOutputAction) -> [ScreenshotCaptureMode: ScreenshotOutputAction] {
        Dictionary(uniqueKeysWithValues: ScreenshotCaptureMode.allCases.map { ($0, output) })
    }

    public static func sanitized(_ candidate: ScreenshotStudioSettings) -> ScreenshotStudioSettings {
        let path = candidate.saveLocationPath?.trimmingCharacters(in: .whitespacesAndNewlines)
        let retained = candidate.shortcuts.filter { $0.value.hasModifier }
        return ScreenshotStudioSettings(
            version: currentVersion,
            shortcutsEnabled: candidate.shortcutsEnabled,
            shortcuts: retained,
            outputs: Dictionary(uniqueKeysWithValues: ScreenshotCaptureMode.allCases.map { ($0, candidate.output(for: $0)) }),
            showCapturePreview: candidate.showCapturePreview,
            saveLocationPath: path?.isEmpty == false ? path : nil,
            includeWindowShadow: candidate.includeWindowShadow,
            fileFormat: candidate.fileFormat,
            jpegQuality: min(max(candidate.jpegQuality, 0.1), 1),
            filenameTemplate: candidate.filenameTemplate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Screenshot {date}" : candidate.filenameTemplate,
            thumbnailDuration: min(max(candidate.thumbnailDuration, 1), 30),
            scrollingMaxFrames: min(max(candidate.scrollingMaxFrames, 2), 100),
            scrollingStep: min(max(candidate.scrollingStep, -4_000), 4_000)
        )
    }

    /// Returns duplicate assignments before attempting Carbon registration.
    /// This makes collisions inside Screenshot Studio explicit and testable.
    public var duplicateShortcuts: Set<GlobalHotkey.Definition> {
        let all = Array(shortcuts.values)
        return Set(all.filter { value in all.filter { $0.keyCode == value.keyCode && $0.modifiers == value.modifiers }.count > 1 })
    }
}

extension ScreenshotStudioSettings {
    private enum CodingKeys: String, CodingKey { case version, shortcutsEnabled, shortcuts, defaultOutput, outputs, showCapturePreview, saveLocationPath, includeWindowShadow, fileFormat, jpegQuality, filenameTemplate, thumbnailDuration, scrollingMaxFrames, scrollingStep }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let decodedOutputs = try c.decodeIfPresent([ScreenshotCaptureMode: ScreenshotOutputAction].self, forKey: .outputs)
        let legacyOutput = try c.decodeIfPresent(ScreenshotOutputAction.self, forKey: .defaultOutput)
        self.init(
            version: try c.decodeIfPresent(Int.self, forKey: .version) ?? 1,
            shortcutsEnabled: try c.decodeIfPresent(Bool.self, forKey: .shortcutsEnabled) ?? true,
            shortcuts: try c.decodeIfPresent([ScreenshotCaptureMode: GlobalHotkey.Definition].self, forKey: .shortcuts) ?? Self.defaultShortcuts,
            // Existing v1 settings had one output. Preserve it for every mode
            // instead of silently changing a person's established workflow.
            defaultOutput: decodedOutputs == nil ? (legacyOutput ?? .editor) : nil,
            outputs: decodedOutputs ?? Self.defaultOutputs,
            showCapturePreview: try c.decodeIfPresent(Bool.self, forKey: .showCapturePreview) ?? true,
            saveLocationPath: try c.decodeIfPresent(String.self, forKey: .saveLocationPath),
            includeWindowShadow: try c.decodeIfPresent(Bool.self, forKey: .includeWindowShadow) ?? true,
            fileFormat: try c.decodeIfPresent(ScreenshotFileFormat.self, forKey: .fileFormat) ?? .png,
            jpegQuality: try c.decodeIfPresent(Double.self, forKey: .jpegQuality) ?? 0.92,
            filenameTemplate: try c.decodeIfPresent(String.self, forKey: .filenameTemplate) ?? "Screenshot {date}",
            thumbnailDuration: try c.decodeIfPresent(Double.self, forKey: .thumbnailDuration) ?? 8,
            scrollingMaxFrames: try c.decodeIfPresent(Int.self, forKey: .scrollingMaxFrames) ?? 30,
            scrollingStep: try c.decodeIfPresent(Int32.self, forKey: .scrollingStep) ?? -640
        )
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(version, forKey: .version)
        try c.encode(shortcutsEnabled, forKey: .shortcutsEnabled)
        try c.encode(shortcuts, forKey: .shortcuts)
        try c.encode(outputs, forKey: .outputs)
        try c.encode(showCapturePreview, forKey: .showCapturePreview)
        try c.encodeIfPresent(saveLocationPath, forKey: .saveLocationPath)
        try c.encode(includeWindowShadow, forKey: .includeWindowShadow)
        try c.encode(fileFormat, forKey: .fileFormat)
        try c.encode(jpegQuality, forKey: .jpegQuality)
        try c.encode(filenameTemplate, forKey: .filenameTemplate)
        try c.encode(thumbnailDuration, forKey: .thumbnailDuration)
        try c.encode(scrollingMaxFrames, forKey: .scrollingMaxFrames)
        try c.encode(scrollingStep, forKey: .scrollingStep)
    }
}

public enum ScreenshotStudioSettingsKey {
    public static let settings = SettingsKey("modules.screenshot-studio.settings")
}

public extension SettingsStore {
    func loadScreenshotStudioSettings() -> ScreenshotStudioSettings {
        if let data = self.data(ScreenshotStudioSettingsKey.settings),
           let decoded = try? JSONDecoder().decode(ScreenshotStudioSettings.self, from: data) {
            return ScreenshotStudioSettings.sanitized(decoded)
        }
        // One-way migration from the unshipped Screenshot Region baseline.
        if let data = self.data(SettingsKey("modules.screenshot-region.settings")),
           let legacy = try? JSONDecoder().decode(LegacyScreenshotRegionSettings.self, from: data) {
            var migrated = ScreenshotStudioSettings()
            migrated.shortcutsEnabled = legacy.hotkeyEnabled
            if let shortcut = legacy.hotkey { migrated.shortcuts[.region] = shortcut }
            migrated.saveLocationPath = legacy.saveLocationPath
            migrated.defaultOutput = legacy.copyPreviewToPasteboard ? .copy : .save
            saveScreenshotStudioSettings(migrated)
            return migrated
        }
        return ScreenshotStudioSettings()
    }

    func saveScreenshotStudioSettings(_ settings: ScreenshotStudioSettings) {
        guard let data = try? JSONEncoder().encode(ScreenshotStudioSettings.sanitized(settings)) else { return }
        self.setData(data, ScreenshotStudioSettingsKey.settings)
    }
}

private struct LegacyScreenshotRegionSettings: Decodable {
    let hotkeyEnabled: Bool
    let hotkey: GlobalHotkey.Definition?
    let saveLocationPath: String?
    let copyPreviewToPasteboard: Bool

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        hotkeyEnabled = try c.decodeIfPresent(Bool.self, forKey: .hotkeyEnabled) ?? true
        hotkey = try c.decodeIfPresent(GlobalHotkey.Definition.self, forKey: .hotkey)
        saveLocationPath = try c.decodeIfPresent(String.self, forKey: .saveLocationPath)
        copyPreviewToPasteboard = try c.decodeIfPresent(Bool.self, forKey: .copyPreviewToPasteboard) ?? true
    }
    private enum CodingKeys: String, CodingKey { case hotkeyEnabled, hotkey, saveLocationPath, copyPreviewToPasteboard }
}
