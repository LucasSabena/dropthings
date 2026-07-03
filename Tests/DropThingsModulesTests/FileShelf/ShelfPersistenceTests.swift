import XCTest
@testable import DropThingsModules

final class ShelfPersistenceTests: XCTestCase {
    private let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)

    /// Each test gets a fresh isolated temp dir so nothing leaks between
    /// runs or into the user's real app support.
    private func makePersistence() -> ShelfPersistence {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("dropthings-shelf-test-\(UUID().uuidString)", isDirectory: true)
        return ShelfPersistence(directory: dir)
    }

    func testSaveAndLoadCollectionsRoundTrip() throws {
        let persistence = makePersistence()
        let items = [
            FileShelfItem(kind: .file(URL(fileURLWithPath: "/tmp/a.png")), addedAt: fixedDate, isPinned: true),
            FileShelfItem(kind: .text("hi"), addedAt: fixedDate, isPinned: true)
        ]
        let collection = ShelfCollection(name: "Trabajo", items: items, createdAt: fixedDate)
        try persistence.saveCollections([collection])

        let loaded = persistence.loadCollections()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.name, "Trabajo")
        XCTAssertEqual(loaded.first?.items.map(\.id), items.map(\.id))
    }

    func testLoadReturnsEmptyWhenNothingSaved() {
        let persistence = makePersistence()
        XCTAssertTrue(persistence.loadCollections().isEmpty)
    }

    func testLegacyFlatItemsMigrateIntoDefaultCollection() throws {
        let persistence = makePersistence()
        // Hand-write the v1 layout ({ "items": [...] }) into the legacy
        // path. The new path must not exist yet.
        let legacyItem = FileShelfItem(
            kind: .text("legacy"), addedAt: fixedDate, isPinned: true
        )
        let blob = try JSONEncoder().encode(["items": [legacyItem]])
        try writeLegacyBlob(blob, persistence: persistence)

        let loaded = persistence.loadCollections()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.name, ShelfCollection.defaultName)
        XCTAssertEqual(loaded.first?.items.map(\.id), [legacyItem.id])
    }

    func testNewLayoutTakesPrecedenceOverLegacy() throws {
        let persistence = makePersistence()
        // Write a legacy blob AND a new file. The new layout wins.
        let legacy = FileShelfItem(kind: .text("legacy"), addedAt: fixedDate, isPinned: true)
        let legacyBlob = try JSONEncoder().encode(["items": [legacy]])
        try writeLegacyBlob(legacyBlob, persistence: persistence)

        let fresh = ShelfCollection(name: "New", items: [
            FileShelfItem(kind: .text("fresh"), addedAt: fixedDate, isPinned: true)
        ])
        try persistence.saveCollections([fresh])

        let loaded = persistence.loadCollections()
        XCTAssertEqual(loaded.first?.name, "New")
        XCTAssertEqual(loaded.first?.items.map(\.id), ["text\u{1F}:fresh"])
    }

    /// Reaches the private legacy path via the persistence store URL's
    /// sibling filename. We can't access the private field, but the legacy
    /// path is a well-known filename next to the new one.
    private func writeLegacyBlob(_ data: Data, persistence: ShelfPersistence) throws {
        // The legacy file sits in the same directory as the new file.
        let dir = persistence.storageURL.deletingLastPathComponent()
        try data.write(to: dir.appendingPathComponent("file-shelf-pinned.json"), options: .atomic)
    }
}
