import XCTest
@testable import DropThingsModules

final class FileShelfModelTests: XCTestCase {
    private let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)

    // MARK: - fileTypeLabel

    func testFileTypeLabelForCommonImageFormats() {
        let cases: [(String, String)] = [
            ("photo.png", "PNG"),
            ("photo.jpg", "JPG"),
            ("photo.jpeg", "JPG"),   // alias collapse for the label
            ("art.webp", "WEBP"),
            ("art.avif", "AVIF"),
            ("logo.svg", "SVG")
        ]
        for (filename, expected) in cases {
            let item = FileShelfItem(kind: .file(URL(fileURLWithPath: "/tmp/\(filename)")), addedAt: fixedDate)
            XCTAssertEqual(item.fileTypeLabel, expected, "label for \(filename)")
        }
    }

    func testFileExtensionIsRawLowercased() {
        // The label collapses jpeg→JPG, but fileExtension reports the raw
        // extension on disk so file operations stay correct.
        let jpg = FileShelfItem(kind: .file(URL(fileURLWithPath: "/tmp/a.jpg")), addedAt: fixedDate)
        XCTAssertEqual(jpg.fileExtension, "jpg")
        let jpeg = FileShelfItem(kind: .file(URL(fileURLWithPath: "/tmp/a.jpeg")), addedAt: fixedDate)
        XCTAssertEqual(jpeg.fileExtension, "jpeg")
        XCTAssertEqual(jpeg.fileTypeLabel, "JPG")
    }

    func testFileTypeLabelForDocuments() {
        let cases: [(String, String)] = [
            ("invoice.pdf", "PDF"),
            ("notes.txt", "TXT"),
            ("readme.md", "MD"),
            ("data.json", "JSON")
        ]
        for (filename, expected) in cases {
            let item = FileShelfItem(kind: .file(URL(fileURLWithPath: "/tmp/\(filename)")), addedAt: fixedDate)
            XCTAssertEqual(item.fileTypeLabel, expected, "for \(filename)")
        }
    }

    func testFileTypeLabelForFolderAndText() {
        let folder = FileShelfItem(kind: .folder(URL(fileURLWithPath: "/tmp/dir")), addedAt: fixedDate)
        XCTAssertEqual(folder.fileTypeLabel, "FOLDER")
        XCTAssertNil(folder.fileExtension)

        let text = FileShelfItem(kind: .text("hi"), addedAt: fixedDate)
        XCTAssertEqual(text.fileTypeLabel, "TEXT")
        XCTAssertNil(text.fileExtension)
    }

    func testFileTypeLabelForNoExtension() {
        let item = FileShelfItem(kind: .file(URL(fileURLWithPath: "/tmp/MANIFEST")), addedAt: fixedDate)
        XCTAssertEqual(item.fileTypeLabel, "FILE")
        XCTAssertNil(item.fileExtension)
    }

    func testTypeLabelAliasCollapseDirectly() {
        XCTAssertEqual(FileShelfItemKind.typeLabel(forExtension: "jpeg"), "JPG")
        XCTAssertEqual(FileShelfItemKind.typeLabel(forExtension: "JPEG"), "JPG")
        XCTAssertEqual(FileShelfItemKind.typeLabel(forExtension: "PNG"), "PNG")
        XCTAssertEqual(FileShelfItemKind.typeLabel(forExtension: ""), "FILE")
    }

    // MARK: - ShelfCollection

    func testCollectionCodableRoundTrip() throws {
        let items = [
            FileShelfItem(kind: .file(URL(fileURLWithPath: "/tmp/a.png")), addedAt: fixedDate),
            FileShelfItem(kind: .text("hello"), addedAt: fixedDate, isPinned: true)
        ]
        let original = ShelfCollection(id: "abc", name: "Trabajo", items: items, createdAt: fixedDate)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ShelfCollection.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testUniqueDefaultName() {
        XCTAssertEqual(ShelfCollection.uniqueDefaultName(existingNames: []), "Shelf")
        XCTAssertEqual(ShelfCollection.uniqueDefaultName(existingNames: ["Shelf"]), "Shelf 2")
        XCTAssertEqual(ShelfCollection.uniqueDefaultName(existingNames: ["Shelf", "Shelf 2"]), "Shelf 3")
        // Gaps are not filled — next free index is used.
        XCTAssertEqual(ShelfCollection.uniqueDefaultName(existingNames: ["Shelf", "Shelf 3"]), "Shelf 2")
    }

    func testNewDefaultPicksFreshName() {
        let c1 = ShelfCollection.newDefault(existingNames: [])
        XCTAssertEqual(c1.name, "Shelf")
        let c2 = ShelfCollection.newDefault(existingNames: [c1.name])
        XCTAssertEqual(c2.name, "Shelf 2")
    }
}
