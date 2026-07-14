import SwiftUI
import XCTest
@testable import DropThingsCore
@testable import DropThingsModules
import DropThingsPlatform

final class CommandPaletteExecutionTests: XCTestCase {
    func testKeyboardSelectionWrapsAndPreservesStableID() {
        let ids = ["one", "two", "three"]
        XCTAssertEqual(PaletteSelection.moved(currentID: "three", by: 1, resultIDs: ids), "one")
        XCTAssertEqual(PaletteSelection.moved(currentID: "one", by: -1, resultIDs: ids), "three")
        XCTAssertEqual(PaletteSelection.preserving(currentID: "two", resultIDs: ids), "two")
        XCTAssertEqual(PaletteSelection.preserving(currentID: "missing", resultIDs: ids), "one")
    }

    @MainActor
    func testCommandActionExecutes() async throws {
        let flag = CommandExecutionFlag()
        let action = PaletteAction(id: "run", title: "Run", symbolName: "return", role: .primary) {
            flag.value = true
        }
        try await action.perform()
        XCTAssertTrue(flag.value)
    }

    @MainActor
    func testModuleDefaultCommandsAreEmpty() {
        XCTAssertTrue(DummyModule().commands.isEmpty)
    }

    @MainActor
    func testHotkeyRegistersOnStartAndUnregistersOnStop() async throws {
        let store = SettingsStore(backend: InMemorySettingsBackend())
        let fake = FakePaletteHotkey()
        let module = CommandPaletteModule(
            settings: store,
            permissions: PermissionCenter(backend: PalettePermissionBackend()),
            commandSource: { [] },
            applicationCatalog: EmptyApplicationCatalog(),
            spotlight: EmptySpotlight(),
            workspace: PaletteWorkspace(),
            hotkeyFactory: { _, _ in fake }
        )
        try await module.start()
        XCTAssertEqual(fake.registerCount, 1)
        await module.stop()
        XCTAssertEqual(fake.unregisterCount, 1)
    }

    @MainActor
    func testHotkeyRegistrationFailureDegradesWithoutStartingListener() async throws {
        let store = SettingsStore(backend: InMemorySettingsBackend())
        let fake = FakePaletteHotkey(shouldFail: true)
        let module = CommandPaletteModule(
            settings: store,
            permissions: PermissionCenter(backend: PalettePermissionBackend()),
            commandSource: { [] },
            applicationCatalog: EmptyApplicationCatalog(),
            spotlight: EmptySpotlight(),
            workspace: PaletteWorkspace(),
            hotkeyFactory: { _, _ in fake }
        )
        try await module.start()
        guard case .degraded = module.state else { return XCTFail("Expected degraded hotkey state") }
        await module.stop()
    }

    @MainActor
    func testClearingProviderFailureDoesNotHideHotkeyFailure() async throws {
        let store = SettingsStore(backend: InMemorySettingsBackend())
        let fake = FakePaletteHotkey(shouldFail: true)
        let module = CommandPaletteModule(
            settings: store,
            permissions: PermissionCenter(backend: PalettePermissionBackend()),
            commandSource: { [] },
            applicationCatalog: EmptyApplicationCatalog(),
            spotlight: EmptySpotlight(),
            workspace: PaletteWorkspace(),
            hotkeyFactory: { _, _ in fake }
        )
        try await module.start()
        try await Task.sleep(for: .milliseconds(50))
        module.setProvider(.applications, enabled: false)
        try await Task.sleep(for: .milliseconds(20))

        guard case .degraded(let reason) = module.state else { return XCTFail("Expected degraded state") }
        XCTAssertTrue(reason.contains("unavailable"))
        await module.stop()
    }
}

private final class CommandExecutionFlag: @unchecked Sendable { var value = false }

private final class DummyModule: DropThingsModule {
    let id = ModuleID.fake
    let name = "Dummy"
    let summary = "Dummy"
    let requiredPermissions: [SystemPermission] = []
    @Published var state: ModuleState = .off
    func start() async throws {}
    func stop() async {}
    func makeSettingsView() -> AnyView { AnyView(EmptyView()) }
}

@MainActor
private final class FakePaletteHotkey: CommandPaletteHotkeyRegistration {
    private let shouldFail: Bool
    var registerCount = 0
    var unregisterCount = 0

    init(shouldFail: Bool = false) { self.shouldFail = shouldFail }
    func register() throws {
        registerCount += 1
        if shouldFail { throw GlobalHotkey.RegistrationError.registerFailed(-1) }
    }
    func unregister() { unregisterCount += 1 }
}

private actor EmptyApplicationCatalog: ApplicationCataloging {
    func applications(in additionalLocations: [URL]) async -> [ApplicationRecord] { [] }
    func invalidate() async {}
}

@MainActor
private final class EmptySpotlight: SpotlightFileSearching, @unchecked Sendable {
    func search(query: String, includeContents: Bool, includeHidden: Bool, excludedPaths: [String], maximumResults: Int) async throws -> [SpotlightFileRecord] { [] }
}

@MainActor
private final class PalettePermissionBackend: PermissionBackend, @unchecked Sendable {
    func currentState(for permission: SystemPermission) -> SystemPermissionState { .granted }
    func openSystemSettings(for permission: SystemPermission) -> Bool { true }
}
