import Foundation

/// Resolves the location of the reproducibly-built FFmpeg binary. Until Phase 0
/// (pinning + packaging) lands, the resolver reports unavailable so the module
/// never advertises audio/video conversions it cannot actually perform.
public enum FFmpegAvailability: Sendable, Equatable {
    case available(at: URL)
    case unavailable(reason: String)
}

public protocol FFmpegResolving: AnyObject, Sendable {
    func resolve() -> FFmpegAvailability
}

/// Production resolver. Looks for a pinned binary inside the app bundle's
/// `Contents/SharedSupport/FFmpeg/` (the planned packaging location). Returns
/// `.unavailable` until that binary is shipped.
public final class BundledFFmpegResolver: FFmpegResolving {
    private let bundleURLProvider: @Sendable () -> URL?

    public init(bundleURLProvider: @escaping @Sendable () -> URL? = { Bundle.main.bundleURL }) {
        self.bundleURLProvider = bundleURLProvider
    }

    public func resolve() -> FFmpegAvailability {
        guard let bundle = bundleURLProvider() else {
            return .unavailable(reason: "App bundle not found.")
        }
        // FFmpeg lives in the helper XPC bundle (Contents/SharedSupport/FFmpeg).
        // When this resolver runs inside the helper, Bundle.main is the helper;
        // when it runs in the app, the helper is at Contents/XPCServices/.
        let candidates = candidatePaths(for: bundle)
        for candidate in candidates {
            if FileManager.default.isExecutableFile(atPath: candidate.path) {
                return .available(at: candidate)
            }
        }
        return .unavailable(reason: "FFmpeg is not packaged in this build.")
    }

    /// All plausible locations for the bundled FFmpeg binary, in lookup order.
    private func candidatePaths(for bundleURL: URL) -> [URL] {
        let sharedSupport = bundleURL
            .appendingPathComponent("Contents")
            .appendingPathComponent("SharedSupport")
            .appendingPathComponent("FFmpeg")
            .appendingPathComponent("ffmpeg")
        let helper = bundleURL
            .appendingPathComponent("Contents")
            .appendingPathComponent("XPCServices")
            .appendingPathComponent("MediaConverterEngine.xpc")
            .appendingPathComponent("Contents")
            .appendingPathComponent("SharedSupport")
            .appendingPathComponent("FFmpeg")
            .appendingPathComponent("ffmpeg")
        return [sharedSupport, helper]
    }
}

/// Test/preview resolver that always reports unavailable. Used by the module
/// until the binary is reproducibly built and pinned.
public final class UnavailableFFmpegResolver: FFmpegResolving {
    public let reason: String
    public init(reason: String = "FFmpeg is not packaged in this build.") { self.reason = reason }
    public func resolve() -> FFmpegAvailability { .unavailable(reason: reason) }
}
