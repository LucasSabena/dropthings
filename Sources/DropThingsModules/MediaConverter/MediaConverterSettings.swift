import Foundation
import DropThingsCore
import DropThingsMediaConverterKit

/// User-tunable Media Converter settings. Versioned so future schema changes
/// can migrate; the custom decoder uses `decodeIfPresent ?? default` so corrupt
/// or partial settings never crash startup (PRODUCT.md / stop-condition).
public struct MediaConverterSettings: Sendable, Equatable, Codable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    /// Which Simple preset is selected by default when opening the surface.
    public var defaultPreset: MediaPresetID
    /// Default output location. `nil` means "same folder as the source".
    public var outputDirectory: URL?
    /// Conflict policy applied to new jobs by default.
    public var conflict: ConflictPolicy
    /// Metadata policy applied to new jobs by default.
    public var metadata: MetadataPolicy
    /// Whether to start in Advanced mode.
    public var startInAdvancedMode: Bool
    /// Never produce outputs larger than their source.
    public var noUpscaleByDefault: Bool

    public init(
        schemaVersion: Int = MediaConverterSettings.currentSchemaVersion,
        defaultPreset: MediaPresetID = .webImage,
        outputDirectory: URL? = nil,
        conflict: ConflictPolicy = .suffix,
        metadata: MetadataPolicy = .stripNonessential,
        startInAdvancedMode: Bool = false,
        noUpscaleByDefault: Bool = false
    ) {
        self.schemaVersion = schemaVersion
        self.defaultPreset = defaultPreset
        self.outputDirectory = outputDirectory
        self.conflict = conflict
        self.metadata = metadata
        self.startInAdvancedMode = startInAdvancedMode
        self.noUpscaleByDefault = noUpscaleByDefault
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion, defaultPreset, outputDirectory, conflict, metadata, startInAdvancedMode, noUpscaleByDefault
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // Every field falls back to its default so a missing/unknown key never
        // throws. A corrupt blob is sanitized, never quarantined into a crash.
        self.schemaVersion = try c.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? Self.currentSchemaVersion
        if let raw = try c.decodeIfPresent(String.self, forKey: .defaultPreset),
           let preset = MediaPresetID(rawValue: raw) {
            self.defaultPreset = preset
        } else {
            self.defaultPreset = .webImage
        }
        self.outputDirectory = try c.decodeIfPresent(URL.self, forKey: .outputDirectory)
        if let raw = try c.decodeIfPresent(String.self, forKey: .conflict),
           let policy = ConflictPolicy(rawValue: raw) {
            self.conflict = policy
        } else {
            self.conflict = .suffix
        }
        if let raw = try c.decodeIfPresent(String.self, forKey: .metadata),
           let policy = MetadataPolicy(rawValue: raw) {
            self.metadata = policy
        } else {
            self.metadata = .stripNonessential
        }
        self.startInAdvancedMode = try c.decodeIfPresent(Bool.self, forKey: .startInAdvancedMode) ?? false
        self.noUpscaleByDefault = try c.decodeIfPresent(Bool.self, forKey: .noUpscaleByDefault) ?? false
    }

    /// Clamp/normalize before persistence.
    public func sanitized() -> MediaConverterSettings {
        var copy = self
        copy.schemaVersion = max(copy.schemaVersion, Self.currentSchemaVersion)
        return copy
    }
}

public enum MediaConverterSettingsKey {
    public static let settings = SettingsKey("modules.media-converter.settings")
}

public extension SettingsStore {
    func loadMediaConverterSettings() -> MediaConverterSettings {
        guard let data = self.data(MediaConverterSettingsKey.settings) else {
            return MediaConverterSettings()
        }
        return (try? JSONDecoder().decode(MediaConverterSettings.self, from: data))
            ?? MediaConverterSettings()
    }

    func saveMediaConverterSettings(_ settings: MediaConverterSettings) {
        guard let data = try? JSONEncoder().encode(settings.sanitized()) else { return }
        self.setData(data, MediaConverterSettingsKey.settings)
    }
}
