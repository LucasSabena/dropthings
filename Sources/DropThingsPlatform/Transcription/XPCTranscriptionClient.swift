import Foundation
import DropThingsTranscriptionKit

public actor XPCTranscriptionClient: LocalTranscriptionClient {
    public static let serviceName = "app.dropthings.TranscriptionEngine"

    private var connection: NSXPCConnection?

    public init() {}

    public func availability() async -> TranscriptionClientAvailability {
        do {
            let value: TranscriptionEngineAvailability = try await call { service, finish in
                service.availability { data, failure in finish(data, failure) }
            }
            guard value.protocolVersion == TranscriptionProtocol.currentVersion else {
                return .unavailable(reason: "The local transcription engine uses an incompatible protocol.")
            }
            return .available(version: value.engineVersion)
        } catch {
            return .unavailable(reason: "The isolated local transcription engine is unavailable.")
        }
    }

    public func transcribe(
        _ request: TranscriptionRequest,
        progress: @escaping @Sendable (TranscriptionProgress) -> Void
    ) async throws -> TranscriptDocument {
        guard request.protocolVersion == TranscriptionProtocol.currentVersion else {
            throw TranscriptionContractError.unsupportedProtocol(request.protocolVersion)
        }
        guard FileManager.default.fileExists(atPath: request.inputURL.path),
              FileManager.default.fileExists(atPath: request.modelURL.path) else {
            throw TranscriptionClientError.invalidRequest("The input audio or selected model is missing.")
        }

        progress(.init(phase: .inspect))
        _ = try WAVInspector.inspect(url: request.inputURL)
        let requestData = try TranscriptionEngineCodec.encode(request)
        progress(.init(phase: .modelLoad))
        progress(.init(phase: .transcribe))

        let document: TranscriptDocument = try await withTaskCancellationHandler {
            try await call { service, finish in
                service.transcribe(requestData) { data, failure in finish(data, failure) }
            }
        } onCancel: {
            Task { await self.cancel(jobID: request.jobID) }
        }
        if Task.isCancelled { throw TranscriptionClientError.cancelled }
        guard document.jobID == request.jobID else {
            throw TranscriptionClientError.malformedResult("The response belongs to a different transcription job.")
        }
        progress(.init(phase: .finalize))
        return document
    }

    public func cancel(jobID: UUID) async {
        do {
            let _: Void = try await callVoid { service, finish in
                service.cancel(jobID.uuidString) { failure in finish(failure) }
            }
        } catch {
            // Cancellation is best-effort. The original operation will surface
            // an XPC interruption or its own engine error if the helper is gone.
        }
    }

    private func connect() -> NSXPCConnection {
        if let connection { return connection }
        let next = NSXPCConnection(serviceName: Self.serviceName)
        next.remoteObjectInterface = NSXPCInterface(with: TranscriptionEngineXPCProtocol.self)
        next.interruptionHandler = { [weak self] in
            Task { await self?.dropConnection() }
        }
        next.invalidationHandler = { [weak self] in
            Task { await self?.dropConnection() }
        }
        next.resume()
        connection = next
        return next
    }

    private func dropConnection() {
        connection = nil
    }

    private func call<T: Decodable>(
        _ operation: @escaping (TranscriptionEngineXPCProtocol, @escaping (Data?, Data?) -> Void) -> Void
    ) async throws -> T {
        let connection = connect()
        return try await withCheckedThrowingContinuation { continuation in
            let gate = ContinuationGate(continuation)
            guard let service = connection.remoteObjectProxyWithErrorHandler({ error in
                gate.fail(TranscriptionClientError.unavailable(error.localizedDescription))
            }) as? TranscriptionEngineXPCProtocol else {
                gate.fail(TranscriptionClientError.unavailable("The local transcription service could not be reached."))
                return
            }
            operation(service) { data, failureData in
                do {
                    if let failureData { throw try Self.clientError(from: failureData) }
                    guard let data else {
                        throw TranscriptionClientError.malformedResult("The engine returned an empty response.")
                    }
                    gate.succeed(try TranscriptionEngineCodec.decode(T.self, from: data))
                } catch {
                    gate.fail(error)
                }
            }
        }
    }

    private func callVoid(
        _ operation: @escaping (TranscriptionEngineXPCProtocol, @escaping (Data?) -> Void) -> Void
    ) async throws {
        let connection = connect()
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let gate = ContinuationGate(continuation)
            guard let service = connection.remoteObjectProxyWithErrorHandler({ error in
                gate.fail(TranscriptionClientError.unavailable(error.localizedDescription))
            }) as? TranscriptionEngineXPCProtocol else {
                gate.fail(TranscriptionClientError.unavailable("The local transcription service could not be reached."))
                return
            }
            operation(service) { failureData in
                do {
                    if let failureData { throw try Self.clientError(from: failureData) }
                    gate.succeed(())
                } catch {
                    gate.fail(error)
                }
            }
        }
    }

    private static func clientError(from data: Data) throws -> TranscriptionClientError {
        let failure = try TranscriptionEngineCodec.decode(TranscriptionEngineFailure.self, from: data)
        switch failure.kind {
        case .invalidRequest: return .invalidRequest(failure.message)
        case .engineFailure: return .helperFailed(failure.message)
        case .cancelled: return .cancelled
        }
    }
}

private final class ContinuationGate<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Value, Error>?

    init(_ continuation: CheckedContinuation<Value, Error>) {
        self.continuation = continuation
    }

    func succeed(_ value: Value) {
        take()?.resume(returning: value)
    }

    func fail(_ error: Error) {
        take()?.resume(throwing: error)
    }

    private func take() -> CheckedContinuation<Value, Error>? {
        lock.lock()
        defer { lock.unlock() }
        defer { continuation = nil }
        return continuation
    }
}
