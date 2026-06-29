import XCTest
@testable import DropThingsModules
@testable import DropThingsCore
import DropThingsPlatform

final class ScreenshotRegionSettingsTests: XCTestCase {
    func testDefaults() {
        let settings = ScreenshotRegionSettings()
        XCTAssertTrue(settings.hotkeyEnabled)
        XCTAssertEqual(settings.hotkey, ScreenshotRegionSettings.defaultHotkey)
        XCTAssertNil(settings.saveLocationPath)
        XCTAssertTrue(settings.copyPreviewToPasteboard)
    }

    func testDefaultHotkeyDisplayString() {
        let hotkey = ScreenshotRegionSettings.defaultHotkey
        XCTAssertEqual(hotkey.displayString, "⌃⌥4")
    }

    func testSanitizedTrimsAndDropsEmptySaveLocation() {
        let withSpaces = ScreenshotRegionSettings.sanitized(
            hotkeyEnabled: true,
            hotkey: nil,
            saveLocationPath: "   ",
            copyPreviewToPasteboard: true
        )
        XCTAssertNil(withSpaces.saveLocationPath)

        let empty = ScreenshotRegionSettings.sanitized(
            hotkeyEnabled: true,
            hotkey: nil,
            saveLocationPath: "",
            copyPreviewToPasteboard: true
        )
        XCTAssertNil(empty.saveLocationPath)

        let valid = ScreenshotRegionSettings.sanitized(
            hotkeyEnabled: false,
            hotkey: nil,
            saveLocationPath: "/Users/me/Screenshots",
            copyPreviewToPasteboard: false
        )
        XCTAssertEqual(valid.saveLocationPath, "/Users/me/Screenshots")
        XCTAssertFalse(valid.hotkeyEnabled)
        XCTAssertFalse(valid.copyPreviewToPasteboard)
    }

    @MainActor
    func testRoundTripThroughSettingsStore() {
        let backend = InMemorySettingsBackend()
        let store = SettingsStore(backend: backend)
        let original = ScreenshotRegionSettings(
            hotkeyEnabled: false,
            hotkey: GlobalHotkey.Definition(keyCode: 5, modifiers: 6, id: 99),
            saveLocationPath: "/tmp/screenshots",
            copyPreviewToPasteboard: false
        )
        store.saveScreenshotRegionSettings(original)
        let loaded = store.loadScreenshotRegionSettings()
        XCTAssertEqual(loaded, original)
    }

    func testDecodeFillsDefaultsForMissingFields() throws {
        let json = Data("{\"copyPreviewToPasteboard\": false}".utf8)
        let decoded = try JSONDecoder().decode(ScreenshotRegionSettings.self, from: json)
        XCTAssertTrue(decoded.hotkeyEnabled)
        XCTAssertEqual(decoded.hotkey, ScreenshotRegionSettings.defaultHotkey)
        XCTAssertNil(decoded.saveLocationPath)
        XCTAssertFalse(decoded.copyPreviewToPasteboard)
    }
}
