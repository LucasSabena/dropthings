import XCTest
@testable import DropThingsCore

final class ModuleStateTests: XCTestCase {
    func testShortLabelsCoverEveryCase() {
        let states: [ModuleState] = [
            .off,
            .starting,
            .running,
            .needsPermission(missing: [.accessibility]),
            .unavailable(reason: "x"),
            .degraded(reason: "y"),
            .failed(reason: "z", recovery: nil)
        ]
        for state in states {
            XCTAssertFalse(state.shortLabel.isEmpty, "Missing label for \(state)")
        }
    }

    func testIsActiveOnlyForRunning() {
        XCTAssertTrue(ModuleState.running.isActive)
        XCTAssertFalse(ModuleState.off.isActive)
        XCTAssertFalse(ModuleState.starting.isActive)
        XCTAssertFalse(ModuleState.needsPermission(missing: [.accessibility]).isActive)
        XCTAssertFalse(ModuleState.failed(reason: "x", recovery: nil).isActive)
    }

    func testIsOffOnlyForOff() {
        XCTAssertTrue(ModuleState.off.isOff)
        XCTAssertFalse(ModuleState.running.isOff)
        XCTAssertFalse(ModuleState.degraded(reason: "y").isOff)
    }

    func testNeedsPermissionCarriesMissingSet() {
        let state = ModuleState.needsPermission(missing: [.accessibility, .screenRecording])
        if case .needsPermission(let missing) = state {
            XCTAssertEqual(missing, [.accessibility, .screenRecording])
        } else {
            XCTFail("Expected needsPermission")
        }
    }
}
