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

    func testRendererSupportsEveryEditorToolInOneExport() throws {
        let source = try image(width: 180, height: 120)
        let annotations: [ScreenshotAnnotation] = [
            ScreenshotAnnotation(kind: .arrow, bounds: CGRect(x: 5, y: 5, width: 30, height: 20), points: [CGPoint(x: 5, y: 5), CGPoint(x: 35, y: 25)]),
            ScreenshotAnnotation(kind: .line, bounds: CGRect(x: 40, y: 5, width: 30, height: 20), points: [CGPoint(x: 40, y: 5), CGPoint(x: 70, y: 25)]),
            ScreenshotAnnotation(kind: .rectangle, bounds: CGRect(x: 75, y: 5, width: 30, height: 20)),
            ScreenshotAnnotation(kind: .ellipse, bounds: CGRect(x: 110, y: 5, width: 30, height: 20)),
            ScreenshotAnnotation(kind: .freehand, bounds: CGRect(x: 5, y: 35, width: 30, height: 20), points: [CGPoint(x: 5, y: 35), CGPoint(x: 20, y: 50), CGPoint(x: 35, y: 40)]),
            ScreenshotAnnotation(kind: .text, bounds: CGRect(x: 40, y: 35, width: 80, height: 24), text: "DropThings"),
            ScreenshotAnnotation(kind: .highlight, bounds: CGRect(x: 5, y: 70, width: 35, height: 18), fill: .yellow),
            ScreenshotAnnotation(kind: .marker, bounds: CGRect(x: 50, y: 68, width: 30, height: 30), markerNumber: 1),
            ScreenshotAnnotation(kind: .blur, bounds: CGRect(x: 90, y: 70, width: 30, height: 20)),
            ScreenshotAnnotation(kind: .pixelate, bounds: CGRect(x: 130, y: 70, width: 30, height: 20))
        ]

        let rendered = AnnotationRenderer.render(source: source, annotations: annotations)

        XCTAssertEqual(rendered?.width, 180)
        XCTAssertEqual(rendered?.height, 120)
    }

    private func image(width: Int, height: Int) throws -> CGImage {
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue), let image = context.makeImage() else { throw XCTSkip("Cannot create test image") }
        return image
    }
}
