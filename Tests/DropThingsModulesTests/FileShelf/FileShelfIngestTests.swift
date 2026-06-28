import XCTest
@testable import DropThingsModules

final class FileShelfIngestTests: XCTestCase {
    private let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)

    func testEmptyKindsLeavesItemsUntouched() {
        let items = [FileShelfItem(kind: .text("a"), addedAt: fixedDate)]
        let result = FileShelfModule.merged(items, with: [], maxItems: 10)
        XCTAssertEqual(result.count, 1)
    }

    func testDuplicatesAreDeduped() {
        let items = [FileShelfItem(kind: .text("a"), addedAt: fixedDate)]
        let kinds: [FileShelfItemKind] = [.text("a"), .text("a")]
        let result = FileShelfModule.merged(items, with: kinds, maxItems: 10)
        XCTAssertEqual(result.count, 1)
    }

    func testNewItemsAppendToEnd() {
        let items = [FileShelfItem(kind: .text("a"), addedAt: fixedDate)]
        let kinds: [FileShelfItemKind] = [.text("b"), .text("c")]
        let result = FileShelfModule.merged(items, with: kinds, maxItems: 10)
        XCTAssertEqual(result.map(\.id), ["text\u{1F}:a", "text\u{1F}:b", "text\u{1F}:c"])
    }

    func testTrimRemovesUnpinnedFromEndFirst() {
        // Three items, last one pinned, cap at 2. Trim must remove the
        // last *unpinned* one (the middle), keeping the pinned tail.
        let pinned = FileShelfItem(kind: .text("pinned"), addedAt: fixedDate, isPinned: true)
        let unpinned1 = FileShelfItem(kind: .text("a"), addedAt: fixedDate)
        let unpinned2 = FileShelfItem(kind: .text("b"), addedAt: fixedDate)
        let items = [unpinned1, unpinned2, pinned]
        let result = FileShelfModule.trimmed(items, maxItems: 2)
        XCTAssertEqual(result.map(\.id), ["text\u{1F}:a", "text\u{1F}:pinned"])
    }

    func testTrimRemovesOldestWhenEverythingPinned() {
        let a = FileShelfItem(kind: .text("a"), addedAt: fixedDate, isPinned: true)
        let b = FileShelfItem(kind: .text("b"), addedAt: fixedDate.addingTimeInterval(1), isPinned: true)
        let c = FileShelfItem(kind: .text("c"), addedAt: fixedDate.addingTimeInterval(2), isPinned: true)
        let result = FileShelfModule.trimmed([a, b, c], maxItems: 2)
        XCTAssertEqual(result.map(\.id), ["text\u{1F}:b", "text\u{1F}:c"])
    }

    func testTrimDoesNothingWhenUnderCap() {
        let items = [FileShelfItem(kind: .text("a"), addedAt: fixedDate)]
        XCTAssertEqual(FileShelfModule.trimmed(items, maxItems: 5).count, 1)
    }

    func testFloodOfDropsKeepsPinned() {
        // Pinned item at position 0, drop 100 unpinned items, cap at 5.
        // The pinned one must survive.
        let pinned = FileShelfItem(kind: .text("pinned"), addedAt: fixedDate, isPinned: true)
        let kinds: [FileShelfItemKind] = (0..<100).map { .text("item\($0)") }
        let result = FileShelfModule.merged([pinned], with: kinds, maxItems: 5)
        XCTAssertEqual(result.count, 5)
        XCTAssertTrue(result.contains(where: { $0.id == "text\u{1F}:pinned" }))
    }
}