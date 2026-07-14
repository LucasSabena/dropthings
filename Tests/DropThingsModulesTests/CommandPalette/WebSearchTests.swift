import XCTest
@testable import DropThingsModules

final class WebSearchTests: XCTestCase {
    func testEveryEngineBuildsHTTPSURLAndEncodesQuery() throws {
        for engine in WebSearchEngine.allCases {
            let url = try XCTUnwrap(engine.searchURL(for: "swift macOS & AppKit"))
            XCTAssertEqual(url.scheme, "https")
            let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
            XCTAssertEqual(components.queryItems?.first(where: { $0.name == "q" })?.value, "swift macOS & AppKit")
        }
    }

    func testSettingsMigrationLeavesNetworkSearchDisabled() throws {
        let legacy = Data(#"{"version":2}"#.utf8)
        let settings = try JSONDecoder().decode(CommandPaletteSettings.self, from: legacy)
        XCTAssertFalse(settings.webSearchEnabled)
        XCTAssertEqual(settings.webSearchEngine, .google)
        XCTAssertNil(settings.webBrowserBundleIdentifier)
    }
}
