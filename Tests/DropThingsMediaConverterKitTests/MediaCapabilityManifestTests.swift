import XCTest
@testable import DropThingsMediaConverterKit

final class MediaCapabilityManifestTests: XCTestCase {

    func testImageFormatsNativeWithoutFFmpeg() {
        let m = MediaCapabilityManifest.shipped
        XCTAssertTrue(m.canEncode(.png, ffmpegAvailable: false))
        XCTAssertTrue(m.canEncode(.jpeg, ffmpegAvailable: false))
        XCTAssertTrue(m.canEncode(.heic, ffmpegAvailable: false))
        XCTAssertFalse(m.canEncode(.webp, ffmpegAvailable: false))
    }

    func testAudioFormatsRequireFFmpeg() {
        let m = MediaCapabilitiesFixture.shipped
        XCTAssertFalse(m.canEncode(.m4aAAC, ffmpegAvailable: false))
        XCTAssertTrue(m.canEncode(.m4aAAC, ffmpegAvailable: true))
        XCTAssertFalse(m.canEncode(.flac, ffmpegAvailable: false))
    }

    func testVideoFormatsRequireFFmpeg() {
        let m = MediaCapabilitiesFixture.shipped
        XCTAssertFalse(m.canEncode(.mp4H264, ffmpegAvailable: false))
        XCTAssertTrue(m.canEncode(.mp4H264, ffmpegAvailable: true))
    }

    func testBackendRouting() {
        let m = MediaCapabilitiesFixture.shipped
        XCTAssertEqual(m.backend(for: .png, ffmpegAvailable: false), .native)
        XCTAssertEqual(m.backend(for: .m4aAAC, ffmpegAvailable: true), .ffmpeg)
        XCTAssertNil(m.backend(for: .m4aAAC, ffmpegAvailable: false))
    }

    func testAvailableOutputsHideUnsupported() {
        let m = MediaCapabilitiesFixture.shipped
        XCTAssertTrue(m.availableOutputs(for: .image, ffmpegAvailable: false).contains(.jpeg))
        XCTAssertTrue(m.availableOutputs(for: .audio, ffmpegAvailable: false).isEmpty)
        XCTAssertFalse(m.availableOutputs(for: .audio, ffmpegAvailable: false).contains(.mp3))
    }
}

/// Local typealias so the test reads naturally while staying in sync with the
/// shipped manifest.
private enum MediaCapabilitiesFixture {
    static let shipped = MediaCapabilityManifest.shipped
}
