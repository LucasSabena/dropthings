import XCTest
import AppKit
@testable import DropThingsModules
import DropThingsCore
import DropThingsPlatform

/// Mutable permission backend so tests can simulate the user granting Screen
/// Recording after the module already entered `.needsPermission`.
final class MutablePermissionBackend: PermissionBackend, @unchecked Sendable {
    nonisolated(unsafe) var states: [SystemPermission: SystemPermissionState]

    init(states: [SystemPermission: SystemPermissionState] = [:]) {
        self.states = states
    }

    nonisolated func currentState(for permission: SystemPermission) -> SystemPermissionState {
        states[permission] ?? .notDetermined
    }

    @MainActor
    func openSystemSettings(for permission: SystemPermission) -> Bool {
        true
    }
}

@MainActor
final class ScreenshotRegionModuleTests: XCTestCase {
    private var backend: InMemorySettingsBackend!
    private var store: SettingsStore!
    private var permissionBackend: MutablePermissionBackend!
    private var permissions: PermissionCenter!
    private var fileManager: FakeFileManager!

    override func setUp() {
        super.setUp()
        backend = InMemorySettingsBackend()
        store = SettingsStore(backend: backend)
        permissionBackend = MutablePermissionBackend(states: [:])
        permissions = PermissionCenter(backend: permissionBackend)
        fileManager = FakeFileManager()
    }

    private func makeModule() -> ScreenshotRegionModule {
        ScreenshotRegionModule(
            settings: store,
            permissions: permissions,
            fileManager: fileManager,
            pasteboard: .general
        )
    }

    func testRecoversFromNeedsPermissionWhenScreenRecordingGranted() async throws {
        permissionBackend.states = [.screenRecording: .notDetermined]
        let module = makeModule()

        try await module.start()
        XCTAssertEqual(module.state, .needsPermission(missing: [.screenRecording]))

        // User grants Screen Recording in System Settings and returns to the app.
        permissionBackend.states = [.screenRecording: .granted]
        permissions.refresh()
        module.checkPermissionRecovery()

        XCTAssertEqual(module.state, .running)
    }

    func testNoRecoveryWhilePermissionStillMissing() async throws {
        permissionBackend.states = [.screenRecording: .notDetermined]
        let module = makeModule()

        try await module.start()
        XCTAssertEqual(module.state, .needsPermission(missing: [.screenRecording]))

        module.checkPermissionRecovery()

        XCTAssertEqual(module.state, .needsPermission(missing: [.screenRecording]))
    }
}
