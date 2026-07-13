import XCTest
@testable import DropThingsModules

@MainActor
final class MarkdownDocumentTests: XCTestCase {
    private func temporaryURL(extension ext: String = "md") -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("markdown-document-\(UUID().uuidString).\(ext)")
    }

    func testSaveWritesLatestTextAndClearsDirtyState() throws {
        let url = temporaryURL()
        try "old".write(to: url, atomically: true, encoding: .utf8)
        let document = MarkdownDocument()
        XCTAssertTrue(document.load(from: url))

        document.text = "# Latest\n\nSaved immediately."
        XCTAssertTrue(document.isDirty)
        XCTAssertTrue(document.save())

        XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), document.text)
        XCTAssertFalse(document.isDirty)
        XCTAssertNil(document.loadError)
    }

    func testSaveAsAdoptsDestination() throws {
        let url = temporaryURL()
        let document = MarkdownDocument(text: "new file")

        XCTAssertTrue(document.save(to: url))

        XCTAssertEqual(document.url, url)
        XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), "new file")
        XCTAssertFalse(document.isDirty)
    }

    func testUntitledTextStartsDirtyAndDiscardClearsIt() {
        let document = MarkdownDocument(text: "unsaved")

        XCTAssertTrue(document.isDirty)
        document.discardChanges()

        XCTAssertEqual(document.text, "")
        XCTAssertFalse(document.isDirty)
    }

    func testDiscardReloadsSavedFile() throws {
        let url = temporaryURL()
        try "saved".write(to: url, atomically: true, encoding: .utf8)
        let document = MarkdownDocument()
        document.load(from: url)
        document.text = "temporary edit"

        document.discardChanges()

        XCTAssertEqual(document.text, "saved")
        XCTAssertFalse(document.isDirty)
    }

    func testFailedLoadKeepsExplicitError() {
        let document = MarkdownDocument()
        let missing = temporaryURL()

        XCTAssertFalse(document.load(from: missing))
        XCTAssertNil(document.url)
        XCTAssertNotNil(document.loadError)
        XCTAssertFalse(document.isLoading)
    }

    func testMarkdownFileTypesRejectPlainText() {
        XCTAssertTrue(MarkdownFileType.accepts(URL(fileURLWithPath: "/tmp/README.MD")))
        XCTAssertTrue(MarkdownFileType.accepts(URL(fileURLWithPath: "/tmp/notes.markdown")))
        XCTAssertFalse(MarkdownFileType.accepts(URL(fileURLWithPath: "/tmp/notes.txt")))
    }
}
