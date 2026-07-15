import Foundation
import UniformTypeIdentifiers

/// High-level media family. Drives which backend (native vs. FFmpeg) can probe
/// and encode a given request.
public enum MediaKind: String, Codable, Hashable, Sendable, CaseIterable {
    case image
    case audio
    case video
}

/// Stable identifier for an output format. Persisted in presets and settings,
/// so the raw values must never change once shipped (renames require a preset
/// migration).
public struct MediaFormatID: Hashable, Sendable, RawRepresentable, Codable, CustomStringConvertible {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public var description: String { rawValue }
}

extension MediaFormatID {
    // Image formats — native backend (ImageIO) unless noted.
    public static let png = MediaFormatID(rawValue: "image.png")
    public static let jpeg = MediaFormatID(rawValue: "image.jpeg")
    public static let heic = MediaFormatID(rawValue: "image.heic")
    public static let webp = MediaFormatID(rawValue: "image.webp")
    public static let tiff = MediaFormatID(rawValue: "image.tiff")

    // Audio formats — FFmpeg backend (M4A/AAC is the compatibility default).
    public static let m4aAAC = MediaFormatID(rawValue: "audio.m4a-aac")
    public static let wav = MediaFormatID(rawValue: "audio.wav-pcm")
    public static let flac = MediaFormatID(rawValue: "audio.flac")
    public static let opus = MediaFormatID(rawValue: "audio.opus")
    public static let mp3 = MediaFormatID(rawValue: "audio.mp3")

    // Video formats — FFmpeg backend. H.264/AAC MP4 is the default preset.
    public static let mp4H264 = MediaFormatID(rawValue: "video.mp4-h264")
    public static let movH264 = MediaFormatID(rawValue: "video.mov-h264")
    public static let mkvH264 = MediaFormatID(rawValue: "video.mkv-h264")
    public static let webmVP9 = MediaFormatID(rawValue: "video.webm-vp9")
}

extension MediaFormatID {
    /// Family of this format. Returns `nil` for unknown identifiers rather than
    /// guessing — callers must decide explicitly how to handle an unknown value.
    public var kind: MediaKind? {
        switch rawValue {
        case let s where s.hasPrefix("image."): return .image
        case let s where s.hasPrefix("audio."): return .audio
        case let s where s.hasPrefix("video."): return .video
        default: return nil
        }
    }

    /// Preferred file extension (without leading dot) for outputs of this
    /// format. Used by `OutputNaming` to build safe output URLs.
    public var preferredExtension: String? {
        switch self {
        case .png: return "png"
        case .jpeg: return "jpg"
        case .heic: return "heic"
        case .webp: return "webp"
        case .tiff: return "tiff"
        case .m4aAAC: return "m4a"
        case .wav: return "wav"
        case .flac: return "flac"
        case .opus: return "opus"
        case .mp3: return "mp3"
        case .mp4H264: return "mp4"
        case .movH264: return "mov"
        case .mkvH264: return "mkv"
        case .webmVP9: return "webm"
        default: return nil
        }
    }

    /// Matching `UTType` for probing/classification. `nil` when the identifier
    /// is not recognized (the caller must not infer capability from extension
    /// alone — see `MediaCapabilityManifest`).
    public var utType: UTType? {
        switch self {
        case .png: return .png
        case .jpeg: return .jpeg
        case .heic: return .heic
        case .webp: return UTType("org.webmproject.webp") ?? UTType.png
        case .tiff: return .tiff
        case .m4aAAC: return UTType("public.mpeg-4-audio") ?? UTType.mpeg4Audio
        case .wav: return UTType("com.microsoft.waveform-audio") ?? UTType.audio
        case .flac: return UTType("org.xiph.flac") ?? UTType.audio
        case .opus: return UTType("org.xiph.opus") ?? UTType.audio
        case .mp3: return .mp3
        case .mp4H264: return .mpeg4Movie
        case .movH264: return .quickTimeMovie
        case .mkvH264: return UTType("org.matroska.mkv") ?? UTType.movie
        case .webmVP9: return UTType("org.webmproject.webm") ?? UTType.movie
        default: return nil
        }
    }
}
