import Foundation

/// Which backend can handle a given conversion. The manifest is the single
/// source of truth for "is this supported right now"; the UI hides or disables
/// anything the active manifest rejects (stop-condition: "do not expose a
/// setting the chosen backend ignores").
public enum ConversionBackend: String, Hashable, Sendable {
    /// Apple system frameworks (ImageIO/CoreImage/AVFoundation). Always
    /// available on the supported OS; used for image conversions today.
    case native
    /// The reproducibly built FFmpeg helper. Only `available` when the pinned
    /// binary is packaged; until Phase 0 lands it reports unavailable.
    case ffmpeg
}

/// Static, shipped declaration of which format families each backend covers.
/// Runtime availability (is the FFmpeg binary actually present?) is layered on
/// top by `resolved(ffmpegAvailable:)`.
public struct MediaCapabilityManifest: Hashable, Sendable {
    public let nativeImageOutputs: Set<MediaFormatID>
    public let ffmpegAudioOutputs: Set<MediaFormatID>
    public let ffmpegVideoOutputs: Set<MediaFormatID>

    public init(
        nativeImageOutputs: Set<MediaFormatID>,
        ffmpegAudioOutputs: Set<MediaFormatID>,
        ffmpegVideoOutputs: Set<MediaFormatID>
    ) {
        self.nativeImageOutputs = nativeImageOutputs
        self.ffmpegAudioOutputs = ffmpegAudioOutputs
        self.ffmpegVideoOutputs = ffmpegVideoOutputs
    }

    /// The manifest shipped with this build. Native image outputs are always
    /// available; FFmpeg-backed outputs depend on whether the binary is present.
    ///
    /// The pinned FFmpeg (LGPL-2.1+, no external libs) provides: AAC (native),
    /// FLAC, Opus, PCM/WAV, and H.264 via VideoToolbox. It does NOT include
    /// MP3 (needs libmp3lame) or WebM/VP9 (needs libvpx). Those IDs stay defined
    /// for schema stability but the manifest hides them, so the UI never offers
    /// a conversion the backend cannot perform.
    public static let shipped = MediaCapabilityManifest(
        nativeImageOutputs: [.png, .jpeg, .heic, .webp, .tiff],
        ffmpegAudioOutputs: [.m4aAAC, .wav, .flac, .opus],
        ffmpegVideoOutputs: [.mp4H264, .movH264, .mkvH264]
    )

    /// Resolve which backend, if any, can produce `format` right now.
    public func backend(
        for format: MediaFormatID,
        ffmpegAvailable: Bool
    ) -> ConversionBackend? {
        if nativeImageOutputs.contains(format) {
            return .native
        }
        if ffmpegAvailable {
            if ffmpegAudioOutputs.contains(format) || ffmpegVideoOutputs.contains(format) {
                return .ffmpeg
            }
        }
        return nil
    }

    /// `true` when `format` can be encoded with the current backend state.
    public func canEncode(_ format: MediaFormatID, ffmpegAvailable: Bool) -> Bool {
        backend(for: format, ffmpegAvailable: ffmpegAvailable) != nil
    }

    /// Outputs the user is allowed to pick for `kind`, given backend state.
    public func availableOutputs(for kind: MediaKind, ffmpegAvailable: Bool) -> [MediaFormatID] {
        switch kind {
        case .image:
            return Array(nativeImageOutputs).sorted { $0.rawValue < $1.rawValue }
        case .audio:
            return ffmpegAvailable ? Array(ffmpegAudioOutputs).sorted { $0.rawValue < $1.rawValue } : []
        case .video:
            return ffmpegAvailable ? Array(ffmpegVideoOutputs).sorted { $0.rawValue < $1.rawValue } : []
        }
    }
}
