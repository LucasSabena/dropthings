import Foundation
import DropThingsTranscriptionKit
import DropThingsWhisperEngine

final class TranscriptionEngineService: NSObject, TranscriptionEngineXPCProtocol {
    private let engine = WhisperTranscriptionEngine()
    private let inferenceQueue = DispatchQueue(label: "app.dropthings.transcription.inference", qos: .userInitiated)

    func availability(reply: @escaping (Data?, Data?) -> Void) {
        do {
            let value = TranscriptionEngineAvailability(engineVersion: engine.version)
            reply(try TranscriptionEngineCodec.encode(value), nil)
        } catch {
            reply(nil, Self.failureData(for: error))
        }
    }

    func transcribe(_ requestData: Data, reply: @escaping (Data?, Data?) -> Void) {
        let request: TranscriptionRequest
        do {
            request = try TranscriptionEngineCodec.decode(TranscriptionRequest.self, from: requestData)
        } catch {
            reply(nil, Self.failureData(kind: .invalidRequest, message: error.localizedDescription))
            return
        }

        engine.prepare(jobID: request.jobID)
        inferenceQueue.async { [engine] in
            do {
                let document = try engine.transcribe(request)
                reply(try TranscriptionEngineCodec.encode(document), nil)
            } catch {
                reply(nil, Self.failureData(for: error))
            }
        }
    }

    func cancel(_ jobID: String, reply: @escaping (Data?) -> Void) {
        guard let id = UUID(uuidString: jobID) else {
            reply(Self.failureData(kind: .invalidRequest, message: "The transcription job identifier is invalid."))
            return
        }
        engine.cancel(jobID: id)
        reply(nil)
    }

    private static func failureData(for error: Error) -> Data? {
        let kind: TranscriptionEngineFailure.Kind
        switch error {
        case TranscriptionClientError.cancelled, is CancellationError:
            kind = .cancelled
        case is TranscriptionContractError, is WAVInspectionError:
            kind = .invalidRequest
        default:
            kind = .engineFailure
        }
        return failureData(kind: kind, message: error.localizedDescription)
    }

    private static func failureData(kind: TranscriptionEngineFailure.Kind, message: String) -> Data? {
        try? TranscriptionEngineCodec.encode(TranscriptionEngineFailure(kind: kind, message: message))
    }
}

final class TranscriptionEngineListenerDelegate: NSObject, NSXPCListenerDelegate {
    private let service = TranscriptionEngineService()

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        connection.exportedInterface = NSXPCInterface(with: TranscriptionEngineXPCProtocol.self)
        connection.exportedObject = service
        connection.resume()
        return true
    }
}
