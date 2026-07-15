import XCTest
@testable import DropThingsModules

final class SmartClipboardTextEngineTests: XCTestCase {
    // MARK: - Case

    func testUppercaseLowercase() {
        XCTAssertEqual(SmartClipboardTextEngine.uppercase("héllo"), "HÉLLO")
        XCTAssertEqual(SmartClipboardTextEngine.lowercase("HÉLLO"), "héllo")
    }

    func testSentenceCaseCapitalizesFirst() {
        XCTAssertEqual(SmartClipboardTextEngine.sentenceCase("hello world"), "Hello world")
        XCTAssertEqual(SmartClipboardTextEngine.sentenceCase(""), "")
    }

    // MARK: - Whitespace

    func testTrim() {
        XCTAssertEqual(SmartClipboardTextEngine.trim("  hi \n"), "hi")
    }

    func testNormalizeWhitespaceCollapsesRuns() {
        XCTAssertEqual(SmartClipboardTextEngine.normalizeWhitespace("a   b\tc\n\nd"), "a b c d")
    }

    func testNormalizeLineEndings() {
        XCTAssertEqual(SmartClipboardTextEngine.normalizeLineEndings("a\r\nb\rc"), "a\nb\nc")
    }

    func testCollapseBlankLines() {
        let input = "a\n\n\nb\n\n\nc"
        XCTAssertEqual(SmartClipboardTextEngine.collapseBlankLines(input), "a\n\nb\n\nc")
    }

    func testStripTrailingWhitespace() {
        XCTAssertEqual(SmartClipboardTextEngine.stripTrailingWhitespace("a   \nb  \n"), "a\nb\n")
    }

    // MARK: - Lines

    func testSortLines() {
        XCTAssertEqual(SmartClipboardTextEngine.sortLines("b\na\nc", ascending: true), "a\nb\nc")
        XCTAssertEqual(SmartClipboardTextEngine.sortLines("a\nb\nc", ascending: false), "c\nb\na")
    }

    func testDeduplicateLinesKeepsFirst() {
        XCTAssertEqual(SmartClipboardTextEngine.deduplicateLines("a\nb\na\nc"), "a\nb\nc")
    }

    func testReverseLines() {
        XCTAssertEqual(SmartClipboardTextEngine.reverseLines("a\nb\nc"), "c\nb\na")
    }

    // MARK: - Encoding

    func testURLEncodeDecodeRoundTrip() {
        let original = "hello world & friends"
        let encoded = SmartClipboardTextEngine.urlEncode(original)
        XCTAssertNotEqual(encoded, original)
        XCTAssertEqual(SmartClipboardTextEngine.urlDecode(encoded), original)
    }

    func testBase64RoundTrip() {
        let original = "Smart Clipboard"
        XCTAssertEqual(SmartClipboardTextEngine.base64Decode(SmartClipboardTextEngine.base64Encode(original)), original)
    }

    func testBase64DecodeInvalidReturnsInput() {
        XCTAssertEqual(SmartClipboardTextEngine.base64Decode("!!!not base64!!!"), "!!!not base64!!!")
    }

    func testHTMLEntitiesRoundTrip() {
        let original = "<a href=\"x\">Tom & Jerry</a>"
        let encoded = SmartClipboardTextEngine.htmlEntityEncode(original)
        XCTAssertTrue(encoded.contains("&lt;"))
        XCTAssertEqual(SmartClipboardTextEngine.htmlEntityDecode(encoded), original)
    }

    // MARK: - Counts

    func testCounts() {
        let counts = SmartClipboardTextEngine.counts(for: "hello world\nthird line")
        XCTAssertEqual(counts.characters, "hello world\nthird line".count)
        XCTAssertEqual(counts.words, 4)
        XCTAssertEqual(counts.lines, 2)
    }
}

final class SmartClipboardJSONEngineTests: XCTestCase {
    func testValidateAcceptsValidJSON() {
        XCTAssertNil(SmartClipboardJSONEngine.validate("{\"a\":1}"))
        XCTAssertNil(SmartClipboardJSONEngine.validate("[1,2,3]"))
    }

    func testValidateRejectsBrokenJSON() {
        XCTAssertNotNil(SmartClipboardJSONEngine.validate("{broken"))
    }

    func testPrettyPrintProducesIndented() {
        let result = SmartClipboardJSONEngine.prettyPrint("{\"a\":1}")
        XCTAssertNotNil(result)
        XCTAssertTrue(result?.output.contains("\n") == true)
        XCTAssertFalse(result?.isMinified ?? true)
    }

    func testPrettyPrintSortedKeysOrdersAlphabetically() {
        let result = SmartClipboardJSONEngine.prettyPrint("{\"b\":1,\"a\":2}", sortKeys: true)
        let output = result?.output ?? ""
        guard let aRange = output.range(of: "\"a\""), let bRange = output.range(of: "\"b\"") else {
            XCTFail("Expected both keys in output"); return
        }
        XCTAssertLessThan(aRange.lowerBound, bRange.lowerBound)
    }

    func testMinifyRemovesWhitespace() {
        let result = SmartClipboardJSONEngine.minify("{\n  \"a\": 1\n}")
        XCTAssertEqual(result?.output, "{\"a\":1}")
        XCTAssertTrue(result?.isMinified ?? false)
    }

    func testInvalidJSONReturnsNil() {
        XCTAssertNil(SmartClipboardJSONEngine.prettyPrint("{broken"))
        XCTAssertNil(SmartClipboardJSONEngine.minify("{broken"))
    }
}

final class SmartClipboardURLEngineTests: XCTestCase {
    func testNormalizeStripsTrackingParameters() {
        let url = URL(string: "https://example.com/path?utm_source=x&id=42&fbclid=abc")!
        let result = SmartClipboardURLEngine.normalize(url)
        XCTAssertEqual(result.url.absoluteString, "https://example.com/path?id=42")
        XCTAssertEqual(Set(result.removedParameters), ["utm_source", "fbclid"])
    }

    func testNormalizeDropsTrailingSlashOnBareHost() {
        let url = URL(string: "https://example.com/")!
        let result = SmartClipboardURLEngine.normalize(url)
        XCTAssertEqual(result.url.absoluteString, "https://example.com")
    }

    func testMarkdownLink() {
        let url = URL(string: "https://example.com")!
        XCTAssertEqual(SmartClipboardURLEngine.markdownLink(url: url, label: "Example"), "[Example](https://example.com)")
        XCTAssertEqual(SmartClipboardURLEngine.markdownLink(url: url), "[example.com](https://example.com)")
    }

    func testTrackingParameterListIsLowercasedMatch() {
        let url = URL(string: "https://x.com/?UTM_Source=a&keep=1")!
        let result = SmartClipboardURLEngine.normalize(url)
        XCTAssertTrue(result.removedParameters.contains("UTM_Source"))
        XCTAssertEqual(result.url.absoluteString, "https://x.com/?keep=1")
    }
}