import XCTest
import CoreGraphics
@testable import DropThingsModules

final class FrameAlignerTests: XCTestCase {
    func testFindsExactOverlap() throws {
        let first = try stripedImage(rows: Array(0..<100))
        let second = try stripedImage(rows: Array(60..<160))
        let alignment = FrameAligner.align(previous: first, next: second, minimumOverlap: 20)
        XCTAssertEqual(alignment?.overlap, 40)
        XCTAssertGreaterThanOrEqual(alignment?.confidence ?? 0, 0.99)
    }
    func testRejectsBlankRepeatedFrames() throws {
        let image = try stripedImage(rows: Array(repeating: 12, count: 100))
        // Repeated flat frames cannot establish a trustworthy scrolling seam.
        XCTAssertNil(FrameAligner.align(previous: image, next: image, minimumOverlap: 20))
    }
    func testStitchPreservesEveryNonOverlappedRow() throws {
        let first = try stripedImage(rows: Array(0..<100))
        let second = try stripedImage(rows: Array(60..<160))
        let result = try XCTUnwrap(FrameAligner.stitch([first, second]))
        XCTAssertEqual(result.image.height, 160)
        let values = try redRows(result.image)
        XCTAssertEqual(values.first, 0)
        XCTAssertEqual(values[59], 59)
        XCTAssertEqual(values[60], 60)
        XCTAssertEqual(values.last, 159)
    }
    private func stripedImage(rows: [Int]) throws -> CGImage {
        let width = 8; var bytes = [UInt8]()
        for row in rows { for _ in 0..<width { let value = UInt8(row % 255); bytes += [value, value &+ 31, value &+ 67, 255] } }
        guard let context = CGContext(data: &bytes, width: width, height: rows.count, bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue), let image = context.makeImage() else { throw XCTSkip("Cannot make fixture") }
        return image
    }
    private func redRows(_ image: CGImage) throws -> [Int] {
        var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
        guard let context = CGContext(data: &bytes, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: image.width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw XCTSkip("Cannot decode fixture") }
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return (0..<image.height).map { Int(bytes[$0 * image.width * 4]) }
    }
}
