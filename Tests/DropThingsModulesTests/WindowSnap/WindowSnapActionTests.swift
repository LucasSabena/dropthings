import XCTest
import CoreGraphics
@testable import DropThingsPlatform

final class WindowSnapActionTests: XCTestCase {
    private let screenFrame = CGRect(x: 0, y: 0, width: 2000, height: 1200)
    private let windowFrame = CGRect(x: 100, y: 100, width: 400, height: 300)

    func testMaximizeFillsScreen() {
        let frame = WindowSnapAction.maximize.targetFrame(
            windowFrame: windowFrame,
            screenFrame: screenFrame
        )
        XCTAssertEqual(frame, screenFrame)
    }

    func testLeftHalfUsesLeftSide() {
        let frame = WindowSnapAction.leftHalf.targetFrame(
            windowFrame: windowFrame,
            screenFrame: screenFrame
        )
        XCTAssertEqual(frame.minX, screenFrame.minX)
        XCTAssertEqual(frame.width, screenFrame.width / 2)
        XCTAssertEqual(frame.height, screenFrame.height)
    }

    func testRightHalfUsesRightSide() {
        let frame = WindowSnapAction.rightHalf.targetFrame(
            windowFrame: windowFrame,
            screenFrame: screenFrame
        )
        XCTAssertEqual(frame.minX, screenFrame.midX)
        XCTAssertEqual(frame.width, screenFrame.width / 2)
        XCTAssertEqual(frame.height, screenFrame.height)
    }

    func testTopHalfUsesUpperHalf() {
        let frame = WindowSnapAction.topHalf.targetFrame(
            windowFrame: windowFrame,
            screenFrame: screenFrame
        )
        XCTAssertEqual(frame.minY, screenFrame.midY)
        XCTAssertEqual(frame.width, screenFrame.width)
        XCTAssertEqual(frame.height, screenFrame.height / 2)
    }

    func testBottomHalfUsesLowerHalf() {
        let frame = WindowSnapAction.bottomHalf.targetFrame(
            windowFrame: windowFrame,
            screenFrame: screenFrame
        )
        XCTAssertEqual(frame.minY, screenFrame.minY)
        XCTAssertEqual(frame.width, screenFrame.width)
        XCTAssertEqual(frame.height, screenFrame.height / 2)
    }

    func testCornersAreQuarters() {
        let topLeft = WindowSnapAction.topLeft.targetFrame(
            windowFrame: windowFrame,
            screenFrame: screenFrame
        )
        let topRight = WindowSnapAction.topRight.targetFrame(
            windowFrame: windowFrame,
            screenFrame: screenFrame
        )
        let bottomLeft = WindowSnapAction.bottomLeft.targetFrame(
            windowFrame: windowFrame,
            screenFrame: screenFrame
        )
        let bottomRight = WindowSnapAction.bottomRight.targetFrame(
            windowFrame: windowFrame,
            screenFrame: screenFrame
        )

        XCTAssertEqual(topLeft, CGRect(x: 0, y: 600, width: 1000, height: 600))
        XCTAssertEqual(topRight, CGRect(x: 1000, y: 600, width: 1000, height: 600))
        XCTAssertEqual(bottomLeft, CGRect(x: 0, y: 0, width: 1000, height: 600))
        XCTAssertEqual(bottomRight, CGRect(x: 1000, y: 0, width: 1000, height: 600))
    }

    func testAllActionsHaveDisplayName() {
        for action in WindowSnapAction.allCases {
            XCTAssertFalse(action.displayName.isEmpty, "\(action) has no display name")
        }
    }

    func testAllActionsHaveDefaultHotkey() {
        for action in WindowSnapAction.allCases {
            XCTAssertNotNil(action.defaultHotkey, "\(action) should have a default hotkey")
        }
    }

    func testDefaultHotkeysHaveUniqueIDs() {
        let ids = WindowSnapAction.allCases.compactMap { $0.defaultHotkey?.id }
        XCTAssertEqual(ids.count, Set(ids).count)
    }
}
