import XCTest
@testable import DropThingsModules

final class FileShelfItemTests: XCTestCase {
    private let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)

    func testFileIdentityIsDeterministic() {
        let url = URL(fileURLWithPath: "/tmp/example.txt")
        let a = FileShelfItem(kind: .file(url), addedAt: fixedDate)
        let b = FileShelfItem(kind: .file(url), addedAt: fixedDate)
        XCTAssertEqual(a.id, b.id)
        XCTAssertEqual(a, b)
    }

    func testDifferentPathsProduceDifferentIds() {
        let a = FileShelfItem(kind: .file(URL(fileURLWithPath: "/tmp/a.txt")), addedAt: fixedDate)
        let b = FileShelfItem(kind: .file(URL(fileURLWithPath: "/tmp/b.txt")), addedAt: fixedDate)
        XCTAssertNotEqual(a.id, b.id)
    }

    func testTextIdentityIsContentBased() {
        let a = FileShelfItem(kind: .text("hello"), addedAt: fixedDate)
        let b = FileShelfItem(kind: .text("hello"), addedAt: fixedDate)
        XCTAssertEqual(a.id, b.id)
        XCTAssertEqual(a, b)
    }

    func testFileAndFolderDiffer() {
        let url = URL(fileURLWithPath: "/tmp/example")
        let a = FileShelfItem(kind: .file(url), addedAt: fixedDate)
        let b = FileShelfItem(kind: .folder(url), addedAt: fixedDate)
        XCTAssertNotEqual(a.id, b.id)
    }

    func testDisplayNameTruncatesLongText() {
        let long = String(repeating: "a", count: 200)
        let item = FileShelfItem(kind: .text(long), addedAt: fixedDate)
        XCTAssertLessThanOrEqual(item.displayName.count, 60)
    }

    func testEmptyTextFallsBackToPlaceholder() {
        let item = FileShelfItem(kind: .text("   \n  "), addedAt: fixedDate)
        XCTAssertEqual(item.displayName, "Empty text")
    }

    func testFileDisplayNameIsLastPathComponent() {
        let url = URL(fileURLWithPath: "/Users/me/notes.md")
        let item = FileShelfItem(kind: .file(url), addedAt: fixedDate)
        XCTAssertEqual(item.displayName, "notes.md")
        XCTAssertEqual(item.displayPath, "/Users/me/notes.md")
    }

    func testPinningFlipsFlag() {
        let item = FileShelfItem(kind: .text("hello"))
        XCTAssertFalse(item.isPinned)
        XCTAssertTrue(item.pinning(true).isPinned)
        XCTAssertFalse(item.pinning(true).pinning(false).isPinned)
    }

    func testCodableRoundTrip() throws {
        let original = FileShelfItem(
            kind: .file(URL(fileURLWithPath: "/tmp/x.txt")),
            addedAt: Date(timeIntervalSince1970: 1_700_000_000),
            isPinned: true
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(FileShelfItem.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testCodableRoundTripForFolderAndText() throws {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let cases: [FileShelfItem] = [
            FileShelfItem(kind: .folder(URL(fileURLWithPath: "/tmp/dir")), addedAt: date),
            FileShelfItem(kind: .text("multi\nline\ntext"), addedAt: date)
        ]
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        for original in cases {
            let data = try encoder.encode(original)
            let decoded = try decoder.decode(FileShelfItem.self, from: data)
            XCTAssertEqual(decoded, original)
        }
    }
}
