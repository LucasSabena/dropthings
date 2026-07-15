import XCTest
import DropThingsMediaConverterKit
import DropThingsPlatform

@MainActor
private final class CancelledMediaEngine: MediaConverterEngineClient {
    var onInterruption: (@MainActor @Sendable () -> Void)?

    func connect() {}
    func invalidate() {}
    func probe(_ url: URL) async throws -> MediaProbeResult {
        throw MediaConverterError.probeFailed(reason: "unused")
    }
    func transcode(
        _ request: MediaConversionRequest,
        outputURL: URL,
        requestID: UUID
    ) async throws -> MediaTranscodeResult {
        throw MediaConverterError.cancelled
    }
    func cancel(_ requestID: UUID) async throws {}
    func ffmpegIsAvailable() async -> Bool { true }
}

@MainActor
final class TranscriptionMediaNormalizerTests: XCTestCase {
    func testCancelledMediaConversionMapsToTaskCancellation() async {
        let normalizer = TranscriptionMediaNormalizer(engine: CancelledMediaEngine())

        do {
            _ = try await normalizer.normalize(
                source: URL(fileURLWithPath: "/tmp/input.opus"),
                jobID: UUID()
            )
            XCTFail("Expected cancellation")
        } catch is CancellationError {
            // Expected: the queue renders this as Cancelled, never Failed.
        } catch {
            XCTFail("Expected CancellationError, got \(error)")
        }
    }
}
