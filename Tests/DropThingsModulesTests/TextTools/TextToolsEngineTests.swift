import XCTest
@testable import DropThingsModules

final class TextToolsEngineTests: XCTestCase {
    // MARK: - Case conversion

    func testUppercase() {
        XCTAssertEqual(TextToolsEngine.uppercase("Hello World"), "HELLO WORLD")
        XCTAssertEqual(TextToolsEngine.uppercase("mixedCASE_123"), "MIXEDCASE_123")
    }

    func testLowercase() {
        XCTAssertEqual(TextToolsEngine.lowercase("Hello World"), "hello world")
        XCTAssertEqual(TextToolsEngine.lowercase("MIXEDCASE_123"), "mixedcase_123")
    }

    func testTitleCase() {
        XCTAssertEqual(TextToolsEngine.titleCase("hello world"), "Hello World")
    }

    func testCamelCase() {
        XCTAssertEqual(TextToolsEngine.camelCase("hello world"), "helloWorld")
        XCTAssertEqual(TextToolsEngine.camelCase("HELLO_WORLD"), "helloWorld")
        XCTAssertEqual(TextToolsEngine.camelCase("snake-case.value"), "snakeCaseValue")
        XCTAssertEqual(TextToolsEngine.camelCase(""), "")
    }

    func testSnakeCase() {
        XCTAssertEqual(TextToolsEngine.snakeCase("hello world"), "hello_world")
        XCTAssertEqual(TextToolsEngine.snakeCase("helloWorld"), "hello_world")
        XCTAssertEqual(TextToolsEngine.snakeCase("HELLO_WORLD"), "hello_world")
        XCTAssertEqual(TextToolsEngine.snakeCase("snake-case.value"), "snake_case_value")
        XCTAssertEqual(TextToolsEngine.snakeCase(""), "")
    }

    // MARK: - URL encoding

    func testURLEncode() {
        XCTAssertEqual(TextToolsEngine.urlEncode("hello world"), "hello%20world")
        XCTAssertEqual(TextToolsEngine.urlEncode("a+b=c"), "a+b=c")
    }

    func testURLDecode() {
        XCTAssertEqual(TextToolsEngine.urlDecode("hello%20world"), "hello world")
        XCTAssertEqual(TextToolsEngine.urlDecode("a+b=c"), "a+b=c")
    }

    // MARK: - JSON formatting

    func testJSONPretty() {
        let input = #"{"b":1,"a":2}"#
        let output = TextToolsEngine.jsonPretty(input)
        XCTAssertTrue(output.contains("{\n"))
        XCTAssertTrue(output.contains("\"a\" : 2"))
        XCTAssertTrue(output.contains("\"b\" : 1"))
    }

    func testJSONMinify() {
        let input = """
        {
            "a" : 2
        }
        """
        XCTAssertEqual(TextToolsEngine.jsonMinify(input), #"{"a":2}"#)
    }

    func testJSONInvalidReturnsInput() {
        let input = "not json"
        XCTAssertEqual(TextToolsEngine.jsonPretty(input), input)
        XCTAssertEqual(TextToolsEngine.jsonMinify(input), input)
    }

    // MARK: - Base64

    func testBase64Encode() {
        XCTAssertEqual(TextToolsEngine.base64Encode("hello"), "aGVsbG8=")
    }

    func testBase64Decode() {
        XCTAssertEqual(TextToolsEngine.base64Decode("aGVsbG8="), "hello")
    }

    func testBase64InvalidReturnsInput() {
        XCTAssertEqual(TextToolsEngine.base64Decode("%%%"), "%%%")
    }

    // MARK: - Line operations

    func testSortLines() {
        let input = "zebra\napple\nbanana"
        XCTAssertEqual(TextToolsEngine.sortLines(input), "apple\nbanana\nzebra")
    }

    func testSortLinesPreservesEmptyLines() {
        let input = "zebra\n\napple"
        XCTAssertEqual(TextToolsEngine.sortLines(input), "\napple\nzebra")
    }

    func testRemoveDuplicateLines() {
        let input = "a\nb\na\nc\nb"
        XCTAssertEqual(TextToolsEngine.removeDuplicateLines(input), "a\nb\nc")
    }

    func testRemoveDuplicateLinesDeduplicatesEmptyLines() {
        let input = "a\n\na\n"
        XCTAssertEqual(TextToolsEngine.removeDuplicateLines(input), "a\n")
    }

    // MARK: - Counts

    func testCounts() {
        let counts = TextToolsEngine.counts(for: "Hello world\nSecond line")
        XCTAssertEqual(counts.characters, 23)
        XCTAssertEqual(counts.words, 4)
        XCTAssertEqual(counts.lines, 2)
    }

    func testCountsEmpty() {
        let counts = TextToolsEngine.counts(for: "")
        XCTAssertEqual(counts.characters, 0)
        XCTAssertEqual(counts.words, 0)
        XCTAssertEqual(counts.lines, 1)
    }

    // MARK: - Dispatch

    func testApplyDispatch() {
        XCTAssertEqual(TextToolsEngine.apply(.uppercase, to: "abc"), "ABC")
        XCTAssertEqual(TextToolsEngine.apply(.snakeCase, to: "helloWorld"), "hello_world")
        XCTAssertEqual(TextToolsEngine.apply(.urlEncode, to: "a b"), "a%20b")
    }
}
