import XCTest
@testable import DropThingsModules
import DropThingsCore

final class ScrollSettingsTests: XCTestCase {
    func testDefaults() {
        let settings = ScrollSettings()
        XCTAssertEqual(settings.trackpadDirection, .natural)
        XCTAssertEqual(settings.mouseWheelDirection, .inverted)
        XCTAssertEqual(settings.magicMouseDirection, .natural)
        XCTAssertTrue(settings.horizontalScrollEnabled)
        XCTAssertEqual(settings.scrollMultiplier, 1.0)
    }

    func testDirectionForKind() {
        let settings = ScrollSettings(
            trackpadDirection: .inverted,
            mouseWheelDirection: .natural,
            magicMouseDirection: .inverted
        )
        XCTAssertEqual(settings.direction(for: .trackpad), .inverted)
        XCTAssertEqual(settings.direction(for: .mouseWheel), .natural)
        XCTAssertEqual(settings.direction(for: .magicMouse), .inverted)
        XCTAssertEqual(settings.direction(for: .unknown), .natural)
    }

    func testSanitizedClampsMultiplier() {
        let high = ScrollSettings.sanitized(
            trackpadDirection: .natural,
            mouseWheelDirection: .natural,
            magicMouseDirection: .natural,
            horizontalScrollEnabled: true,
            scrollMultiplier: 100, hotkey: nil,
        )
        XCTAssertEqual(high.scrollMultiplier, ScrollSettings.multiplierMax)

        let low = ScrollSettings.sanitized(
            trackpadDirection: .natural,
            mouseWheelDirection: .natural,
            magicMouseDirection: .natural,
            horizontalScrollEnabled: true,
            scrollMultiplier: 0, hotkey: nil,
        )
        XCTAssertEqual(low.scrollMultiplier, ScrollSettings.multiplierMin)
    }

    @MainActor
    func testRoundTripThroughSettingsStore() {
        let backend = InMemorySettingsBackend()
        let store = SettingsStore(backend: backend)
        let original = ScrollSettings(
            trackpadDirection: .inverted,
            mouseWheelDirection: .natural,
            magicMouseDirection: .inverted,
            horizontalScrollEnabled: false,
            scrollMultiplier: 1.75
        )
        store.saveScrollSettings(original)
        let loaded = store.loadScrollSettings()
        XCTAssertEqual(loaded, original)
    }

    @MainActor
    func testCorruptedJSONFallsBackToDefaults() {
        let backend = InMemorySettingsBackend()
        backend.setData(Data([0x00, 0xFF, 0x00]), forKey: ScrollSettingsKey.settings.rawValue)
        let store = SettingsStore(backend: backend)
        let loaded = store.loadScrollSettings()
        XCTAssertEqual(loaded, ScrollSettings())
    }
}
