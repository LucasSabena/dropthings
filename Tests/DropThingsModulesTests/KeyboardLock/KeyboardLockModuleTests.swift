import XCTest
import DropThingsCore
import DropThingsPlatform
@testable import DropThingsModules

private final class FakeKeyboardTap: KeyboardEventTapping, @unchecked Sendable {
    var shouldFail = false
    private(set) var isActive = false
    private(set) var locked = false

    func start() throws {
        if shouldFail { throw KeyboardEventTap.TapError.creationFailed }
        isActive = true
    }

    func stop() {
        isActive = false
        locked = false
    }

    func setLocked(_ locked: Bool) { self.locked = locked }
}

@MainActor
private final class GrantedAccessibilityBackend: PermissionBackend, @unchecked Sendable {
    func currentState(for permission: SystemPermission) -> SystemPermissionState {
        permission == .accessibility ? .granted : .notDetermined
    }

    func openSystemSettings(for permission: SystemPermission) -> Bool { true }
}

@MainActor
final class KeyboardLockModuleTests: XCTestCase {
    private func makeModule(tap: FakeKeyboardTap) -> KeyboardLockModule {
        let permissions = PermissionCenter(backend: GrantedAccessibilityBackend())
        return KeyboardLockModule(permissions: permissions, tap: tap)
    }

    func testStartsReadyWithoutInstallingGlobalEventTap() async throws {
        let tap = FakeKeyboardTap()
        let module = makeModule(tap: tap)

        try await module.start()

        XCTAssertEqual(module.state, .running)
        XCTAssertFalse(tap.isActive)
        XCTAssertFalse(module.isKeyboardLocked)
        XCTAssertFalse(tap.locked)
    }

    func testExplicitLockInstallsTapAndBlocksKeys() async throws {
        let tap = FakeKeyboardTap()
        let module = makeModule(tap: tap)
        try await module.start()

        module.toggleLock()

        XCTAssertTrue(tap.isActive)
        XCTAssertTrue(module.isKeyboardLocked)
        XCTAssertTrue(tap.locked)
    }

    func testUnlockRemovesTapInsteadOfLeavingPassiveListener() async throws {
        let tap = FakeKeyboardTap()
        let module = makeModule(tap: tap)
        try await module.start()
        module.toggleLock()

        module.toggleLock()

        XCTAssertFalse(tap.isActive)
        XCTAssertFalse(module.isKeyboardLocked)
        XCTAssertFalse(tap.locked)
        XCTAssertEqual(module.state, .running)
    }

    func testStoppingAlwaysUnlocksAndRemovesTap() async throws {
        let tap = FakeKeyboardTap()
        let module = makeModule(tap: tap)
        try await module.start()
        module.toggleLock()

        await module.stop()

        XCTAssertEqual(module.state, .off)
        XCTAssertFalse(module.isKeyboardLocked)
        XCTAssertFalse(tap.isActive)
        XCTAssertFalse(tap.locked)
    }

    func testTapFailureNeverLocksKeyboard() async throws {
        let tap = FakeKeyboardTap()
        tap.shouldFail = true
        let module = makeModule(tap: tap)

        try await module.start()
        module.toggleLock()

        if case .failed = module.state {} else { XCTFail("Expected failed state") }
        XCTAssertFalse(module.isKeyboardLocked)
        XCTAssertFalse(tap.locked)
    }

    func testTapFailureCanBeRetriedWithoutTogglingModuleLifecycle() async throws {
        let tap = FakeKeyboardTap()
        tap.shouldFail = true
        let module = makeModule(tap: tap)
        try await module.start()
        module.toggleLock()
        tap.shouldFail = false

        module.toggleLock()

        XCTAssertEqual(module.state, .running)
        XCTAssertTrue(module.isKeyboardLocked)
        XCTAssertTrue(tap.isActive)
        XCTAssertTrue(tap.locked)
    }

    func testMenuBarEscapeRouteCannotBeHidden() {
        let module = makeModule(tap: FakeKeyboardTap())

        XCTAssertEqual(module.menuBarPresentation?.isVisibleByDefault, true)
        XCTAssertEqual(module.menuBarPresentation?.allowsVisibilityCustomization, false)
    }
}
