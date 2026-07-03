import XCTest
@testable import DropThingsModules
import DropThingsCore

@MainActor
final class ShelfSelectionTests: XCTestCase {
    private let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)

    /// Five ordered items: [a, b, c, d, e] by addedAt, ids "text\u{1F}:a"…
    private var orderedIds: [String] {
        ["text\u{1F}:a", "text\u{1F}:b", "text\u{1F}:c", "text\u{1F}:d", "text\u{1F}:e"]
    }

    private func makeItems() -> [FileShelfItem] {
        ["a", "b", "c", "d", "e"].map { FileShelfItem(kind: .text($0), addedAt: fixedDate) }
    }

    // MARK: - range(from:to:in:) — pure

    func testRangeSelectsForward() {
        let r = FileShelfModule.range(from: "text\u{1F}:a", to: "text\u{1F}:c", in: orderedIds)
        XCTAssertEqual(r, ["text\u{1F}:a", "text\u{1F}:b", "text\u{1F}:c"])
    }

    func testRangeSelectsBackward() {
        let r = FileShelfModule.range(from: "text\u{1F}:c", to: "text\u{1F}:a", in: orderedIds)
        XCTAssertEqual(r, ["text\u{1F}:a", "text\u{1F}:b", "text\u{1F}:c"])
    }

    func testRangeSingleElement() {
        let r = FileShelfModule.range(from: "text\u{1F}:c", to: "text\u{1F}:c", in: orderedIds)
        XCTAssertEqual(r, ["text\u{1F}:c"])
    }

    func testRangeUnknownTargetFallsBackToJustTarget() {
        let r = FileShelfModule.range(from: "text\u{1F}:a", to: "text\u{1F}:zzz", in: orderedIds)
        XCTAssertEqual(r, ["text\u{1F}:zzz"])
    }

    // MARK: - Display order honors pinned-first — pure

    func testDisplayOrderPutsPinnedFirst() {
        var mixed = makeItems()
        mixed[2] = mixed[2].pinning(true)
        let sorted = ShelfDisplayOrder.sort(mixed).map(\.id)
        XCTAssertEqual(sorted.first, "text\u{1F}:c")
    }

    // MARK: - handleSelect / batch — exercised via a module seeded with items

    func testPlainCommandShiftSelectionAndBatchRemove() {
        let module = makeModule(with: makeItems())

        // Plain click → only c.
        module.handleSelect(id: "text\u{1F}:c", command: false, shift: false)
        XCTAssertEqual(module.selectedItemIDs, ["text\u{1F}:c"])

        // ⌘-click toggles a and e in.
        module.handleSelect(id: "text\u{1F}:a", command: true, shift: false)
        module.handleSelect(id: "text\u{1F}:e", command: true, shift: false)
        XCTAssertEqual(module.selectedItemIDs, ["text\u{1F}:a", "text\u{1F}:c", "text\u{1F}:e"])

        // Selected items come out in display order.
        XCTAssertEqual(module.selectedItems.map(\.id), ["text\u{1F}:a", "text\u{1F}:c", "text\u{1F}:e"])

        // Clear, then a ⇧-click range from a to c.
        module.clearSelection()
        XCTAssertTrue(module.selectedItemIDs.isEmpty)
        module.handleSelect(id: "text\u{1F}:a", command: false, shift: false)
        module.handleSelect(id: "text\u{1F}:c", command: false, shift: true)
        XCTAssertEqual(module.selectedItemIDs, ["text\u{1F}:a", "text\u{1F}:b", "text\u{1F}:c"])

        // Batch remove the range; b and c are gone, a and d,e survive.
        module.removeSelected()
        XCTAssertEqual(module.items.map(\.id), ["text\u{1F}:d", "text\u{1F}:e"])
        XCTAssertTrue(module.selectedItemIDs.isEmpty)
    }

    func testToggleOffDeselects() {
        let module = makeModule(with: makeItems())
        module.handleSelect(id: "text\u{1F}:a", command: true, shift: false)
        module.handleSelect(id: "text\u{1F}:c", command: true, shift: false)
        module.handleSelect(id: "text\u{1F}:a", command: true, shift: false)
        XCTAssertEqual(module.selectedItemIDs, ["text\u{1F}:c"])
    }

    // MARK: - helpers

    /// Builds a module with `items` seeded through the internal test hook.
    /// `@testable import` exposes `internal` members, so the hook does not
    /// leak into the public API. Reuses the shared `InMemorySettingsBackend`.
    private func makeModule(with items: [FileShelfItem]) -> FileShelfModule {
        let store = SettingsStore(backend: InMemorySettingsBackend())
        let module = FileShelfModule(settings: store)
        module.setItemsForTesting(items)
        return module
    }
}
