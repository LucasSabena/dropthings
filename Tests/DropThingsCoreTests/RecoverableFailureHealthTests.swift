import XCTest
@testable import DropThingsCore

final class RecoverableFailureHealthTests: XCTestCase {
    func testRecoversOnlyItsOwnFailure() {
        var health = RecoverableFailureHealth()
        let failed = health.failed(reason: "disk")

        XCTAssertEqual(health.recovered(current: failed), .running)
    }

    func testDoesNotClearDifferentDegradation() {
        var health = RecoverableFailureHealth()
        _ = health.failed(reason: "disk")

        XCTAssertEqual(
            health.recovered(current: .degraded(reason: "hotkey")),
            .degraded(reason: "hotkey")
        )
    }
}
