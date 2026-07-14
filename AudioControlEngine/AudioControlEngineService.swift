import Foundation
import DropThingsAudioControlKit

final class AudioControlEngineService: NSObject, AudioControlXPCServiceProtocol {
    private let engine = AudioEngineCoordinator()

    func applyDesiredState(_ data: Data, reply: @escaping (Data?, String?) -> Void) {
        Task {
            do {
                let desired = try AudioControlCodec.decode(AudioControlDesiredState.self, from: data)
                let observed = try await engine.apply(desired)
                reply(try AudioControlCodec.encode(observed), nil)
            } catch {
                reply(nil, error.localizedDescription)
            }
        }
    }

    func snapshot(reply: @escaping (Data?, String?) -> Void) {
        Task {
            do { reply(try AudioControlCodec.encode(await engine.snapshot()), nil) }
            catch { reply(nil, error.localizedDescription) }
        }
    }

    func restoreNormalAudio(reply: @escaping (String?) -> Void) {
        Task {
            await engine.restoreNormalAudio()
            reply(nil)
        }
    }
}

final class AudioControlEngineListenerDelegate: NSObject, NSXPCListenerDelegate {
    private let service = AudioControlEngineService()

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        connection.exportedInterface = NSXPCInterface(with: AudioControlXPCServiceProtocol.self)
        connection.exportedObject = service
        connection.invalidationHandler = { [weak service] in
            guard let service else { return }
            service.restoreNormalAudio { _ in }
        }
        connection.resume()
        return true
    }
}
