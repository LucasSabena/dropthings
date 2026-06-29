import XCTest
import SwiftUI
@testable import DropThingsModules
@testable import DropThingsCore

final class CommandPaletteExecutionTests: XCTestCase {
    @MainActor
    func testCommandExecutesAction() {
        var executed = false
        let command = CommandDescriptor(id: "test", title: "Test") {
            executed = true
        }
        command.action()
        XCTAssertTrue(executed)
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
}

private final class DummyModule: DropThingsModule {
    let id = ModuleID.fake
    let name = "Dummy"
    let summary = "Dummy"
    let requiredPermissions: [SystemPermission] = []
    var state: ModuleState = .off

    func start() async throws {}
    func stop() async {}
    func makeSettingsView() -> AnyView { AnyView(EmptyView()) }
}

private final class CommandfulModule: DropThingsModule {
    let id = ModuleID.fake
    let name = "Commandful"
    let summary = "Commandful"
    let requiredPermissions: [SystemPermission] = []
    var state: ModuleState = .off

    var commands: [CommandDescriptor] {
        [CommandDescriptor(id: "do-work", title: "Do Work", action: {})]
    }

    func start() async throws {}
    func stop() async {}
    func makeSettingsView() -> AnyView { AnyView(EmptyView()) }
}
