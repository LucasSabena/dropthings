import XCTest
import Combine
@testable import DropThingsCore

@MainActor
final class PermissionCenterTests: XCTestCase {
    private var settingsBackend: InMemorySettingsBackend!
    private var settings: SettingsStore!

    override func setUp() {
        super.setUp()
        settingsBackend = InMemorySettingsBackend()
        settings = SettingsStore(backend: settingsBackend)
    }

    func testRefreshPopulatesAllCases() {
        let backend = FakePermissionBackend(states: [
            .accessibility: .granted,
            .screenRecording: .notDetermined
        ])
        let center = PermissionCenter(backend: backend, settings: settings)
        center.refresh()
        XCTAssertEqual(center.state(for: .accessibility), .granted)
        XCTAssertEqual(center.state(for: .screenRecording), .notDetermined)
        XCTAssertEqual(center.state(for: .fullDiskAccess), .unknown)
        XCTAssertEqual(center.state(for: .automation), .unknown)
    }

    func testRefreshDoesNotPublishWhenPermissionStateIsUnchanged() {
        let backend = FakePermissionBackend(states: [.accessibility: .granted])
        let center = PermissionCenter(backend: backend, settings: settings)
        var publications = 0
        let observation = center.$states.dropFirst().sink { _ in publications += 1 }

        center.refresh()

        XCTAssertEqual(publications, 0)
        withExtendedLifetime(observation) {}
    }

    func testMissingReturnsOnlyUngranted() {
        let backend = FakePermissionBackend(states: [
            .accessibility: .granted,
            .screenRecording: .notDetermined,
            .automation: .denied
        ])
        let center = PermissionCenter(backend: backend, settings: settings)
        center.refresh()
        let missing = center.missing(from: [.accessibility, .screenRecording, .automation, .fullDiskAccess])
        XCTAssertEqual(missing, [.screenRecording, .automation, .fullDiskAccess])
    }

    func testOpenSettingsRoutesThroughBackend() {
        let backend = FakePermissionBackend()
        let center = PermissionCenter(backend: backend, settings: settings)
        let ok = center.openSystemSettings(for: .accessibility)
        XCTAssertTrue(ok)
        XCTAssertEqual(backend.openCount[.accessibility], 1)
    }

    func testPrivacySettingsURLsUseSystemSettingsDeepLinkFormat() {
        XCTAssertEqual(
            SystemPermission.accessibility.settingsPaneURL?.absoluteString,
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        )
        XCTAssertEqual(
            SystemPermission.screenRecording.settingsPaneURL?.absoluteString,
            "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
        )
    }

    func testRequestPermissionRecordsPromptedFlagForAccessibility() {
        let backend = FakePermissionBackend(states: [.accessibility: .notDetermined])
        let center = PermissionCenter(backend: backend, settings: settings)

        _ = center.requestPermission(.accessibility)
        center.refresh()

        XCTAssertEqual(center.state(for: .accessibility), .denied)
    }

    func testRequestPermissionRecordsPromptedFlagForScreenRecording() {
        let backend = FakePermissionBackend(states: [.screenRecording: .notDetermined])
        let center = PermissionCenter(backend: backend, settings: settings)

        _ = center.requestPermission(.screenRecording)
        center.refresh()

        XCTAssertEqual(center.state(for: .screenRecording), .denied)
    }

    func testGrantedPermissionStaysGrantedAfterRequest() {
        let backend = FakePermissionBackend(states: [.accessibility: .granted])
        let center = PermissionCenter(backend: backend, settings: settings)

        _ = center.requestPermission(.accessibility)
        center.refresh()

        XCTAssertEqual(center.state(for: .accessibility), .granted)
    }

    func testResetPromptStateRestoresNotDetermined() {
        let backend = FakePermissionBackend(states: [.accessibility: .notDetermined])
        let center = PermissionCenter(backend: backend, settings: settings)

        _ = center.requestPermission(.accessibility)
        center.refresh()
        XCTAssertEqual(center.state(for: .accessibility), .denied)

        center.resetPromptState(for: .accessibility)
        center.refresh()

        XCTAssertEqual(center.state(for: .accessibility), .notDetermined)
    }

    func testRequestPermissionDoesNotMarkFullDiskAccessPrompted() {
        let backend = FakePermissionBackend()
        let center = PermissionCenter(backend: backend, settings: settings)

        _ = center.requestPermission(.fullDiskAccess)
        center.refresh()

        XCTAssertEqual(center.state(for: .fullDiskAccess), .unknown)
    }

    func testPromptedFlagPersistsAcrossCenterInstances() {
        let backend = FakePermissionBackend(states: [.screenRecording: .notDetermined])
        let firstCenter = PermissionCenter(backend: backend, settings: settings)
        _ = firstCenter.requestPermission(.screenRecording)

        let secondCenter = PermissionCenter(backend: backend, settings: settings)
        secondCenter.refresh()

        XCTAssertEqual(secondCenter.state(for: .screenRecording), .denied)
    }
}
