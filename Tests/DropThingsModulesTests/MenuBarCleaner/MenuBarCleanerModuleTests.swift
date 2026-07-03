import XCTest
@testable import DropThingsModules

final class MenuBarCleanerModuleTests: XCTestCase {
    // MARK: - Divider length math

    func testCollapsedDividerLengthUsesScreenWidthPlusExpandedLengthAndMargin() {
        let divider = MenuBarCleanerDivider(
            name: "Test",
            expandedLength: 18,
            collapsedLength: 500,
            isOverflow: true
        )
        let length = MenuBarCleanerModule.collapsedDividerLength(
            for: divider,
            screenVisibleWidth: 1728
        )
        XCTAssertEqual(length, 1728 + 18 + 40)
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
            screenVisibleWidth: 800
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
            screenVisibleWidth: 300
        )
        XCTAssertEqual(length, 500)
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
            screenVisibleWidth: 5120
        )
        XCTAssertEqual(length, 5120 + 18 + 40)
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
