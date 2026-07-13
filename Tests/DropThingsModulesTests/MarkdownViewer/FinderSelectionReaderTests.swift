import XCTest
@testable import DropThingsModules

final class FinderSelectionReaderTests: XCTestCase {

    func testParsePathsSplitsNewlinesAndDropsEmpty() {
        let urls = FinderSelectionReader.parsePaths("/a/b.md\n/c/d.md\n")
        XCTAssertEqual(urls.count, 2)
        XCTAssertEqual(urls[0].path, "/a/b.md")
        XCTAssertEqual(urls[1].path, "/c/d.md")
    }

    func testParsePathsHandlesEmptyString() {
        XCTAssertTrue(FinderSelectionReader.parsePaths("").isEmpty)
        XCTAssertTrue(FinderSelectionReader.parsePaths("\n\n").isEmpty)
    }

    func testParsePathsHandlesTrailingNewline() {
        let urls = FinderSelectionReader.parsePaths("/tmp/one.md\n")
        XCTAssertEqual(urls.count, 1)
    }

    func testMarkdownOnlyKeepsMdExtensions() {
        let urls = [
            URL(fileURLWithPath: "/a.md"),
            URL(fileURLWithPath: "/b.MARKDOWN"),
            URL(fileURLWithPath: "/c.mdown"),
            URL(fileURLWithPath: "/d.MKD"),
            URL(fileURLWithPath: "/e.txt"),
            URL(fileURLWithPath: "/f/notes.md")
        ]
        let kept = FinderSelectionReader.markdownOnly(urls)
        XCTAssertEqual(kept.count, 5)
        XCTAssertFalse(kept.contains(where: { $0.pathExtension == "txt" }))
    }

    func testMarkdownOnlyEmptyForNoMarkdown() {
        let urls = [URL(fileURLWithPath: "/a.txt"), URL(fileURLWithPath: "/b.png")]
        XCTAssertTrue(FinderSelectionReader.markdownOnly(urls).isEmpty)
    }

    func testMarkdownOnlyPreservesOrder() {
        let urls = [
            URL(fileURLWithPath: "/z.md"),
            URL(fileURLWithPath: "/a.md"),
            URL(fileURLWithPath: "/m.md")
        ]
        let kept = FinderSelectionReader.markdownOnly(urls)
        XCTAssertEqual(kept.map(\.lastPathComponent), ["z.md", "a.md", "m.md"])
    }
}
