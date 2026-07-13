import XCTest
import CoreGraphics
@testable import DropThingsModules
import DropThingsPlatform

private actor SequenceCaptureService: ScreenCaptureService {
    private var images: [CGImage]
    init(_ images: [CGImage]) { self.images = images }
    func capture(_ request: ScreenCaptureRequest) async throws -> CapturedImage {
        guard !images.isEmpty else { throw ScreenCaptureError.captureFailed }
        let image = images.count == 1 ? images[0] : images.removeFirst()
        return CapturedImage(image: image, sourceRect: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    }
}
private struct NoopScrollDriver: ScrollDriver { func scroll(at point: CGPoint, deltaY: Int32) throws {} }

@MainActor
final class ScrollCaptureCoordinatorTests: XCTestCase {
    func testStopsOnRepeatedFrameAndKeepsValidStitch() async throws {
        let first = try fixture(Array(0..<100)); let second = try fixture(Array(60..<160))
        let coordinator = ScrollCaptureCoordinator()
        let result = try await coordinator.capture(region: CGRect(x: 0, y: 0, width: 8, height: 100), service: SequenceCaptureService([first, second, second]), driver: NoopScrollDriver(), maximumFrames: 4)
        XCTAssertEqual(result.frameCount, 2)
        XCTAssertFalse(result.isPartial)
        XCTAssertEqual(result.image.width, 8)
        XCTAssertEqual(result.image.height, 160)
    }
    private func fixture(_ rows: [Int]) throws -> CGImage {
        let width = 8; var data = [UInt8](); for row in rows { for _ in 0..<width { let c = UInt8(row % 255); data += [c, c &+ 30, c &+ 70, 255] } }
        guard let context = CGContext(data: &data, width: width, height: rows.count, bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue), let image = context.makeImage() else { throw XCTSkip("Fixture creation failed") }; return image
    }
}
