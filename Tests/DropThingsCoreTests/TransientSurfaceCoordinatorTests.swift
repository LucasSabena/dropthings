import XCTest
@testable import DropThingsCore

@MainActor
final class TransientSurfaceCoordinatorTests: XCTestCase {
    func testPresentingOneSurfaceDismissesEveryOtherSurface() {
        let coordinator = TransientSurfaceCoordinator()
        var dismissed: [ModuleID] = []
        coordinator.register(.commandPalette) { dismissed.append(.commandPalette) }
        coordinator.register(.fileShelf) { dismissed.append(.fileShelf) }
        coordinator.register(.clipboardHistory) { dismissed.append(.clipboardHistory) }

        coordinator.prepareToPresent(.commandPalette)

        XCTAssertEqual(Set(dismissed), [.fileShelf, .clipboardHistory])
    }

    func testUnregisteredSurfaceIsNotDismissed() {
        let coordinator = TransientSurfaceCoordinator()
        var dismissCount = 0
        coordinator.register(.fileShelf) { dismissCount += 1 }
        coordinator.unregister(.fileShelf)

        coordinator.dismissAll()

        XCTAssertEqual(dismissCount, 0)
    }

    func testDismissAllIncludesTheCurrentlyPresentedSurface() {
        let coordinator = TransientSurfaceCoordinator()
        var dismissed: Set<ModuleID> = []
        coordinator.register(.commandPalette) { dismissed.insert(.commandPalette) }
        coordinator.register(.smartClipboard) { dismissed.insert(.smartClipboard) }

        coordinator.dismissAll()

        XCTAssertEqual(dismissed, [.commandPalette, .smartClipboard])
    }
}
