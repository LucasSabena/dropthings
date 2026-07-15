import Foundation

/// Stable identifier for a Simple-mode preset. Persisted in settings, so raw
/// values must never change once shipped.
public enum MediaPresetID: String, Hashable, Sendable, Codable, CaseIterable {
    case webImage = "preset.web-image"
    case transparentWeb = "preset.transparent-web"
    case email = "preset.email"
    case smallerVideo = "preset.smaller-video"
    case audioOnly = "preset.audio-only"
    case audioForTranscription = "preset.audio-for-transcription"
}

/// Simple-mode preset: outcome-oriented, hides implementation vocabulary.
/// Each preset declares which input kinds it applies to and a factory that
/// produces a typed `MediaConversionRequest` for a given source + destination.
public struct MediaPreset: Hashable, Sendable, Identifiable {
    public let id: MediaPresetID
    public let title: String
    public let summary: String
    public let iconName: String
    /// Input kinds this preset accepts. Drives the compatibility preview.
    public let applicableKinds: Set<MediaKind>

    public init(
        id: MediaPresetID,
        title: String,
        summary: String,
        iconName: String,
        applicableKinds: Set<MediaKind>
    ) {
        self.id = id
        self.title = title
        self.summary = summary
        self.iconName = iconName
        self.applicableKinds = applicableKinds
    }

    public var identifier: String { id.rawValue }
}

extension MediaPreset {
    /// The shipped Simple-mode presets (PRODUCT.md "Definition of done").
    public static let shipped: [MediaPreset] = [
        .init(id: .webImage, title: "Web Image",
              summary: "JPEG, max 1600 px, good quality.",
              iconName: "photo",
              applicableKinds: [.image]),
        .init(id: .transparentWeb, title: "Transparent Web",
              summary: "PNG with transparency, max 2048 px.",
              iconName: "photo.on.rectangle.angled",
              applicableKinds: [.image]),
        .init(id: .email, title: "Email",
              summary: "Small JPEG, max 1024 px.",
              iconName: "envelope",
              applicableKinds: [.image]),
        .init(id: .smallerVideo, title: "Smaller Video",
              summary: "H.264 MP4, smaller file.",
              iconName: "film",
              applicableKinds: [.video]),
        .init(id: .audioOnly, title: "Audio Only",
              summary: "M4A/AAC from any video or audio.",
              iconName: "waveform",
              applicableKinds: [.audio, .video]),
        .init(id: .audioForTranscription, title: "Audio for Transcription",
              summary: "16 kHz mono M4A, optimized for transcription.",
              iconName: "waveform.badge.magnifyingglass",
              applicableKinds: [.audio, .video])
    ]

    public static func find(_ id: MediaPresetID) -> MediaPreset? {
        shipped.first { $0.id == id }
    }
}

/// Resolves a preset + source into a concrete `MediaConversionRequest`. The
/// resolution is pure (no I/O); the pipeline then validates it against the
/// capability manifest and the probed source before starting.
public enum MediaPlanResolver {
    public enum ResolveError: Error, Equatable, Sendable {
        case presetNotFound
        case kindNotApplicable
        case unsupportedFormat
    }

    public static func resolve(
        presetID: MediaPresetID,
        source: URL,
        sourceKind: MediaKind,
        outputDirectory: URL,
        manifest: MediaCapabilityManifest,
        ffmpegAvailable: Bool
    ) throws -> MediaConversionRequest {
        guard let preset = MediaPreset.find(presetID) else { throw ResolveError.presetNotFound }
        guard preset.applicableKinds.contains(sourceKind) else { throw ResolveError.kindNotApplicable }

        switch presetID {
        case .webImage:
            guard manifest.canEncode(.jpeg, ffmpegAvailable: ffmpegAvailable) else { throw ResolveError.unsupportedFormat }
            return MediaConversionRequest(
                source: source, outputDirectory: outputDirectory,
                outputFormat: .jpeg, resize: .maxEdge(maxEdge: 1600),
                noUpscale: false, quality: 82, metadata: .stripNonessential, conflict: .suffix)

        case .transparentWeb:
            guard manifest.canEncode(.png, ffmpegAvailable: ffmpegAvailable) else { throw ResolveError.unsupportedFormat }
            return MediaConversionRequest(
                source: source, outputDirectory: outputDirectory,
                outputFormat: .png, resize: .maxEdge(maxEdge: 2048),
                noUpscale: false, quality: 100, metadata: .preserve, conflict: .suffix)

        case .email:
            guard manifest.canEncode(.jpeg, ffmpegAvailable: ffmpegAvailable) else { throw ResolveError.unsupportedFormat }
            return MediaConversionRequest(
                source: source, outputDirectory: outputDirectory,
                outputFormat: .jpeg, resize: .maxEdge(maxEdge: 1024),
                noUpscale: false, quality: 70, metadata: .removeLocationOnly, conflict: .suffix)

        case .smallerVideo:
            guard manifest.canEncode(.mp4H264, ffmpegAvailable: ffmpegAvailable) else { throw ResolveError.unsupportedFormat }
            return MediaConversionRequest(
                source: source, outputDirectory: outputDirectory,
                outputFormat: .mp4H264, resize: .none,
                noUpscale: false, quality: 60, metadata: .preserve, conflict: .suffix)

        case .audioOnly:
            guard manifest.canEncode(.m4aAAC, ffmpegAvailable: ffmpegAvailable) else { throw ResolveError.unsupportedFormat }
            return MediaConversionRequest(
                source: source, outputDirectory: outputDirectory,
                outputFormat: .m4aAAC, resize: .none,
                noUpscale: false, quality: 80, metadata: .preserve, conflict: .suffix)

        case .audioForTranscription:
            // 16 kHz mono is the transcription-friendly target. The FFmpeg
            // helper enforces the sample rate / channel downmix; the request
            // carries the format + a quality hint.
            guard manifest.canEncode(.m4aAAC, ffmpegAvailable: ffmpegAvailable) else { throw ResolveError.unsupportedFormat }
            return MediaConversionRequest(
                source: source, outputDirectory: outputDirectory,
                outputFormat: .m4aAAC, resize: .none,
                noUpscale: false, quality: 64,
                audioSampleRate: 16_000, audioChannels: 1,
                metadata: .stripNonessential, conflict: .suffix)
        }
    }
}
