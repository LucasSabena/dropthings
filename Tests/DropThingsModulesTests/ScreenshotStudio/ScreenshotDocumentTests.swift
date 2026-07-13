import XCTest
import CoreGraphics
@testable import DropThingsModules

@MainActor
final class ScreenshotDocumentTests: XCTestCase {
    func testAnnotationsAreUndoableAndRedoableWithoutChangingSourceBounds() throws {
        let document = ScreenshotDocument(source: try image(width: 20, height: 10))
        let annotation = ScreenshotAnnotation(kind: .rectangle, bounds: CGRect(x: 2, y: 2, width: 8, height: 4))
        document.add(annotation)
        XCTAssertEqual(document.annotations, [annotation])
        XCTAssertTrue(document.isDirty)
        document.undo()
        XCTAssertTrue(document.annotations.isEmpty)
        XCTAssertEqual(document.sourceBounds, CGRect(x: 0, y: 0, width: 20, height: 10))
        document.redo()
        XCTAssertEqual(document.annotations, [annotation])
    }

    func testCropIsClippedToImmutableSourceBounds() throws {
        let document = ScreenshotDocument(source: try image(width: 20, height: 10))
        document.setCrop(CGRect(x: -2, y: 3, width: 30, height: 10))
        XCTAssertEqual(document.effectiveCrop, CGRect(x: 0, y: 3, width: 20, height: 7))
    }

    func testRendererReturnsCroppedPixelDimensions() throws {
        let source = try image(width: 20, height: 10)
        let rendered = AnnotationRenderer.render(source: source, crop: CGRect(x: 5, y: 2, width: 8, height: 4), annotations: [])
        XCTAssertEqual(rendered?.width, 8)
        XCTAssertEqual(rendered?.height, 4)
    }

    private func image(width: Int, height: Int) throws -> CGImage {
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue), let image = context.makeImage() else { throw XCTSkip("Cannot create test image") }
        return image
    }
}
