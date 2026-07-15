import Foundation

/// Builds the FFmpeg argument array for a typed `MediaConversionRequest`.
///
/// The output is always a `[String]` passed straight to `Process`/the helper's
/// argv — never a shell string. This is the central defense against shell
/// injection (QUALITY.md: "FFmpeg arguments are arrays; test spaces, quotes,
/// newlines and leading dashes"). File paths are passed as their own argv
/// entries, so a path containing `-flag`, spaces, quotes, or newlines cannot be
/// interpreted as an option.
public enum FFmpegArgumentBuilder {
    /// Arguments for an audio conversion. Returns `nil` when the request isn't
    /// an FFmpeg-backed audio format (the caller should not have asked).
    public static func audioArguments(for request: MediaConversionRequest) -> [String]? {
        guard request.outputFormat.kind == .audio else { return nil }
        var args: [String] = ["-hide_banner", "-loglevel", "error", "-nostats", "-y", "-nostdin"]

        // Input always comes last among -i options and as its own argv token.
        args.append(contentsOf: ["-i", request.source.path])

        switch request.outputFormat {
        case .m4aAAC:
            args.append(contentsOf: ["-c:a", "aac", "-b:a", bitrate(for: request), "-movflags", "+faststart"])
        case .wav:
            args.append(contentsOf: ["-c:a", "pcm_s16le"])
        case .flac:
            args.append(contentsOf: ["-c:a", "flac"])
        case .opus:
            // FFmpeg 8.x ships a built-in Opus encoder ("opus"), so no external
            // libopus dependency is needed. Output container is Ogg/Opus.
            args.append(contentsOf: ["-c:a", "opus", "-strict", "experimental", "-b:a", bitrate(for: request)])
        default:
            return nil
        }

        if let sampleRate = request.audioSampleRate {
            args.append(contentsOf: ["-ar", String(sampleRate)])
        }
        if let channels = request.audioChannels {
            args.append(contentsOf: ["-ac", String(channels)])
        }

        switch request.metadata {
        case .preserve:
            break
        case .removeLocationOnly:
            args.append(contentsOf: ["-map_metadata", "0"])
            appendLocationRemoval(to: &args)
        case .stripNonessential:
            args.append(contentsOf: ["-map_metadata", "-1"])
        }

        // The output path is its own argv token; never interpolated into a
        // shell string. The actual URL is resolved upstream by the pipeline.
        // We return placeholder-free args; the caller appends the output path.
        return args
    }

    /// Arguments for a video conversion. H.264/AAC MP4 is the default
    /// compatibility preset. Returns `nil` for non-video requests.
    public static func videoArguments(for request: MediaConversionRequest) -> [String]? {
        guard request.outputFormat.kind == .video else { return nil }
        var args: [String] = ["-hide_banner", "-loglevel", "error", "-nostats", "-y", "-nostdin", "-i", request.source.path]

        switch request.outputFormat {
        case .mp4H264, .movH264:
            // h264_videotoolbox is the LGPL hardware H.264 encoder (no libx264,
            // which would be GPL). Quality is controlled via -q:v (1=best, 100
            // =worst) for VideoToolbox, mapped from the request quality 0..100.
            args.append(contentsOf: ["-c:v", "h264_videotoolbox", "-q:v", vtVideoQuality(for: request), "-pix_fmt", "yuv420p"])
            args.append(contentsOf: ["-c:a", "aac", "-b:a", "128k", "-movflags", "+faststart"])
        case .mkvH264:
            args.append(contentsOf: ["-c:v", "h264_videotoolbox", "-q:v", vtVideoQuality(for: request), "-pix_fmt", "yuv420p"])
            args.append(contentsOf: ["-c:a", "aac", "-b:a", "128k"])
        default:
            return nil
        }

        switch request.metadata {
        case .preserve:
            args.append(contentsOf: ["-map_metadata", "0"])
        case .removeLocationOnly:
            args.append(contentsOf: ["-map_metadata", "0"])
            appendLocationRemoval(to: &args)
        case .stripNonessential:
            args.append(contentsOf: ["-map_metadata", "-1"])
        }

        return args
    }

    /// Append the resolved output path as its own argv token.
    public static func appending(output url: URL, to arguments: [String]) -> [String] {
        arguments + [url.path]
    }

    private static func bitrate(for request: MediaConversionRequest) -> String {
        // Map 0...100 quality to a coarse bitrate ladder. Pure function, no I/O.
        switch request.quality {
        case 0..<40: return "96k"
        case 40..<70: return "128k"
        case 70..<90: return "192k"
        default: return "256k"
        }
    }

    private static func appendLocationRemoval(to arguments: inout [String]) {
        arguments.append(contentsOf: [
            "-metadata", "location=",
            "-metadata", "location-eng=",
            "-metadata", "com.apple.quicktime.location.ISO6709="
        ])
    }

    /// VideoToolbox H.264 quality (1=best, 100=worst). Invert the request's
    /// 0..100 quality so higher quality maps to a lower q:v.
    private static func vtVideoQuality(for request: MediaConversionRequest) -> String {
        let q = max(1, min(100, 100 - request.quality))
        return String(q)
    }
}
