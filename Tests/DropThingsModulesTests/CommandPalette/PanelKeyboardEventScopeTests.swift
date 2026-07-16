import XCTest
@testable import DropThingsModules

final class PanelKeyboardEventScopeTests: XCTestCase {
    func testAcceptsEventsFromTheOwningKeyWindow() {
        XCTAssertTrue(PanelKeyboardEventScope.accepts(
            windowNumber: 42,
            isKeyWindow: true,
            expectedWindowNumber: 42
        ))
    }

    func testRejectsEventsFromAnotherKeyWindow() {
        XCTAssertFalse(PanelKeyboardEventScope.accepts(
            windowNumber: 99,
            isKeyWindow: true,
            expectedWindowNumber: 42
        ))
    }

    func testRejectsEventsAfterTheOwningWindowLosesKeyStatus() {
        XCTAssertFalse(PanelKeyboardEventScope.accepts(
            windowNumber: 42,
            isKeyWindow: false,
            expectedWindowNumber: 42
        ))
    }
}
