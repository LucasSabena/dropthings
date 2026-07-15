import Foundation

/// Wire-protocol version. Bumped whenever the request/result DTOs change shape.
/// The client rejects any reply whose `protocolVersion` differs so a stale
/// helper cannot produce silently-wrong output.
public enum MediaConverterProtocolVersion {
    public static let current = 1
}

/// A probe request carried over XPC. Paths are absolute; the helper runs in the
/// app's security context and the app hands it security-scoped URLs.
public struct MediaProbeRequest: Codable, Hashable, Sendable {
    public let protocolVersion: Int
    public let requestID: UUID
    public let url: URL

    public init(requestID: UUID = UUID(), url: URL) {
        self.protocolVersion = MediaConverterProtocolVersion.current
        self.requestID = requestID
        self.url = url
    }
}

/// A transcode request carried over XPC. The helper resolves the FFmpeg
/// arguments from the typed request (never from raw strings).
public struct MediaTranscodeRequest: Codable, Hashable, Sendable {
    public let protocolVersion: Int
    public let requestID: UUID
    public let conversion: MediaConversionRequest
    /// Resolved output URL inside a staging directory the helper owns.
    public let outputURL: URL

    public init(requestID: UUID = UUID(), conversion: MediaConversionRequest, outputURL: URL) {
        self.protocolVersion = MediaConverterProtocolVersion.current
        self.requestID = requestID
        self.conversion = conversion
        self.outputURL = outputURL
    }
}

/// Result of a successful transcode. The host re-probes `outputURL` itself
/// before finalizing (defense in depth: stop-condition "do not finalize an
/// output before successful re-probe").
public struct MediaTranscodeResult: Codable, Hashable, Sendable {
    public let protocolVersion: Int
    public let requestID: UUID
    public let outputURL: URL
    public let outputBytes: Int64

    public init(requestID: UUID, outputURL: URL, outputBytes: Int64) {
        self.protocolVersion = MediaConverterProtocolVersion.current
        self.requestID = requestID
        self.outputURL = outputURL
        self.outputBytes = max(0, outputBytes)
    }
}

/// JSON codec mirroring `AudioControlCodec`. Keeps the `@objc` XPC protocol
/// free of Swift-only types: the wire carries `Data`, and the second tuple
/// element is an error description string (or `nil` on success).
public enum MediaConverterCodec {
    public static func encode<T: Encodable>(_ value: T) throws -> Data {
        try JSONEncoder().encode(value)
    }

    public static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        try JSONDecoder().decode(type, from: data)
    }
}

/// The XPC service the helper exports. Every method takes `Data` and replies
/// with `(Data?, String?)` — `nil` error means success, otherwise the string is
/// a localized description. This shape is required because `@objc` protocols
/// cannot carry rich Swift enums across the XPC boundary.
@objc public protocol MediaConverterXPCServiceProtocol {
    /// Probe a source URL and return a `MediaProbeResult` as JSON.
    func probe(_ data: Data, reply: @escaping (Data?, String?) -> Void)
    /// Run a typed transcode request; returns a `MediaTranscodeResult` as JSON.
    func transcode(_ data: Data, reply: @escaping (Data?, String?) -> Void)
    /// Cancel an in-flight request by id (id encoded as JSON `MediaCancelRequest`).
    func cancel(_ data: Data, reply: @escaping (String?) -> Void)
    /// Whether the reproducibly built FFmpeg binary is packaged in this build.
    func ffmpegIsAvailable(_ reply: @escaping (Bool) -> Void)
}

/// Cancel request DTO.
public struct MediaCancelRequest: Codable, Hashable, Sendable {
    public let requestID: UUID
    public init(requestID: UUID) { self.requestID = requestID }
}
