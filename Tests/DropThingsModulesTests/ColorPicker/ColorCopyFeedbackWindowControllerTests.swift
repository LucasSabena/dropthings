import XCTest
@testable import DropThingsModules

@MainActor
final class ColorCopyFeedbackWindowControllerTests: XCTestCase {
    func testFeedbackStaysBesideCursorWhenThereIsRoom() {
        let origin = ColorCopyFeedbackWindowController.panelOrigin(
            cursor: CGPoint(x: 400, y: 300),
            panelSize: CGSize(width: 220, height: 64),
            visibleFrame: CGRect(x: 0, y: 0, width: 1000, height: 700)
        )

        XCTAssertEqual(origin, CGPoint(x: 416, y: 220))
    }

    func testFeedbackFlipsInsideSecondaryDisplayAtBottomRight() {
        let frame = CGRect(x: 1440, y: 100, width: 1200, height: 800)
        let origin = ColorCopyFeedbackWindowController.panelOrigin(
            cursor: CGPoint(x: 2600, y: 110),
            panelSize: CGSize(width: 220, height: 64),
            visibleFrame: frame
        )

        XCTAssertEqual(origin, CGPoint(x: 2364, y: 126))
        XCTAssertTrue(frame.contains(CGRect(origin: origin, size: CGSize(width: 220, height: 64))))
    }
}
