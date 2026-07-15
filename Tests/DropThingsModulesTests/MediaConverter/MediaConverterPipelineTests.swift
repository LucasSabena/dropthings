import XCTest
@testable import DropThingsModules
@testable import DropThingsPlatform
import DropThingsCore
import DropThingsMediaConverterKit

/// Tests the pipeline with fake adapters so failure paths can be injected
/// without touching ImageIO or the real filesystem. QUALITY.md calls out:
/// probe fail, disk full, unsupported, and cancellation as required fault tests.
final class MediaConverterPipelineTests: XCTestCase {

    // MARK: - Happy path

    func testHappyPathImageConversionReportsCompleted() async {
        let source = URL(fileURLWithPath: "/tmp/in/photo.heic")
        let output = URL(fileURLWithPath: "/tmp/out/photo.jpg")
        let request = MediaConversionRequest(
            source: source, outputDirectory: output.deletingLastPathComponent(),
            outputFormat: .jpeg)

        let probe = FakeProbe()
        probe.result = .success(MediaProbeResult(
            url: source, kind: .image, formatHint: .heic,
            fileSize: 50_000, dimensions: MediaDimensions(width: 100, height: 80)))

        let encoder = FakeImageEncoder()
        encoder.output = .success(output)

        let pipeline = MediaConverterPipeline(
            configuration: .init(ffmpegAvailable: false),
            probeAdapter: probe,
            imageEncoder: encoder,
            securityScope: NullSecurityScope(),
            diskSpace: FixedDiskSpace(bytes: 1_000_000_000))

        var phases: [MediaItemPhase] = []
        let result = await pipeline.run(request, jobID: UUID()) { phase in
            phases.append(phase)
        }

        try XCTAssertNotNil(result.get())
        XCTAssertTrue(phases.contains(where: { if case .completed = $0 { true } else { false } }))
    }

    // MARK: - Probe failure

    func testProbeFailureIsReported() async {
        let request = request(format: .jpeg)
        let probe = FakeProbe()
        probe.result = .failure(.probeFailed(reason: "corrupt"))

        let pipeline = makePipeline(probe: probe)
        var failed = false
        let result = await pipeline.run(request, jobID: UUID()) { phase in
            if case .failed = phase { failed = true }
        }
        if case .failure(let error) = result {
            XCTAssertEqual(error, .probeFailed(reason: "corrupt"))
        } else { XCTFail("expected failure") }
        XCTAssertTrue(failed)
    }

    // MARK: - Disk full

    func testInsufficientDiskSpaceFailsBeforeEncode() async {
        let request = request(format: .jpeg)
        let probe = FakeProbe()
        probe.result = .success(MediaProbeResult(
            url: request.source, kind: .image, formatHint: .heic,
            fileSize: 1_000_000, dimensions: MediaDimensions(width: 10, height: 10)))
        let encoder = FakeImageEncoder()
        encoder.output = .success(URL(fileURLWithPath: "/tmp/out/x.jpg"))

        let pipeline = MediaConverterPipeline(
            configuration: .init(ffmpegAvailable: false),
            probeAdapter: probe,
            imageEncoder: encoder,
            securityScope: NullSecurityScope(),
            diskSpace: FixedDiskSpace(bytes: 100)) // far too little

        let result = await pipeline.run(request, jobID: UUID()) { _ in }
        if case .failure(let error) = result {
            if case .insufficientDiskSpace = error { /* ok */ } else { XCTFail("expected disk-full, got \(error)") }
        } else { XCTFail("expected failure") }
        XCTAssertFalse(encoder.invoked, "encoder must not run when disk is full")
    }

    // MARK: - Unsupported conversion

    func testAudioRequestWithoutFFmpegFails() async {
        let request = request(format: .mp3)
        let probe = FakeProbe()
        probe.result = .success(MediaProbeResult(
            url: request.source, kind: .audio, formatHint: .mp3, fileSize: 1000))
        let pipeline = MediaConverterPipeline(
            configuration: .init(ffmpegAvailable: false),
            probeAdapter: probe,
            imageEncoder: FakeImageEncoder(),
            securityScope: NullSecurityScope(),
            diskSpace: FixedDiskSpace(bytes: 1_000_000_000))
        let result = await pipeline.run(request, jobID: UUID()) { _ in }
        if case .failure(let error) = result {
            // The manifest routes mp3 to ffmpeg, which is unavailable.
            XCTAssertTrue(error == .unsupportedConversion(reason: "This output format isn't available in this build.")
                       || error == .ffmpegBackendUnavailable,
                          "got \(error)")
        } else { XCTFail("expected failure") }
    }

