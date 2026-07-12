import XCTest
import SwiftUI
@testable import DropThingsModules
@testable import DropThingsCore
import DropThingsPlatform

final class CommandPaletteExecutionTests: XCTestCase {
    @MainActor
    func testCommandExecutesAction() {
        let executed = CommandExecutionFlag()
        let command = CommandDescriptor(id: "test", title: "Test") {
            executed.value = true
        }
        command.action()
        XCTAssertTrue(executed.value)
    }

    @MainActor
    func testModuleDefaultCommandsAreEmpty() {
        let module = DummyModule()
        XCTAssertTrue(module.commands.isEmpty)
    }

    @MainActor
    func testModuleCanExposeCommands() {
        let module = CommandfulModule()
        XCTAssertEqual(module.commands.count, 1)
        XCTAssertEqual(module.commands.first?.title, "Do Work")
    }

    @MainActor
    func testDropThingsModuleDefaultCommandsAreEmpty() {
        let module = DummyModule()
        XCTAssertTrue(module.commands.isEmpty)
    }

    @MainActor
    func testRealModuleCommandIDsAreUniqueAndUseful() {
        let store = SettingsStore(backend: InMemorySettingsBackend())
        let permissions = PermissionCenter(backend: CommandPermissionBackend())
        let modules: [any DropThingsModule] = [
            FileShelfModule(settings: store),
            ClipboardHistoryModule(settings: store, permissions: permissions),
            MenuBarCleanerModule(settings: store, permissions: permissions),
            KeepAwakeModule(settings: store),
            ColorPickerModule(settings: store, permissions: permissions),
            ScrollControlModule(settings: store, permissions: permissions),
            ScreenshotRegionModule(settings: store, permissions: permissions),
            WindowSnapModule(settings: store, permissions: permissions),
            TextToolsModule(settings: store)
        ]
        let commands = modules.flatMap(\.commands)
        let ids = commands.map(\.id)

        XCTAssertGreaterThanOrEqual(commands.count, 18)
        XCTAssertEqual(Set(ids).count, ids.count)
        XCTAssertTrue(ids.contains("file-shelf.toggle"))
        XCTAssertTrue(ids.contains("clipboard-history.open"))
        XCTAssertTrue(ids.contains("window-snap.maximize"))
    }
}

private final class CommandExecutionFlag: @unchecked Sendable {
    var value = false
}

@MainActor
private final class CommandPermissionBackend: PermissionBackend, @unchecked Sendable {
    func currentState(for permission: SystemPermission) -> SystemPermissionState { .granted }
    func openSystemSettings(for permission: SystemPermission) -> Bool { true }
}

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

private final class CommandfulModule: DropThingsModule {
    let id = ModuleID.fake
    let name = "Commandful"
    let summary = "Commandful"
    let requiredPermissions: [SystemPermission] = []
    @Published var state: ModuleState = .off

    var commands: [CommandDescriptor] {
        [CommandDescriptor(id: "do-work", title: "Do Work", action: {})]
    }

    func start() async throws {}
    func stop() async {}
    func makeSettingsView() -> AnyView { AnyView(EmptyView()) }
}
