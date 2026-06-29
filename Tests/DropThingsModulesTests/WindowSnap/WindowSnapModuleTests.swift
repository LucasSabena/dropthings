import XCTest
import AppKit
@testable import DropThingsModules
import DropThingsCore
import DropThingsPlatform

/// Records snap requests and optionally returns a configured error.
@MainActor
final class FakeWindowSnapper: WindowSnapperProtocol, @unchecked Sendable {
    private(set) var recordedActions: [WindowSnapAction] = []
    var nextError: WindowSnapError?

    func snap(_ action: WindowSnapAction) -> Result<Void, WindowSnapError> {
        recordedActions.append(action)
        if let error = nextError {
            return .failure(error)
        }
        return .success(())
    }
}

/// Deterministic permission backend for module tests.
@MainActor
final class FakePermissionBackend: PermissionBackend, @unchecked Sendable {
    var states: [SystemPermission: SystemPermissionState] = [:]
    var openCount: [SystemPermission: Int] = [:]

    init(states: [SystemPermission: SystemPermissionState] = [:]) {
        self.states = states
    }

    func currentState(for permission: SystemPermission) -> SystemPermissionState {
        states[permission] ?? .notDetermined
    }

    func openSystemSettings(for permission: SystemPermission) -> Bool {
        openCount[permission, default: 0] += 1
        return true
    }
}

@MainActor
final class WindowSnapModuleTests: XCTestCase {
    private var backend: InMemorySettingsBackend!
    private var store: SettingsStore!
    private var permissions: PermissionCenter!
    private var snapper: FakeWindowSnapper!

    override func setUp() {
        super.setUp()
        backend = InMemorySettingsBackend()
        store = SettingsStore(backend: backend)
        permissions = PermissionCenter(backend: FakePermissionBackend(states: [.accessibility: .granted]))
        snapper = FakeWindowSnapper()
    }

    private func makeModule() -> WindowSnapModule {
        WindowSnapModule(settings: store, permissions: permissions, snapper: snapper)
    }

    func testStartBlockedWithoutPermission() async {
        permissions = PermissionCenter(backend: FakePermissionBackend(states: [.accessibility: .notDetermined]))
        let module = makeModule()
        try? await module.start()
        XCTAssertEqual(module.state, .needsPermission(missing: [.accessibility]))
    }

    func testStartSucceedsWithPermission() async throws {
        let module = makeModule()
        try await module.start()
        XCTAssertEqual(module.state, .running)
    }

    func testSnapForwardsActionToSnapper() async throws {
        let module = makeModule()
        try await module.start()
        module.snap(.leftHalf)
        XCTAssertEqual(snapper.recordedActions, [.leftHalf])
        XCTAssertNil(module.lastError)
    }

    func testSnapIsIgnoredWhenNotRunning() async throws {
        let module = makeModule()
        module.snap(.rightHalf)
        XCTAssertTrue(snapper.recordedActions.isEmpty)
    }

    func testSnapFailureSurfacesAsLastError() async throws {
        let module = makeModule()
        try await module.start()
        snapper.nextError = .noFocusedWindow
        module.snap(.maximize)
        XCTAssertEqual(module.lastError, WindowSnapError.noFocusedWindow.localizedDescription)
    }

    func testAccessibilityDeniedTransitionsToNeedsPermission() async throws {
        let module = makeModule()
        try await module.start()
        snapper.nextError = .accessibilityDenied
        module.snap(.topHalf)
        XCTAssertEqual(module.state, .needsPermission(missing: [.accessibility]))
    }

    func testSetHotkeyPersistsAndReRegistersWhenRunning() async throws {
        let module = makeModule()
        try await module.start()
        let custom = GlobalHotkey.Definition(keyCode: 5, modifiers: 6, id: 200)
        module.setHotkey(.bottomLeft, custom)
        XCTAssertEqual(module.windowSnapSettings.hotkey(for: .bottomLeft), custom)
        let loaded = store.loadWindowSnapSettings()
        XCTAssertEqual(loaded.hotkey(for: .bottomLeft), custom)
    }

    func testStopUnregistersHotkeysAndClearsError() async throws {
        let module = makeModule()
        try await module.start()
        snapper.nextError = .noFocusedWindow
        module.snap(.maximize)
        await module.stop()
        XCTAssertEqual(module.state, .off)
        XCTAssertNil(module.lastError)
    }
}
