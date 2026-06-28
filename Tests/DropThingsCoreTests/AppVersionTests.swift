import XCTest
@testable import DropThingsCore

final class AppVersionTests: XCTestCase {
    func testComparesNumericComponents() {
        XCTAssertGreaterThan(AppVersion("0.1.10"), AppVersion("0.1.2"))
        XCTAssertGreaterThan(AppVersion("1.0.0"), AppVersion("0.9.9"))
        XCTAssertLessThan(AppVersion("0.2.0"), AppVersion("0.10.0"))
    }

    func testIgnoresLeadingVAndTrailingZeros() {
        XCTAssertEqual(AppVersion("v1.2.0"), AppVersion("1.2"))
        XCTAssertEqual(AppVersion("V0.1.0"), AppVersion("0.1"))
    }

    func testIgnoresPrereleaseAndBuildMetadataForStableReleaseComparison() {
        XCTAssertEqual(AppVersion("1.2.3-beta.1"), AppVersion("1.2.3"))
        XCTAssertEqual(AppVersion("1.2.3+45"), AppVersion("1.2.3"))
    }
}
