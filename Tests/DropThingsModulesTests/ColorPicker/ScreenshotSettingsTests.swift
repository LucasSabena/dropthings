import XCTest
@testable import DropThingsModules
import DropThingsCore

final class ScreenshotSettingsTests: XCTestCase {
    func testDefaults() {
        let settings = ScreenshotSettings()
        XCTAssertTrue(settings.hotkeyEnabled)
        XCTAssertNil(settings.saveFolderBookmark)
        XCTAssertNil(settings.lastSavePath)
    }

    @MainActor
    func testRoundTripThroughSettingsStore() {
        let backend = InMemorySettingsBackend()
        let store = SettingsStore(backend: backend)
        let original = ScreenshotSettings(
            hotkeyEnabled: false,
            saveFolderBookmark: Data([0x01, 0x02, 0x03]),
            lastSavePath: "/tmp/screenshot.png"
        )
        store.saveScreenshotSettings(original)
        let loaded = store.loadScreenshotSettings()
        XCTAssertEqual(loaded, original)
    }
}
