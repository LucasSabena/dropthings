import XCTest
@testable import DropThingsCore

@MainActor
final class PermissionCenterTests: XCTestCase {
    func testRefreshPopulatesAllCases() {
        let backend = FakePermissionBackend(states: [
            .accessibility: .granted,
            .screenRecording: .notDetermined
        ])
        let center = PermissionCenter(backend: backend)
        center.refresh()
        XCTAssertEqual(center.state(for: .accessibility), .granted)
        XCTAssertEqual(center.state(for: .screenRecording), .notDetermined)
        XCTAssertEqual(center.state(for: .fullDiskAccess), .unknown)
        XCTAssertEqual(center.state(for: .automation), .unknown)
    }

    func testMissingReturnsOnlyUngranted() {
        let backend = FakePermissionBackend(states: [
            .accessibility: .granted,
            .screenRecording: .notDetermined,
            .automation: .denied
        ])
        let center = PermissionCenter(backend: backend)
        center.refresh()
        let missing = center.missing(from: [.accessibility, .screenRecording, .automation, .fullDiskAccess])
        XCTAssertEqual(missing, [.screenRecording, .automation, .fullDiskAccess])
    }

    func testOpenSettingsRoutesThroughBackend() {
        let backend = FakePermissionBackend()
        let center = PermissionCenter(backend: backend)
        let ok = center.openSystemSettings(for: .accessibility)
        XCTAssertTrue(ok)
        XCTAssertEqual(backend.openCount[.accessibility], 1)
    }
}
