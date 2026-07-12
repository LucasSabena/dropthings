import XCTest
import SwiftUI
@testable import DropThingsCore

/// Minimal module used to verify `ModuleRegistry` lifecycle behavior.
final class StubModule: DropThingsModule, @unchecked Sendable {
    let id: ModuleID
    let name: String
    let summary: String
    let requiredPermissions: [SystemPermission]
    @Published private(set) var state: ModuleState = .off
    private(set) var startCount = 0
    private(set) var stopCount = 0
    var startError: Error?

    init(
        id: ModuleID,
        name: String = "Stub",
        summary: String = "stub",
        requiredPermissions: [SystemPermission] = []
    ) {
        self.id = id
        self.name = name
        self.summary = summary
        self.requiredPermissions = requiredPermissions
    }

    func start() async throws {
        startCount += 1
        if let startError { throw startError }
        state = .running
    }

    func stop() async {
        stopCount += 1
        state = .off
    }

    func report(_ newState: ModuleState) {
        state = newState
    }

    @MainActor
    func makeSettingsView() -> AnyView {
        AnyView(EmptyView())
    }
}

@MainActor
final class ModuleRegistryTests: XCTestCase {
    private var backend: InMemorySettingsBackend!
    private var store: SettingsStore!
    private var permissions: PermissionCenter!
    private var registry: ModuleRegistry!

    override func setUp() {
        super.setUp()
        backend = InMemorySettingsBackend()
        store = SettingsStore(backend: backend)
        permissions = PermissionCenter(backend: FakePermissionBackend())
        registry = ModuleRegistry(settings: store, permissions: permissions)
    }

    func testRegisterStartsInOffState() {
        let stub = StubModule(id: .fake)
        registry.register(stub)
        XCTAssertEqual(registry.states[stub.id], .off)
    }

    func testRegistryMirrorsModuleStateChangesAfterStart() async {
        let stub = StubModule(id: .fake)
        registry.register(stub)

        stub.report(.degraded(reason: "Shortcut conflict"))
        await Task.yield()
        try? await Task.sleep(nanoseconds: 10_000_000)

        XCTAssertEqual(registry.states[stub.id], .degraded(reason: "Shortcut conflict"))
    }

    func testEnableStartsModuleWhenPermissionsGranted() async {
        permissions = PermissionCenter(backend: FakePermissionBackend(states: [.accessibility: .granted]))
        registry = ModuleRegistry(settings: store, permissions: permissions)
        let stub = StubModule(id: .fake, requiredPermissions: [.accessibility])
        registry.register(stub)

        registry.setEnabled(true, for: stub.id)
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(stub.startCount, 1)
        XCTAssertEqual(registry.states[stub.id], .running)
        XCTAssertTrue(registry.isEnabled(stub.id), "Enable flag must persist")
    }

    func testEnableMovesToNeedsPermissionWhenMissing() async {
        let backend = FakePermissionBackend(states: [.accessibility: .notDetermined])
        permissions = PermissionCenter(backend: backend)
        registry = ModuleRegistry(settings: store, permissions: permissions)
        let stub = StubModule(id: .fake, requiredPermissions: [.accessibility])
        registry.register(stub)

        registry.setEnabled(true, for: stub.id)
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(stub.startCount, 0, "Module must not start when permissions missing")
        if case .needsPermission(let missing) = registry.states[stub.id] ?? .off {
            XCTAssertEqual(missing, [.accessibility])
        } else {
            XCTFail("Expected needsPermission, got \(String(describing: registry.states[stub.id]))")
        }
    }

    func testEnablingDoesNotForgetARejectedPermission() async throws {
        let settingsBackend = InMemorySettingsBackend()
        let persistedStore = SettingsStore(backend: settingsBackend)
        let permissionBackend = FakePermissionBackend(states: [.accessibility: .notDetermined])
        let firstCenter = PermissionCenter(backend: permissionBackend, settings: persistedStore)
        _ = firstCenter.requestPermission(.accessibility)
        firstCenter.refresh()
        XCTAssertEqual(firstCenter.state(for: .accessibility), .denied)

        let permissionRegistry = ModuleRegistry(settings: persistedStore, permissions: firstCenter)
        let stub = StubModule(id: .fake, requiredPermissions: [.accessibility])
        permissionRegistry.register(stub)
        permissionRegistry.setEnabled(true, for: stub.id)
        try await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(firstCenter.state(for: .accessibility), .denied)
        XCTAssertEqual(permissionRegistry.missingPermissions(for: stub.id), [.accessibility])
    }

