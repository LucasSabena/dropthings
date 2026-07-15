import XCTest
@testable import DropThingsMediaConverterKit

final class MediaPresetTests: XCTestCase {

    func testShippedPresetsCoverRequiredSet() {
        let ids = Set(MediaPreset.shipped.map(\.id))
        XCTAssertEqual(ids, Set(MediaPresetID.allCases))
        // PRODUCT.md "Definition of done" presets.
        for required in [MediaPresetID.webImage, .transparentWeb, .email, .smallerVideo, .audioOnly, .audioForTranscription] {
            XCTAssertTrue(MediaPreset.find(required) != nil)
        }
    }

    func testResolveWebImageProducesJPEG1600() throws {
        let req = try MediaPlanResolver.resolve(
            presetID: .webImage, source: URL(fileURLWithPath: "/x/a.heic"),
            sourceKind: .image, outputDirectory: URL(fileURLWithPath: "/out"),
            manifest: .shipped, ffmpegAvailable: false)
        XCTAssertEqual(req.outputFormat, .jpeg)
        if case .maxEdge(let edge) = req.resize { XCTAssertEqual(edge, 1600) } else { XCTFail("expected maxEdge") }
        XCTAssertEqual(req.metadata, .stripNonessential)
    }

    func testResolveAudioOnlyRequiresFFmpeg() {
        XCTAssertThrowsError(
            try MediaPlanResolver.resolve(
                presetID: .audioOnly, source: URL(fileURLWithPath: "/x/a.mp4"),
                sourceKind: .video, outputDirectory: URL(fileURLWithPath: "/out"),
                manifest: .shipped, ffmpegAvailable: false)
        ) { error in
            guard case MediaPlanResolver.ResolveError.unsupportedFormat = error else {
                return XCTFail("expected unsupportedFormat when FFmpeg unavailable")
            }
        }
    }

    func testResolveAudioOnlySucceedsWithFFmpeg() throws {
        let req = try MediaPlanResolver.resolve(
            presetID: .audioOnly, source: URL(fileURLWithPath: "/x/a.mp4"),
            sourceKind: .video, outputDirectory: URL(fileURLWithPath: "/out"),
            manifest: .shipped, ffmpegAvailable: true)
        XCTAssertEqual(req.outputFormat, .m4aAAC)
    }

    func testKindMismatchThrows() {
        XCTAssertThrowsError(
            try MediaPlanResolver.resolve(
                presetID: .webImage, source: URL(fileURLWithPath: "/x/a.mp3"),
                sourceKind: .audio, outputDirectory: URL(fileURLWithPath: "/out"),
                manifest: .shipped, ffmpegAvailable: true)
        ) { error in
            guard case MediaPlanResolver.ResolveError.kindNotApplicable = error else {
                return XCTFail("expected kindNotApplicable")
            }
        }
    }
}
