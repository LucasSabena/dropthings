import XCTest
import DropThingsPlatform

final class ApplicationBundleLookupTests: XCTestCase {

    func testKnownBundleIDReturnsName() {
        let name = applicationName(forBundleID: "com.apple.finder")
        XCTAssertFalse(name.isEmpty)
        XCTAssertNotEqual(name, "com.apple.finder")
    }

    func testUnknownBundleIDReturnsBundleID() {
        let bundleID = "com.dropthings.nonexistent-app"
        XCTAssertEqual(applicationName(forBundleID: bundleID), bundleID)
    }

    func testEmptyBundleIDReturnsInput() {
        XCTAssertEqual(applicationName(forBundleID: ""), "")
    }
}
