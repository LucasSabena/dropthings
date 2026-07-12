import XCTest
@testable import DropThingsModules
import DropThingsCore

@MainActor
final class MenuBarCleanerModuleTests: XCTestCase {
    func testOffModuleConfigurationDoesNotStartIt() {
        let store = SettingsStore(backend: InMemorySettingsBackend())
        let permissions = PermissionCenter(backend: MenuBarPermissionBackend())
        let module = MenuBarCleanerModule(settings: store, permissions: permissions)

        module.addDivider(name: "Visual")
        module.addProfile(name: "Collapsed", collapsed: true)
        module.setActiveProfile(module.settings.profiles.last?.id)

        XCTAssertEqual(module.state, .off)
        XCTAssertFalse(module.isCollapsed)
        XCTAssertEqual(module.settings.dividers.count, 2)
    }

    func testSafeResetWhileOffKeepsModuleOff() {
        let store = SettingsStore(backend: InMemorySettingsBackend())
        let permissions = PermissionCenter(backend: MenuBarPermissionBackend())
        let module = MenuBarCleanerModule(settings: store, permissions: permissions)
        module.addDivider(name: "Visual")

        module.safeReset()

        XCTAssertEqual(module.state, .off)
        XCTAssertEqual(module.settings.dividers, [.defaultMain])
    }

    // MARK: - Divider length math

    func testCollapsedDividerLengthUsesTwiceWidestScreenWidth() {
        let divider = MenuBarCleanerDivider(
            name: "Test",
            expandedLength: 18,
            collapsedLength: 500,
            isOverflow: true
        )
        let length = MenuBarCleanerModule.collapsedDividerLength(
            for: divider,
            widestScreenWidth: 1728
        )
        XCTAssertEqual(length, 1728 * 2)
    }

    func testCollapsedDividerLengthFallsBackToCollapsedLengthWhenComputedValueIsSmaller() {
        let divider = MenuBarCleanerDivider(
            name: "Test",
            expandedLength: 18,
            collapsedLength: 2500,
            isOverflow: true
        )
        let length = MenuBarCleanerModule.collapsedDividerLength(
            for: divider,
            widestScreenWidth: 800
        )
        XCTAssertEqual(length, 2500)
    }

    func testCollapsedDividerLengthHandlesNarrowScreen() {
        let divider = MenuBarCleanerDivider(
            name: "Test",
            expandedLength: 18,
            collapsedLength: 500,
            isOverflow: true
        )
        let length = MenuBarCleanerModule.collapsedDividerLength(
            for: divider,
            widestScreenWidth: 300
        )
        XCTAssertEqual(length, 600)
    }

    func testCollapsedDividerLengthHandlesWideScreen() {
        let divider = MenuBarCleanerDivider(
            name: "Test",
            expandedLength: 18,
            collapsedLength: 500,
            isOverflow: true
        )
        let length = MenuBarCleanerModule.collapsedDividerLength(
            for: divider,
            widestScreenWidth: 5120
        )
        XCTAssertEqual(length, 10_000)
    }

    // MARK: - Status message logic

    func testStatusMessageWhenControlsAreInstalling() {
        let message = MenuBarCleanerModule.statusMessage(
            dividerX: nil,
            toggleX: nil,
            isCollapsed: false
        )
        XCTAssertEqual(message, "DropThings controls are being installed in the menu bar.")
    }

    func testStatusMessageWhenOnlyDividerPositionIsUnknown() {
        let message = MenuBarCleanerModule.statusMessage(
            dividerX: nil,
            toggleX: 100,
            isCollapsed: false
        )
        XCTAssertEqual(message, "DropThings controls are being installed in the menu bar.")
    }

    func testStatusMessageWhenOnlyTogglePositionIsUnknown() {
        let message = MenuBarCleanerModule.statusMessage(
            dividerX: 100,
            toggleX: nil,
            isCollapsed: false
        )
        XCTAssertEqual(message, "DropThings controls are being installed in the menu bar.")
    }

    func testStatusMessageWhenChevronIsLeftOfDivider() {
        let message = MenuBarCleanerModule.statusMessage(
            dividerX: 200,
            toggleX: 100,
            isCollapsed: false
        )
        XCTAssertEqual(
            message,
            "The chevron is on the wrong side. Command-drag the DropThings chevron so it sits to the right of the divider."
        )
    }

    func testStatusMessageWhenChevronIsRightOfDividerAndCollapsed() {
        let message = MenuBarCleanerModule.statusMessage(
            dividerX: 100,
            toggleX: 200,
            isCollapsed: true
        )
        XCTAssertEqual(message, "Collapsed. Click the DropThings chevron to reveal the hidden side.")
    }

    func testStatusMessageWhenChevronIsRightOfDividerAndRevealed() {
        let message = MenuBarCleanerModule.statusMessage(
            dividerX: 100,
            toggleX: 200,
            isCollapsed: false
        )
        XCTAssertEqual(message, "Revealed. Icons placed left of the divider will collapse behind it.")
    }

    func testStatusMessageWhenChevronIsAlignedWithDivider() {
        let message = MenuBarCleanerModule.statusMessage(
            dividerX: 100,
            toggleX: 100,
            isCollapsed: false
        )
        XCTAssertEqual(message, "Revealed. Icons placed left of the divider will collapse behind it.")
    }
}

@MainActor
private final class MenuBarPermissionBackend: PermissionBackend, @unchecked Sendable {
    func currentState(for permission: SystemPermission) -> SystemPermissionState { .granted }
    func openSystemSettings(for permission: SystemPermission) -> Bool { true }
}
