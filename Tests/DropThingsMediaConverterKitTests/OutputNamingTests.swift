import XCTest
@testable import DropThingsMediaConverterKit

final class OutputNamingTests: XCTestCase {

    func testProposedSwapsExtension() {
        let src = URL(fileURLWithPath: "/Photos/Beach.HEIC")
        let url = OutputNaming.proposedURL(for: src, format: .jpeg, in: URL(fileURLWithPath: "/out"))
        XCTAssertEqual(url.lastPathComponent, "Beach.jpg")
    }

    func testSanitizeStripsLeadingDots() {
        XCTAssertEqual(OutputNaming.sanitizeBase("..hidden"), "hidden")
        XCTAssertEqual(OutputNaming.sanitizeBase("."), "")
    }

    func testSanitizeStripsSeparatorsAndControl() {
        XCTAssertEqual(OutputNaming.sanitizeBase("a/b:c"), "abc")
        XCTAssertTrue(OutputNaming.sanitizeBase("a\u{0007}b").isEmpty || OutputNaming.sanitizeBase("a\u{0007}b") == "ab")
        XCTAssertEqual(OutputNaming.sanitizeBase("line\nbreak"), "linebreak")
    }

    func testSuffixIncrements() {
        let existing: Set<URL> = [
            URL(fileURLWithPath: "/out/Photo.jpg"),
            URL(fileURLWithPath: "/out/Photo 2.jpg"),
            URL(fileURLWithPath: "/out/Photo 3.jpg")
        ]
        let resolved = OutputNaming.resolve(
            URL(fileURLWithPath: "/out/Photo.jpg"),
            conflict: .suffix,
            exists: { existing.contains($0) }
        )
        XCTAssertEqual(resolved?.lastPathComponent, "Photo 4.jpg")
    }

    func testFailPolicyReturnsNilWhenCollision() {
        let existing = URL(fileURLWithPath: "/out/X.jpg")
        let resolved = OutputNaming.resolve(
            existing, conflict: .fail,
            exists: { $0 == existing }
        )
        XCTAssertNil(resolved)
    }

    func testFailPolicyReturnsURLWhenFree() {
        let url = URL(fileURLWithPath: "/out/free.jpg")
        let resolved = OutputNaming.resolve(url, conflict: .fail, exists: { _ in false })
        XCTAssertEqual(resolved, url)
    }

    func testEmptyBaseUsesFallbackName() {
        // A source whose sanitized base is empty must not collapse into ".png".
        // We construct the case directly through the pure helper.
        XCTAssertTrue(OutputNaming.sanitizeBase("...").isEmpty)
        let proposed = OutputNaming.proposedURL(
            for: URL(fileURLWithPath: "/Photos/...".addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)!),
            format: .png,
            in: URL(fileURLWithPath: "/out"))
        // The fallback "Converted" base must be used for an empty base name.
        XCTAssertTrue(proposed.lastPathComponent == "Converted.png" || proposed.deletingPathExtension().lastPathComponent == "Converted",
                      "got \(proposed.lastPathComponent)")
    }
}
