import XCTest
@testable import DropThingsModules
import DropThingsCore

@MainActor
final class ShelfCollectionTests: XCTestCase {
    private let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeModule(
        items: [FileShelfItem] = [],
        persistence: ShelfPersistence? = nil
    ) -> FileShelfModule {
        let store = SettingsStore(backend: InMemorySettingsBackend())
        let module: FileShelfModule
        if let persistence {
            module = FileShelfModule(settings: store, persistence: persistence)
        } else {
            module = FileShelfModule(settings: store)
        }
        module.setItemsForTesting(items)
        return module
    }

    private func makePersistence() -> ShelfPersistence {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("dropthings-shelf-test-\(UUID().uuidString)", isDirectory: true)
        return ShelfPersistence(directory: dir)
    }

    func testStartsWithOneDefaultCollection() {
        let module = makeModule()
        XCTAssertEqual(module.collections.count, 1)
        XCTAssertEqual(module.collections.first?.name, ShelfCollection.defaultName)
        XCTAssertEqual(module.activeCollectionID, module.collections.first?.id)
    }

    func testAddCollectionMakesItActive() {
        let module = makeModule()
        module.addCollection()
        XCTAssertEqual(module.collections.count, 2)
        XCTAssertEqual(module.collections.last?.name, "Shelf 2")
        XCTAssertEqual(module.activeCollectionID, module.collections.last?.id)
    }

    func testRenameActiveCollection() {
        let module = makeModule()
        module.beginRename(id: module.activeCollectionID!)
        module.commitRename("Trabajo")
        XCTAssertEqual(module.activeCollection?.name, "Trabajo")
    }

    func testEmptyRenameIsCancelled() {
        let module = makeModule()
        let original = module.activeCollection?.name
        module.beginRename(id: module.activeCollectionID!)
        module.commitRename("   ")
        XCTAssertEqual(module.activeCollection?.name, original)
    }

    func testRenamePersistsToDisk() throws {
        let persistence = makePersistence()
        let module = makeModule(persistence: persistence)
        module.beginRename(id: module.activeCollectionID!)
        module.commitRename("Trabajo")

        let loaded = persistence.loadCollections()
        XCTAssertEqual(loaded.first?.name, "Trabajo")
    }

    func testRenamePersistsAcrossStopStart() async throws {
        let persistence = makePersistence()
        let module = makeModule(persistence: persistence)
        module.beginRename(id: module.activeCollectionID!)
        module.commitRename("Trabajo")
        await module.stop()

        let newModule = FileShelfModule(
            settings: SettingsStore(backend: InMemorySettingsBackend()),
            persistence: persistence
        )
        try await newModule.start()
        XCTAssertEqual(newModule.activeCollection?.name, "Trabajo")
        await newModule.stop()
    }

    func testRemoveLastCollectionClearsInsteadOfDeleting() {
        let module = makeModule(items: [FileShelfItem(kind: .text("a"), addedAt: fixedDate)])
        XCTAssertEqual(module.items.count, 1)
        module.removeActiveCollection()
        // Still one collection, now empty.
        XCTAssertEqual(module.collections.count, 1)
        XCTAssertEqual(module.items.count, 0)
    }

    func testRemoveNonLastDeletesAndSwitches() {
        let module = makeModule()
        module.addCollection() // "Shelf 2" active
        // Go back to first, then remove the second by selecting + removing.
        let first = module.collections[0].id
        module.selectCollection(id: module.collections[1].id)
        module.removeActiveCollection()
        XCTAssertEqual(module.collections.count, 1)
        XCTAssertEqual(module.activeCollectionID, first)
    }

    func testSelectCollectionClearsSelection() {
        let module = makeModule(items: [
            FileShelfItem(kind: .text("a"), addedAt: fixedDate),
            FileShelfItem(kind: .text("b"), addedAt: fixedDate)
        ])
        module.handleSelect(id: "text\u{1F}:a", command: false, shift: false)
        XCTAssertEqual(module.selectedItemIDs.count, 1)
        module.addCollection()
        // Selecting a new tab clears selection.
        XCTAssertTrue(module.selectedItemIDs.isEmpty)
    }

    func testItemsReflectsActiveCollection() {
        let module = makeModule(items: [FileShelfItem(kind: .text("a"), addedAt: fixedDate)])
        module.addCollection()
        XCTAssertEqual(module.items.count, 0) // new collection is empty
        module.selectCollection(id: module.collections[0].id)
        XCTAssertEqual(module.items.count, 1) // back to the first
    }

    func testIngestLandsInActiveCollection() {
        let module = makeModule()
        module.addCollection() // active = second (empty)
        // Seed the active collection via the testing hook, which routes
        // through ensureDefaultCollection + mutateActiveItems.
        let item = FileShelfItem(kind: .text("in-active"), addedAt: fixedDate)
        module.setItemsForTesting([item])
        XCTAssertEqual(module.items.map(\.id), ["text\u{1F}:in-active"])
        // The first collection stays untouched.
        XCTAssertEqual(module.collections[0].items.count, 0)
        XCTAssertEqual(module.collections[1].items.count, 1)
    }
}
