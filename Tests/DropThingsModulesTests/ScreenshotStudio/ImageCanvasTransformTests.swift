import XCTest
@testable import DropThingsModules

final class ImageCanvasTransformTests: XCTestCase {
    func testRoundTripPreservesTranslatedSourcePixels() {
        let transform = ImageCanvasTransform(sourceRect: CGRect(x: 120, y: 80, width: 2000, height: 1000), availableRect: CGRect(x: 0, y: 0, width: 800, height: 600), zoom: 1)
        let point = CGPoint(x: 845.5, y: 333.25)
        let actual = transform.sourcePoint(forViewPoint: transform.viewPoint(forSourcePoint: point))
        XCTAssertEqual(actual.x, point.x, accuracy: 0.001)
        XCTAssertEqual(actual.y, point.y, accuracy: 0.001)
    }
    func testZoomCentersImageWithoutChangingSourceMapping() {
        let one = ImageCanvasTransform(sourceRect: CGRect(x: 0, y: 0, width: 100, height: 100), availableRect: CGRect(x: 0, y: 0, width: 300, height: 300), zoom: 1)
        let two = ImageCanvasTransform(sourceRect: CGRect(x: 0, y: 0, width: 100, height: 100), availableRect: CGRect(x: 0, y: 0, width: 300, height: 300), zoom: 2)
        XCTAssertEqual(one.viewPoint(forSourcePoint: CGPoint(x: 50, y: 50)), two.viewPoint(forSourcePoint: CGPoint(x: 50, y: 50)))
    }
}