    func testPruneUnregisteredEnablementKeepsOnlyRegisteredModules() throws {
        let initial = [
            ModuleID.fake.rawValue: true,
            ModuleID.commandPalette.rawValue: true
        ]
        store.setData(try JSONEncoder().encode(initial), ModuleRegistry.enabledKey)
        registry.register(StubModule(id: .fake))

        registry.pruneUnregisteredEnablement()

        XCTAssertTrue(registry.isEnabled(.fake))
        XCTAssertFalse(registry.isEnabled(.commandPalette))
        let data = try XCTUnwrap(store.data(ModuleRegistry.enabledKey))
        XCTAssertEqual(
            try JSONDecoder().decode([String: Bool].self, from: data),
            [ModuleID.fake.rawValue: true]
        )
    }

    func testPermissionRevocationStopsRunningModule() async {
        let permissionBackend = FakePermissionBackend(states: [.accessibility: .granted])
        permissions = PermissionCenter(backend: permissionBackend)
        registry = ModuleRegistry(settings: store, permissions: permissions)
        let stub = StubModule(id: .fake, requiredPermissions: [.accessibility])
        registry.register(stub)
        registry.setEnabled(true, for: stub.id)
        try? await Task.sleep(nanoseconds: 50_000_000)

        permissionBackend.states[.accessibility] = .notDetermined
        await registry.refreshPermissionsAndRetry()

        XCTAssertEqual(stub.stopCount, 1)
        XCTAssertEqual(registry.states[stub.id], .needsPermission(missing: [.accessibility]))
        XCTAssertTrue(registry.isEnabled(stub.id), "Revocation should not disable the user's choice")
    }

    func testDisableStopsAndResetsToOff() async {
        permissions = PermissionCenter(backend: FakePermissionBackend(states: [.accessibility: .granted]))
        registry = ModuleRegistry(settings: store, permissions: permissions)
        let stub = StubModule(id: .fake, requiredPermissions: [.accessibility])
        registry.register(stub)

        registry.setEnabled(true, for: stub.id)
        try? await Task.sleep(nanoseconds: 50_000_000)
        registry.setEnabled(false, for: stub.id)
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(stub.stopCount, 1)
        XCTAssertEqual(registry.states[stub.id], .off)
        XCTAssertFalse(registry.isEnabled(stub.id))
    }

    func testStartFailureMapsToFailedState() async {
        permissions = PermissionCenter(backend: FakePermissionBackend())
        registry = ModuleRegistry(settings: store, permissions: permissions)
        let stub = StubModule(id: .fake)
        stub.startError = NSError(domain: "stub", code: 1)
        registry.register(stub)

        registry.setEnabled(true, for: stub.id)
        try? await Task.sleep(nanoseconds: 50_000_000)

        if case .failed = registry.states[stub.id] ?? .off {
            // expected
        } else {
            XCTFail("Expected failed state, got \(String(describing: registry.states[stub.id]))")
        }
    }

    func testBootEnabledModulesStartsPreviouslyEnabled() async {
        permissions = PermissionCenter(backend: FakePermissionBackend())
        registry = ModuleRegistry(settings: store, permissions: permissions)
        let stub = StubModule(id: .fake)
        registry.register(stub)
        registry.setEnabled(true, for: stub.id)
        try? await Task.sleep(nanoseconds: 50_000_000)

        let freshRegistry = ModuleRegistry(settings: store, permissions: permissions)
        freshRegistry.register(StubModule(id: .fake))
        freshRegistry.bootEnabledModules()
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(freshRegistry.isEnabled(.fake), true)
        XCTAssertEqual(freshRegistry.states[.fake], .running)
    }
}
