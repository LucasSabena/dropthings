import XCTest
@testable import DropThingsModules

final class SmartClipboardClassifierTests: XCTestCase {
    func testClassifiesURL() {
        XCTAssertEqual(SmartClipboardClassifier.classify(text: "https://example.com"), .url)
        XCTAssertEqual(SmartClipboardClassifier.classify(text: "http://example.com/path?q=1"), .url)
    }

    func testClassifiesJSON() {
        XCTAssertEqual(SmartClipboardClassifier.classify(text: "{\"a\":1}"), .json)
        XCTAssertEqual(SmartClipboardClassifier.classify(text: "[1,2,3]"), .json)
    }

    func testBareStringStaysText() {
        XCTAssertEqual(SmartClipboardClassifier.classify(text: "hello"), .text)
        XCTAssertEqual(SmartClipboardClassifier.classify(text: "42"), .text)
        XCTAssertEqual(SmartClipboardClassifier.classify(text: "\"quoted\""), .text)
    }

    func testMultilineTextIsNotURL() {
        XCTAssertEqual(SmartClipboardClassifier.classify(text: "https://example.com\nsecond line"), .text)
    }

    func testClassifiesColor() {
        XCTAssertEqual(SmartClipboardClassifier.classify(text: "#FF0000"), .color)
        XCTAssertEqual(SmartClipboardClassifier.classify(text: "rgb(255, 0, 0)"), .color)
        XCTAssertEqual(SmartClipboardClassifier.classify(text: "hsl(0, 100%, 50%)"), .color)
        XCTAssertEqual(SmartClipboardClassifier.classify(text: "red"), .color)
    }

    func testFilesAndImagesWinOverText() {
        XCTAssertEqual(
            SmartClipboardClassifier.classify(text: "x", fileURLs: [URL(fileURLWithPath: "/a")], imageData: nil, colorHex: nil),
            .files
        )
        XCTAssertEqual(
            SmartClipboardClassifier.classify(text: "x", fileURLs: [], imageData: Data(), colorHex: nil),
            .image
        )
        XCTAssertEqual(
            SmartClipboardClassifier.classify(text: "x", fileURLs: [], imageData: nil, colorHex: "#000000"),
            .color
        )
    }

    func testIsJSONRejectsNonObjectFragments() {
        XCTAssertFalse(SmartClipboardClassifier.isJSON("123"))
        XCTAssertFalse(SmartClipboardClassifier.isJSON("\"hello\""))
        XCTAssertFalse(SmartClipboardClassifier.isJSON(""))
        XCTAssertFalse(SmartClipboardClassifier.isJSON("{broken"))
    }

    func testIsURLRejectsRelativeAndFileSchemes() {
        XCTAssertFalse(SmartClipboardClassifier.isURL("/Users/foo"))
        XCTAssertFalse(SmartClipboardClassifier.isURL("file:///tmp/a"))
        XCTAssertFalse(SmartClipboardClassifier.isURL("example.com"))
    }
}