import Foundation
import DropThingsAudioControlKit

public enum AudioControlEngineClientError: LocalizedError, Sendable {
    case helperUnavailable
    case invalidReply(String)

    public var errorDescription: String? {
        switch self {
        case .helperUnavailable:
            return "The isolated audio engine is unavailable. Normal system audio was left untouched."
        case .invalidReply(let detail):
            return "The isolated audio engine returned an invalid response: \(detail)"
        }
    }
}

@MainActor
public protocol AudioControlEngineClient: AnyObject {
    var onInterruption: (@MainActor @Sendable () -> Void)? { get set }
    func connect()
    func invalidate()
    func apply(_ desiredState: AudioControlDesiredState) async throws -> AudioControlObservedState
    func snapshot() async throws -> AudioControlObservedState
    func restoreNormalAudio() async throws
    func sendMediaCommand(_ command: MediaTransportCommand) async throws -> AudioControlObservedState
}

@MainActor
public final class XPCAudioControlEngineClient: AudioControlEngineClient {
    public static let serviceName = "app.dropthings.AudioControlEngine"

    public var onInterruption: (@MainActor @Sendable () -> Void)?

    private var connection: NSXPCConnection?

    public init() {}

    public func connect() {
        guard connection == nil else { return }
        let next = NSXPCConnection(serviceName: Self.serviceName)
        next.remoteObjectInterface = NSXPCInterface(with: AudioControlXPCServiceProtocol.self)
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
    }

    public func invalidate() {
        connection?.invalidate()
        connection = nil
    }

    public func apply(_ desiredState: AudioControlDesiredState) async throws -> AudioControlObservedState {
        let data = try AudioControlCodec.encode(desiredState)
        return try await withService { service, continuation in
            service.applyDesiredState(data) { reply, error in
                Self.resumeObserved(continuation, data: reply, error: error)
            }
        }
    }

    public func snapshot() async throws -> AudioControlObservedState {
        try await withService { service, continuation in
            service.snapshot { reply, error in
                Self.resumeObserved(continuation, data: reply, error: error)
            }
        }
    }

    public func restoreNormalAudio() async throws {
        let _: Void = try await withService { service, continuation in
            service.restoreNormalAudio { error in
                if let error {
                    continuation.resume(throwing: AudioControlEngineClientError.invalidReply(error))
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    public func sendMediaCommand(_ command: MediaTransportCommand) async throws -> AudioControlObservedState {
        try await withService { service, continuation in
            service.sendMediaCommand(command.rawValue) { reply, error in
                Self.resumeObserved(continuation, data: reply, error: error)
            }
        }
    }

    private func withService<T>(
        _ operation: @escaping (AudioControlXPCServiceProtocol, CheckedContinuation<T, Error>) -> Void
    ) async throws -> T {
        connect()
        guard let connection else { throw AudioControlEngineClientError.helperUnavailable }
        return try await withCheckedThrowingContinuation { continuation in
            guard let service = connection.remoteObjectProxyWithErrorHandler({ error in
                continuation.resume(throwing: error)
            }) as? AudioControlXPCServiceProtocol else {
                continuation.resume(throwing: AudioControlEngineClientError.helperUnavailable)
                return
            }
            operation(service, continuation)
        }
    }

    private static func resumeObserved(
        _ continuation: CheckedContinuation<AudioControlObservedState, Error>,
        data: Data?,
        error: String?
    ) {
        do {
            if let error { throw AudioControlEngineClientError.invalidReply(error) }
            guard let data else { throw AudioControlEngineClientError.helperUnavailable }
            let state = try AudioControlCodec.decode(AudioControlObservedState.self, from: data)
            guard state.protocolVersion == AudioControlProtocolVersion.current else {
                throw AudioControlProtocolError.incompatibleVersion(received: state.protocolVersion)
            }
            continuation.resume(returning: state)
        } catch {
            continuation.resume(throwing: error)
        }
    }
}
