import XCTest
@testable import DropThingsModules
import AppKit

@MainActor
final class PasteboardItemReaderTests: XCTestCase {
    private func makePasteboard() -> NSPasteboard {
        let pb = NSPasteboard(name: NSPasteboard.Name("test-\(UUID().uuidString)"))
        pb.clearContents()
        return pb
    }

    func testEmptyPasteboardReturnsEmpty() {
        let pb = makePasteboard()
        let kinds = PasteboardItemReader().read(from: pb)
        XCTAssertTrue(kinds.isEmpty)
    }

    func testReadsFileURL() {
        let pb = makePasteboard()
        let url = URL(fileURLWithPath: "/tmp/example.txt")
        pb.setData(url.dataRepresentation, forType: .fileURL)

        let kinds = PasteboardItemReader().read(from: pb)
        XCTAssertEqual(kinds.count, 1)
        guard case .file(let readURL) = kinds[0] else {
            return XCTFail("Expected .file kind, got \(kinds[0])")
        }
        XCTAssertEqual(readURL.standardizedFileURL.path, url.standardizedFileURL.path)
    }

    func testReadsPlainText() {
        let pb = makePasteboard()
        pb.setString("hello world", forType: .string)

        let kinds = PasteboardItemReader().read(from: pb)
        XCTAssertEqual(kinds.count, 1)
        guard case .text(let value) = kinds[0] else {
            return XCTFail("Expected .text kind, got \(kinds[0])")
        }
        XCTAssertEqual(value, "hello world")
    }

    func testSkipsEmptyStrings() {
        let pb = makePasteboard()
        pb.setString("", forType: .string)

        let kinds = PasteboardItemReader().read(from: pb)
        XCTAssertTrue(kinds.isEmpty)
    }

    func testFileURLWinsWhenItemHasBoth() {
        // When a single pasteboard item carries both a file URL and a string,
        // the file URL is the stronger signal. This avoids dropping a real
        // file just because the source app also published a label.
        let pb = makePasteboard()
        let url = URL(fileURLWithPath: "/tmp/example.txt")
        pb.setData(url.dataRepresentation, forType: .fileURL)
        pb.setString("second item", forType: .string)

        let kinds = PasteboardItemReader().read(from: pb)
        XCTAssertEqual(kinds.count, 1)
        XCTAssertTrue(kinds.contains(where: { if case .file = $0 { return true }; return false }))
    }
}
