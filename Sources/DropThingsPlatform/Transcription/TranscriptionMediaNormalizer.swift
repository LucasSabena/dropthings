import Foundation
import DropThingsMediaConverterKit
import DropThingsTranscriptionKit

/// Converts any audio stream FFmpeg can decode (including the primary audio
/// stream in a video container) into Whisper's required 16 kHz mono PCM WAV.
/// The codec process remains isolated in MediaConverterEngine.xpc.
@MainActor
public final class TranscriptionMediaNormalizer {
    private let engine: any MediaConverterEngineClient

    public init(engine: (any MediaConverterEngineClient)? = nil) {
        self.engine = engine ?? XPCMediaConverterEngineClient()
    }

    public func isAvailable() async -> Bool {
        await engine.ffmpegIsAvailable()
    }

    public func normalize(source: URL, jobID: UUID) async throws -> URL {
        let directory = temporaryDirectory(for: jobID)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let output = directory.appendingPathComponent("normalized.wav")
        let request = MediaConversionRequest(
            source: source,
            outputDirectory: directory,
            outputFormat: .wav,
            audioSampleRate: 16_000,
            audioChannels: 1,
            metadata: .stripNonessential,
            conflict: .fail
        )
        do {
            _ = try await engine.transcode(request, outputURL: output, requestID: jobID)
        } catch MediaConverterError.cancelled {
            throw CancellationError()
        } catch {
            if Task.isCancelled { throw CancellationError() }
            throw error
        }
        try Task.checkCancellation()
        _ = try WAVInspector.inspect(url: output)
        return output
    }

    public func cancel(jobID: UUID) async {
        try? await engine.cancel(jobID)
    }

    public func removeTemporaryFiles(for jobID: UUID) {
        try? FileManager.default.removeItem(at: temporaryDirectory(for: jobID))
    }

    private func temporaryDirectory(for jobID: UUID) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("DropThings-Transcription", isDirectory: true)
            .appendingPathComponent(jobID.uuidString, isDirectory: true)
    }
}
