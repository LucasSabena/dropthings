import Foundation

/// How an image should be resized during conversion. Every case is typed; none
/// accepts a raw shell argument (stop-condition: "no raw shell arguments").
public enum ResizePolicy: Hashable, Sendable, Codable {
    /// Leave dimensions untouched.
    case none
    /// Scale to fit within `maxEdge` preserving aspect ratio.
    case maxEdge(maxEdge: Int)
    /// Scale by a percentage (0...1000). 100 means original size.
    case percentage(percent: Int)
    /// Exact target dimensions; behavior on aspect mismatch depends on `mode`.
    case exact(width: Int, height: Int, mode: FitMode)

    public enum FitMode: String, Hashable, Sendable, Codable {
        /// Scale to fully fit inside the box; may letterbox (keeps aspect).
        case fit
        /// Scale to cover the box and crop the overflow (keeps aspect).
        case fill
        /// Ignore aspect ratio and stretch to the exact box.
        case stretch
    }
}

extension ResizePolicy {
    /// When `true`, never produce an output larger than the source.
    public var canUpscale: Bool {
        switch self {
        case .none: return true
        case .maxEdge, .percentage, .exact: return true
        }
    }
}

/// What to do with metadata (EXIF/IPTC/XMP) on output.
public enum MetadataPolicy: String, Hashable, Sendable, Codable, CaseIterable {
    /// Keep all metadata.
    case preserve
    /// Keep everything except GPS/location.
    case removeLocationOnly
    /// Strip all non-essential metadata (color profile may still be kept for
    /// correctness on image outputs).
    case stripNonessential
}

/// What to do when the destination output URL already exists.
public enum ConflictPolicy: String, Hashable, Sendable, Codable, CaseIterable {
    /// Skip the file and leave the existing output untouched.
    case skip
    /// Append " 2", " 3", ... until the name is free.
    case suffix
    /// Fail and ask the user to choose a different destination. Never a silent
    /// overwrite.
    case fail
}

/// A single typed conversion job. Built from a preset or the Advanced mode; the
/// pipeline validates it against `MediaCapabilityManifest` before starting.
public struct MediaConversionRequest: Hashable, Sendable, Codable {
    public let source: URL
    public let outputDirectory: URL
    public let outputFormat: MediaFormatID
    public let resize: ResizePolicy
    public let noUpscale: Bool
    /// 0...100 for lossy encoders; ignored by lossless formats.
    public let quality: Int
    /// Optional audio normalization. `nil` preserves the source value.
    public let audioSampleRate: Int?
    public let audioChannels: Int?
    public let metadata: MetadataPolicy
    public let conflict: ConflictPolicy

    public init(
        source: URL,
        outputDirectory: URL,
        outputFormat: MediaFormatID,
        resize: ResizePolicy = .none,
        noUpscale: Bool = false,
        quality: Int = 80,
        audioSampleRate: Int? = nil,
        audioChannels: Int? = nil,
        metadata: MetadataPolicy = .preserve,
        conflict: ConflictPolicy = .suffix
    ) {
        self.source = source
        self.outputDirectory = outputDirectory
        self.outputFormat = outputFormat
        self.resize = resize
        self.noUpscale = noUpscale
        self.quality = max(1, min(100, quality))
        self.audioSampleRate = audioSampleRate.map { max(8_000, min(192_000, $0)) }
        self.audioChannels = audioChannels.map { max(1, min(8, $0)) }
        self.metadata = metadata
        self.conflict = conflict
    }

    public var kind: MediaKind? { outputFormat.kind }
}