    func testKindMismatchFails() async {
        // Output is image but source probes as audio.
        let request = request(format: .jpeg)
        let probe = FakeProbe()
        probe.result = .success(MediaProbeResult(
            url: request.source, kind: .audio, formatHint: .mp3, fileSize: 1000))
        let pipeline = makePipeline(probe: probe)
        let result = await pipeline.run(request, jobID: UUID()) { _ in }
        if case .failure(let error) = result {
            if case .unsupportedConversion = error { /* ok */ } else { XCTFail("got \(error)") }
        } else { XCTFail("expected failure") }
    }

    // MARK: - Cancellation

    func testCancellationBeforeProbeFailsCancelled() async {
        let request = request(format: .jpeg)
        let probe = FakeProbe()
        probe.result = .success(MediaProbeResult(
            url: request.source, kind: .image, formatHint: .heic,
            fileSize: 1000, dimensions: MediaDimensions(width: 10, height: 10)))
        let pipeline = makePipeline(probe: probe)
        let jobID = UUID()
        await pipeline.markCancelled(jobID)
        let result = await pipeline.run(request, jobID: jobID) { _ in }
        if case .failure(let error) = result {
            XCTAssertEqual(error, .cancelled)
        } else { XCTFail("expected cancelled") }
    }

    // MARK: - Re-probe mismatch

    func testReprobeMismatchDiscardsOutput() async {
        let source = URL(fileURLWithPath: "/tmp/in/x.heic")
        let output = URL(fileURLWithPath: "/tmp/out/x.jpg")
        let request = MediaConversionRequest(
            source: source, outputDirectory: output.deletingLastPathComponent(),
            outputFormat: .jpeg)
        let probe = FakeProbe()
        // First probe: image. Second probe (re-probe): audio -> mismatch.
        probe.results = [
            .success(MediaProbeResult(url: source, kind: .image, formatHint: .heic,
                                      fileSize: 1000, dimensions: MediaDimensions(width: 10, height: 10))),
            .success(MediaProbeResult(url: output, kind: .audio, formatHint: .mp3, fileSize: 500))
        ]
        let encoder = FakeImageEncoder()
        encoder.output = .success(output)
        let pipeline = MediaConverterPipeline(
            configuration: .init(ffmpegAvailable: false),
            probeAdapter: probe,
            imageEncoder: encoder,
            securityScope: NullSecurityScope(),
            diskSpace: FixedDiskSpace(bytes: 1_000_000_000))
        let result = await pipeline.run(request, jobID: UUID()) { _ in }
        if case .failure(let error) = result {
            if case .outputReprobeFailed = error { /* ok */ } else { XCTFail("got \(error)") }
        } else { XCTFail("expected re-probe failure") }
    }

    // MARK: - Helpers

    private func request(format: MediaFormatID) -> MediaConversionRequest {
        MediaConversionRequest(
            source: URL(fileURLWithPath: "/tmp/in/x.heic"),
            outputDirectory: URL(fileURLWithPath: "/tmp/out"),
            outputFormat: format)
    }

    private func makePipeline(probe: FakeProbe) -> MediaConverterPipeline {
        MediaConverterPipeline(
            configuration: .init(ffmpegAvailable: false),
            probeAdapter: probe,
            imageEncoder: FakeImageEncoder(),
            securityScope: NullSecurityScope(),
            diskSpace: FixedDiskSpace(bytes: 1_000_000_000))
    }
}

// MARK: - Fakes

final class FakeProbe: MediaProbing {
    var result: Result<MediaProbeResult, MediaConverterError>?
    /// If set, probes consume these in order; otherwise `result` is returned.
    var results: [Result<MediaProbeResult, MediaConverterError>] = []
    private var counter = 0

    func probe(url: URL) async -> Result<MediaProbeResult, MediaConverterError> {
        if !results.isEmpty {
            let r = results[min(counter, results.count - 1)]
            counter += 1
            return r
        }
        return result ?? .failure(.probeFailed(reason: "no fake result configured"))
    }
}

final class FakeImageEncoder: ImageEncoding {
    var output: Result<URL, MediaConverterError> = .failure(.unsupportedConversion(reason: "not configured"))
    var invoked = false

    func encode(_ request: MediaConversionRequest, source: MediaProbeResult) async -> Result<URL, MediaConverterError> {
        invoked = true
        return output
    }
}
