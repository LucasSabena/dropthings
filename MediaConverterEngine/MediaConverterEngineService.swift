import Foundation
import DropThingsMediaConverterKit

final class MediaConverterEngineService: NSObject, MediaConverterXPCServiceProtocol {
    private let runner = HelperFFmpegRunner.shared

    func probe(_ data: Data, reply: @escaping (Data?, String?) -> Void) {
        Task {
            do {
                let request = try MediaConverterCodec.decode(MediaProbeRequest.self, from: data)
                try validate(request.protocolVersion)
                let json = try await runner.probe(url: request.url)
                let result = try FFprobeJSONDecoder.decode(json, sourceURL: request.url)
                reply(try MediaConverterCodec.encode(result), nil)
            } catch { reply(nil, error.localizedDescription) }
        }
    }

    func transcode(_ data: Data, reply: @escaping (Data?, String?) -> Void) {
        Task {
            do {
                let request = try MediaConverterCodec.decode(MediaTranscodeRequest.self, from: data)
                try validate(request.protocolVersion)
                let bytes = try await runner.transcode(
                    requestID: request.requestID,
                    request: request.conversion,
                    outputURL: request.outputURL
                )
                let result = MediaTranscodeResult(requestID: request.requestID, outputURL: request.outputURL, outputBytes: bytes)
                reply(try MediaConverterCodec.encode(result), nil)
            } catch { reply(nil, error.localizedDescription) }
        }
    }

    func cancel(_ data: Data, reply: @escaping (String?) -> Void) {
        do {
            let request = try MediaConverterCodec.decode(MediaCancelRequest.self, from: data)
            runner.cancel(request.requestID)
            reply(nil)
        } catch { reply(error.localizedDescription) }
    }

    func ffmpegIsAvailable(_ reply: @escaping (Bool) -> Void) {
        reply(HelperFFmpegRunner.ffmpegURL() != nil && HelperFFmpegRunner.ffprobeURL() != nil)
    }

    private func validate(_ version: Int) throws {
        guard version == MediaConverterProtocolVersion.current else {
            throw MediaConverterError.incompatibleProtocolVersion(received: version)
        }
    }
}

final class MediaConverterEngineListenerDelegate: NSObject, NSXPCListenerDelegate {
    private let service = MediaConverterEngineService()

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        connection.exportedInterface = NSXPCInterface(with: MediaConverterXPCServiceProtocol.self)
        connection.exportedObject = service
        connection.resume()
        return true
    }
}
