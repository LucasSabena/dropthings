import XCTest
import AppKit
@testable import DropThingsModules
import DropThingsCore
import DropThingsPlatform

/// Fake assertion adapter so `KeepAwakeModule` tests never touch IOKit.
@MainActor
final class FakeKeepAwakeAssertion: KeepAwakeAssertionProtocol, @unchecked Sendable {
    var shouldFailNextAcquisition = false
    var failureReason: KeepAwakeAssertion.FailureReason = .osStatus(-1)

    private(set) var acquireCallCount = 0
    private(set) var releaseCallCount = 0
    private(set) var isActive = false
    private(set) var currentAssertionIDs: [UInt32] = []
    private(set) var lastKeepDisplayAwake = false

    func acquireKeepAwakeAssertions(keepDisplayAwake: Bool) throws {
        acquireCallCount += 1
        if shouldFailNextAcquisition {
            throw failureReason
        }
        isActive = true
        lastKeepDisplayAwake = keepDisplayAwake
        currentAssertionIDs = keepDisplayAwake ? [1, 2] : [1]
    }

    func release() {
        releaseCallCount += 1
        isActive = false
        currentAssertionIDs = []
    }
}

@MainActor
final class KeepAwakeModuleTests: XCTestCase {
    private var backend: InMemorySettingsBackend!
    private var store: SettingsStore!
    private var assertion: FakeKeepAwakeAssertion!

    override func setUp() {
        super.setUp()
        backend = InMemorySettingsBackend()
        store = SettingsStore(backend: backend)
        assertion = FakeKeepAwakeAssertion()
    }

    private func makeModule(enabled: Bool = false) -> KeepAwakeModule {
        store.saveKeepAwakeSettings(KeepAwakeSettings(enabled: enabled))
        return KeepAwakeModule(settings: store, assertion: assertion)
    }

    func testSuccessfulAssertionSetsRunning() async throws {
        let module = makeModule(enabled: true)
        try await module.start()

        XCTAssertEqual(module.state, .running)
        XCTAssertTrue(assertion.isActive)
        XCTAssertEqual(assertion.acquireCallCount, 1)
        XCTAssertNil(module.lastError)
        XCTAssertFalse(assertion.lastKeepDisplayAwake)
    }

    func testDisplayAssertionIsOptIn() async throws {
        let module = makeModule(enabled: true)
        module.setKeepDisplayAwake(true)

        try await module.start()

        XCTAssertTrue(assertion.lastKeepDisplayAwake)
        XCTAssertEqual(assertion.currentAssertionIDs, [1, 2])
    }

    func testEnabledModuleIsAuthoritativeOverExpiredLegacySession() async throws {
        store.saveKeepAwakeSettings(
            KeepAwakeSettings(
                enabled: true,
                durationMinutes: 30,
                activeUntil: Date().addingTimeInterval(-1)
            )
        )
        let module = KeepAwakeModule(settings: store, assertion: assertion)

        try await module.start()

        XCTAssertTrue(module.keepAwakeSettings.enabled)
        XCTAssertTrue(assertion.isActive)
        XCTAssertNil(module.keepAwakeSettings.activeUntil)
        XCTAssertNil(module.keepAwakeSettings.durationMinutes)
        XCTAssertEqual(module.state, .running)
    }

    func testFailedAcquisitionSetsDegraded() async throws {
        let module = makeModule(enabled: false)
        assertion.shouldFailNextAcquisition = true
        try await module.start()

        if case .degraded = module.state {
            // Expected
        } else {
            XCTFail("Expected degraded state, got \(module.state)")
        }
        XCTAssertFalse(assertion.isActive)
        XCTAssertNotNil(module.lastError)
    }

    func testStoppingModuleAlwaysReleasesAssertion() async throws {
        let module = makeModule(enabled: false)
        try await module.start()
        XCTAssertTrue(assertion.isActive)

        await module.stop()

        XCTAssertFalse(assertion.isActive)
        XCTAssertFalse(module.keepAwakeSettings.enabled)
        XCTAssertEqual(module.state, .off)
    }
}
