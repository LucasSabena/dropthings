import XCTest
@testable import DropThingsModules
import DropThingsCore

/// Verifies that history trimming respects pinned/favorite items and never
/// loops when every overflow item is protected.
@MainActor
final class ClipboardHistoryTrimTests: XCTestCase {
    private var backend: InMemorySettingsBackend!
    private var store: SettingsStore!
    private var module: ClipboardHistoryModule!

    override func setUp() {
        super.setUp()
        backend = InMemorySettingsBackend()
        store = SettingsStore(backend: backend)
        module = ClipboardHistoryModule(settings: store, permissions: PermissionCenter())
    }

    func testTrimDropsOldestUnpinnedUntilUnderMax() {
        // maxHistory is clamped to a minimum of 10, so use a value above the min.
        module.setMaxHistory(10)
        let items = (1...11).map { ClipboardItem(type: .plainText, content: String($0), isPinned: false) }
        module.items = items

        module.trimToMax()

        XCTAssertEqual(module.items.count, 10)
        XCTAssertEqual(module.items.map(\.content), (1...10).map(String.init))
    }

    func testTrimPreservesPinnedItems() {
        module.setMaxHistory(10)
        let items = [
            ClipboardItem(type: .plainText, content: "pinned-a", isPinned: true)
        ] + (1...10).map {
            ClipboardItem(type: .plainText, content: "unpinned-\($0)", isPinned: false)
        }
        module.items = items

        module.trimToMax()

        XCTAssertEqual(module.items.count, 10)
        XCTAssertTrue(module.items.contains { $0.content == "pinned-a" })
        XCTAssertEqual(module.items.filter { !$0.isPinned }.count, 9)
    }

    func testTrimStopsWhenOnlyPinnedOrFavoriteRemain() {
        module.setMaxHistory(10)
        let items = [
            ClipboardItem(type: .plainText, content: "pinned", isPinned: true)
        ] + (1...10).map {
            ClipboardItem(type: .plainText, content: "favorite-\($0)", isPinned: false, isFavorite: true)
        }
        module.items = items

        module.trimToMax()

        XCTAssertEqual(module.items.count, 11)
        XCTAssertTrue(module.items.allSatisfy { $0.isPinned || $0.isFavorite })
    }

    func testTrimDoesNotLoopWhenAllOverflowItemsArePinned() {
        module.setMaxHistory(10)
        let items = (1...11).map { ClipboardItem(type: .plainText, content: String($0), isPinned: true) }
        module.items = items

        module.trimToMax()

        XCTAssertEqual(module.items.count, 11)
        XCTAssertEqual(module.items.filter(\.isPinned).count, 11)
    }

    func testTrimDoesNotLoopWhenAllOverflowItemsAreFavorite() {
        module.setMaxHistory(10)
        let items = (1...11).map { ClipboardItem(type: .plainText, content: "fav-\($0)", isPinned: false, isFavorite: true) }
        module.items = items

        module.trimToMax()

        XCTAssertEqual(module.items.count, 11)
        XCTAssertTrue(module.items.allSatisfy(\.isFavorite))
    }

    func testTrimIsNoOpWhenCountIsAtOrBelowMax() {
        module.setMaxHistory(10)
        let items = [
            ClipboardItem(type: .plainText, content: "a"),
            ClipboardItem(type: .plainText, content: "b"),
        ]
        module.items = items

        module.trimToMax()

        XCTAssertEqual(module.items.count, 2)
        XCTAssertEqual(module.items.map(\.content), ["a", "b"])
    }

    func testRetentionExpiresOnlyUnpinnedItems() {
        let now = Date()
        module.setRetentionDays(7)
        module.items = [
            ClipboardItem(timestamp: now.addingTimeInterval(-8 * 86_400), type: .plainText, content: "expired"),
            ClipboardItem(timestamp: now.addingTimeInterval(-8 * 86_400), type: .plainText, content: "pinned", isPinned: true),
            ClipboardItem(timestamp: now.addingTimeInterval(-6 * 86_400), type: .plainText, content: "recent")
        ]

        module.trimToMax(now: now)

        XCTAssertEqual(Set(module.items.map(\.content)), ["pinned", "recent"])
    }

    func testClipboardDoesNotRequireAccessibilityAndCopiesByDefault() {
        XCTAssertTrue(module.requiredPermissions.isEmpty)
        XCTAssertFalse(module.settings.pasteOnEnter)
    }

    func testPinnedItemsAreRestoredWhenModuleIsCreated() {
        let pinned = ClipboardItem(
            type: .plainText,
            content: "persistent",
            isPinned: true
        )
        store.saveClipboardHistorySettings(
            ClipboardHistorySettings(pinnedItems: [pinned])
        )

        let restored = ClipboardHistoryModule(
            settings: store,
            permissions: PermissionCenter()
        )

        XCTAssertEqual(restored.items, [pinned])
    }
}
