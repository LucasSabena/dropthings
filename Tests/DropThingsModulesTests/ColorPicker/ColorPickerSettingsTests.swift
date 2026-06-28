import XCTest
@testable import DropThingsModules
@testable import DropThingsCore
import DropThingsPlatform

final class ColorPickerSettingsTests: XCTestCase {
    func testDefaults() {
        let settings = ColorPickerSettings()
        XCTAssertTrue(settings.hotkeyEnabled)
        XCTAssertTrue(settings.history.isEmpty)
        XCTAssertEqual(settings.historyLimit, ColorPickerSettings.historyLimitDefault)
    }

    func testSanitizedClampsLimit() {
        let high = ColorPickerSettings.sanitized(
            hotkeyEnabled: true,
            history: [],
            historyLimit: 9_999, hotkey: nil
        )
        XCTAssertEqual(high.historyLimit, ColorPickerSettings.historyLimitMax)
        let low = ColorPickerSettings.sanitized(
            hotkeyEnabled: true,
            history: [],
            historyLimit: 0, hotkey: nil
        )
        XCTAssertEqual(low.historyLimit, 1)
    }

    @MainActor
    func testRoundTripThroughSettingsStore() {
        let backend = InMemorySettingsBackend()
        let store = SettingsStore(backend: backend)
        let picked = PickedColor(r: 255, g: 99, b: 71)
        let original = ColorPickerSettings(
            hotkeyEnabled: false,
            history: [picked],
            historyLimit: 50
        )
        store.saveColorPickerSettings(original)
        let loaded = store.loadColorPickerSettings()
        XCTAssertEqual(loaded, original)
    }

    func testPickedColorFormatting() {
        let picked = PickedColor(r: 0xFF, g: 0x63, b: 0x47)
        XCTAssertEqual(picked.hex, "#FF6347")
        XCTAssertEqual(picked.rgbString, "rgb(255, 99, 71)")
        XCTAssertEqual(picked.rgb, PixelSampler.RGB(r: 0xFF, g: 0x63, b: 0x47))
    }
}
