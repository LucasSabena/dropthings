import Foundation

/// Typed errors for the Media Converter pipeline. Never use a raw string where
/// one of these cases fits — the category flows into diagnostics and the UI.
public enum MediaConverterError: LocalizedError, Equatable, Sendable {
    /// Probe could not read the source (corrupt, unsupported, unreadable).
    case probeFailed(reason: String)
    /// The requested conversion is not supported by the shipped backend for
    /// this source. Mirrors the stop-condition "do not expose a setting the
    /// chosen backend ignores": capability is checked before starting work.
    case unsupportedConversion(reason: String)
    /// Not enough free space on the destination volume for the planned output.
    case insufficientDiskSpace(requiredBytes: Int64, availableBytes: Int64)
    /// A previous step wrote a temp file but the re-probe of the output failed
    /// or disagreed with the expected format. The output is never finalized.
    case outputReprobeFailed(reason: String)
    /// The job was cancelled before producing a usable output.
    case cancelled
    /// The temporary output could not be moved to its final destination.
    case finalizationFailed(reason: String)
    /// The FFmpeg helper is present but no reproducibly built FFmpeg binary is
    /// packaged yet (Phase 0 pending). Audio/video conversions return this.
    case ffmpegBackendUnavailable
    /// The helper replied with an incompatible protocol version.
    case incompatibleProtocolVersion(received: Int)
    /// A generic failure from the helper, already localized to a sentence.
    case helperFailure(reason: String)

    public var errorDescription: String? {
        switch self {
        case .probeFailed(let reason):
            return "Could not read this file: \(reason)"
        case .unsupportedConversion(let reason):
            return "This conversion isn't supported here: \(reason)"
        case .insufficientDiskSpace(let required, let available):
            return "Not enough free space. About \(format(bytes: required)) is needed but only \(format(bytes: available)) is available."
        case .outputReprobeFailed(let reason):
            return "The converted file didn't verify and was discarded: \(reason)"
        case .cancelled:
            return "Cancelled. No output was kept."
        case .finalizationFailed(let reason):
            return "Couldn't save the converted file: \(reason)"
        case .ffmpegBackendUnavailable:
            return "Audio and video conversion need the bundled media engine, which isn't packaged in this build."
        case .incompatibleProtocolVersion(let received):
            return "The media helper is a different version (\(received)). Restart DropThings to update it."
        case .helperFailure(let reason):
            return reason
        }
    }

    /// Stable category string for diagnostics. Never includes user content.
    public var diagnosticCategory: String {
        switch self {
        case .probeFailed: return "probe-failed"
        case .unsupportedConversion: return "unsupported-conversion"
        case .insufficientDiskSpace: return "insufficient-disk-space"
        case .outputReprobeFailed: return "output-reprobe-failed"
        case .cancelled: return "cancelled"
        case .finalizationFailed: return "finalization-failed"
        case .ffmpegBackendUnavailable: return "ffmpeg-backend-unavailable"
        case .incompatibleProtocolVersion: return "incompatible-protocol-version"
        case .helperFailure: return "helper-failure"
        }
    }

    private func format(bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: max(0, bytes))
    }
}
