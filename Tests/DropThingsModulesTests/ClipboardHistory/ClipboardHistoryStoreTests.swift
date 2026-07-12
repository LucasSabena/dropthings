import Foundation
import XCTest
@testable import DropThingsModules

final class ClipboardHistoryStoreTests: XCTestCase {
    private var directory: URL!
    private var store: ClipboardHistoryStore!

    override func setUp() {
        super.setUp()
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("DropThings-ClipboardTests-\(UUID().uuidString)", isDirectory: true)
        store = ClipboardHistoryStore(directoryURL: directory)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: directory)
        store = nil
        directory = nil
        super.tearDown()
    }

    func testTextHistoryRoundTrips() async throws {
        let items = [
            ClipboardItem(type: .plainText, content: "persistent text"),
            ClipboardItem(type: .color, content: "#112233")
        ]

        let result = try await store.save(items, maxStorageBytes: 1_024_000)
        let restored = try await store.load()

        XCTAssertEqual(restored, items)
        XCTAssertEqual(result.storedItemCount, 2)
        XCTAssertGreaterThan(result.storageBytes, 0)
    }

    func testRawImageRoundTripsAsPersistentAsset() async throws {
        let item = ClipboardItem(type: .image, content: "Image", imageData: Self.onePixelPNG)

        let result = try await store.save([item], maxStorageBytes: 1_024_000)
        let restored = try await store.load()

        XCTAssertEqual(result.omittedImageCount, 0)
        XCTAssertEqual(restored.count, 1)
        XCTAssertEqual(restored.first?.id, item.id)
        XCTAssertNotNil(restored.first?.imageData)
    }

    func testImageOverStorageLimitIsNotPersistedAsBrokenPlaceholder() async throws {
        let item = ClipboardItem(type: .image, content: "Image", imageData: Self.onePixelPNG)

        let result = try await store.save([item], maxStorageBytes: 0)
        let restored = try await store.load()

        XCTAssertEqual(result.storedItemCount, 0)
        XCTAssertEqual(result.omittedImageCount, 1)
        XCTAssertTrue(restored.isEmpty)
    }

    private static let onePixelPNG = Data(base64Encoded:
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="
    )!
}
