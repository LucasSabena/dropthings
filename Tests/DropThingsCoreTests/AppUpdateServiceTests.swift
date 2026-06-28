import XCTest
@testable import DropThingsCore

@MainActor
final class AppUpdateServiceTests: XCTestCase {
    func testMarksNewerReleaseAsAvailable() async {
        let release = AppUpdateRelease(
            version: "0.1.2",
            releaseURL: URL(string: "https://example.com/releases/v0.1.2")!,
            downloadURL: URL(string: "https://example.com/DropThings-0.1.2.dmg")!,
            publishedAt: Date(timeIntervalSince1970: 1_000),
            changelog: "Fixes"
        )
        let store = SettingsStore(backend: InMemorySettingsBackend())
        let service = AppUpdateService(
            settings: store,
            client: StubUpdateClient(release: release),
            currentVersion: { "0.1.1" },
            now: { Date(timeIntervalSince1970: 2_000) }
        )

        await service.checkForUpdates()

        guard case .updateAvailable(let available, let checkedAt) = service.state else {
            return XCTFail("Expected updateAvailable, got \(service.state)")
        }
        XCTAssertEqual(available.version, "0.1.2")
        XCTAssertEqual(checkedAt, Date(timeIntervalSince1970: 2_000))
        XCTAssertEqual(service.lastCheckedAt, checkedAt)
    }

    func testMarksSameReleaseAsUpToDate() async {
        let release = AppUpdateRelease(
            version: "v0.1.1",
            releaseURL: URL(string: "https://example.com/releases/v0.1.1")!,
            downloadURL: nil,
            publishedAt: nil,
            changelog: ""
        )
        let store = SettingsStore(backend: InMemorySettingsBackend())
        let service = AppUpdateService(
            settings: store,
            client: StubUpdateClient(release: release),
            currentVersion: { "0.1.1" }
        )

        await service.checkForUpdates()

        guard case .upToDate = service.state else {
            return XCTFail("Expected upToDate, got \(service.state)")
        }
    }

    func testAutomaticCheckCanBeDisabled() {
        let release = AppUpdateRelease(
            version: "0.1.2",
            releaseURL: URL(string: "https://example.com/releases/v0.1.2")!,
            downloadURL: nil,
            publishedAt: nil,
            changelog: ""
        )
        let store = SettingsStore(backend: InMemorySettingsBackend())
        let service = AppUpdateService(
            settings: store,
            client: StubUpdateClient(release: release),
            currentVersion: { "0.1.1" }
        )

        service.setAutomaticChecksEnabled(false)
        service.checkAutomaticallyIfNeeded()

        XCTAssertEqual(service.state, .idle)
    }
}

private struct StubUpdateClient: AppUpdateClient {
    let release: AppUpdateRelease

    func latestRelease() async throws -> AppUpdateRelease {
        release
    }
}
