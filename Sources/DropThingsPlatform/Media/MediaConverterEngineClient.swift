import Foundation
import DropThingsCore
import DropThingsMediaConverterKit

/// Client for the isolated `MediaConverterEngine` XPC helper. The helper owns
/// FFmpeg execution so a codec crash can never terminate DropThings. Mirrors
/// the `AudioControlEngineClient` pattern.
@MainActor
public protocol MediaConverterEngineClient: AnyObject {
    var onInterruption: (@MainActor @Sendable () -> Void)? { get set }
    func connect()
    func invalidate()
    /// Probe a source URL.
    func probe(_ url: URL) async throws -> MediaProbeResult
    /// Run a typed transcode; returns the staging output URL + bytes.
    func transcode(
        _ request: MediaConversionRequest,
        outputURL: URL,
        requestID: UUID
    ) async throws -> MediaTranscodeResult
    /// Cancel an in-flight request.
    func cancel(_ requestID: UUID) async throws
    /// Whether the reproducibly built FFmpeg binary is packaged.
    func ffmpegIsAvailable() async -> Bool
}

public enum MediaConverterEngineClientError: LocalizedError, Equatable, Sendable {
    case helperUnavailable
    case invalidReply(String)

    public var errorDescription: String? {
        switch self {
        case .helperUnavailable:
            return "The isolated media engine is unavailable."
        case .invalidReply(let detail):
            return "The media engine returned an invalid response: \(detail)"
        }
    }
}

/// XPC-backed client. Connects lazily and recovers from interruption by
/// dropping the connection; callers retry.
@MainActor
public final class XPCMediaConverterEngineClient: MediaConverterEngineClient {
    public static let serviceName = "app.dropthings.MediaConverterEngine"

    public var onInterruption: (@MainActor @Sendable () -> Void)?

    private var connection: NSXPCConnection?
    private let logger = ModuleLogger(subsystem: "app.dropthings", category: "media-converter.client")

    public init() {}

    public func connect() {
        guard connection == nil else { return }
        let next = NSXPCConnection(serviceName: Self.serviceName)
        next.remoteObjectInterface = NSXPCInterface(with: MediaConverterXPCServiceProtocol.self)
        next.interruptionHandler = { [weak self] in
            Task { @MainActor in
                self?.connection = nil
                self?.onInterruption?()
            }
        }
        next.invalidationHandler = { [weak self] in
            Task { @MainActor in self?.connection = nil }
        }
        next.resume()
        connection = next
        logger.info("Connected to media engine helper")
    }

    public func invalidate() {
        connection?.invalidate()
        connection = nil
    }

    public func probe(_ url: URL) async throws -> MediaProbeResult {
        let payload = MediaProbeRequest(url: url)
        let data = try MediaConverterCodec.encode(payload)
        return try await withService { service, gate in
            service.probe(data) { reply, error in
                Self.decodeOrThrow(gate, data: reply, error: error)
            }
        }
    }

    public func transcode(
        _ request: MediaConversionRequest,
        outputURL: URL,
        requestID: UUID
    ) async throws -> MediaTranscodeResult {
        let payload = MediaTranscodeRequest(requestID: requestID, conversion: request, outputURL: outputURL)
        let data = try MediaConverterCodec.encode(payload)
        let result: MediaTranscodeResult = try await withService { service, gate in
            service.transcode(data) { reply, error in
                Self.decodeOrThrow(gate, data: reply, error: error)
            }
        }
        guard result.protocolVersion == MediaConverterProtocolVersion.current,
              result.requestID == requestID,
              result.outputURL.standardizedFileURL == outputURL.standardizedFileURL else {
            throw MediaConverterEngineClientError.invalidReply("The response did not match the request.")
        }
        return result
    }

    public func cancel(_ requestID: UUID) async throws {
        let payload = MediaCancelRequest(requestID: requestID)
        let data = try MediaConverterCodec.encode(payload)
        let _: Void = try await withService { service, gate in
            service.cancel(data) { error in
                if let error {
                    gate.fail(MediaConverterEngineClientError.invalidReply(error))
                } else {
                    gate.succeed(())
                }
            }
        }
    }

    public func ffmpegIsAvailable() async -> Bool {
        do {
            return try await withService { service, gate in
                service.ffmpegIsAvailable { gate.succeed($0) }
            }
        } catch {
            return false
        }
    }

    // MARK: - Plumbing

    private func withService<T>(
        _ operation: @escaping (MediaConverterXPCServiceProtocol, MediaContinuationGate<T>) -> Void
    ) async throws -> T {
        connect()
        guard let connection else { throw MediaConverterEngineClientError.helperUnavailable }
        return try await withCheckedThrowingContinuation { continuation in
            let gate = MediaContinuationGate(continuation)
            guard let service = connection.remoteObjectProxyWithErrorHandler({ error in
                gate.fail(error)
            }) as? MediaConverterXPCServiceProtocol else {
                gate.fail(MediaConverterEngineClientError.helperUnavailable)
                return
            }
            operation(service, gate)
        }
    }

    private static func decodeOrThrow<T: Decodable>(
        _ gate: MediaContinuationGate<T>,
        data: Data?,
        error: String?
    ) {
        do {
            if let error { throw MediaConverterEngineClientError.invalidReply(error) }
            guard let data else { throw MediaConverterEngineClientError.helperUnavailable }
            let result = try MediaConverterCodec.decode(T.self, from: data)
            gate.succeed(result)
        } catch {
            gate.fail(error)
        }
    }
}

private final class MediaContinuationGate<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: CheckedContinuation<Value, Error>?

    init(_ continuation: CheckedContinuation<Value, Error>) {
        stored = continuation
    }

    func succeed(_ value: Value) { take()?.resume(returning: value) }
    func fail(_ error: Error) { take()?.resume(throwing: error) }

    private func take() -> CheckedContinuation<Value, Error>? {
        lock.lock()
        defer { lock.unlock() }
        let value = stored
        stored = nil
        return value
    }
}
