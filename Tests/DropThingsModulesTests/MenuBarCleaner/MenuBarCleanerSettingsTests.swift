import XCTest
@testable import DropThingsModules
import DropThingsCore

final class MenuBarCleanerSettingsTests: XCTestCase {
    func testDefaults() {
        let settings = MenuBarCleanerSettings()
        XCTAssertTrue(settings.hiddenItemIds.isEmpty)
    }

    @MainActor
    func testRoundTripThroughSettingsStore() {
        let backend = InMemorySettingsBackend()
        let store = SettingsStore(backend: backend)
        let original = MenuBarCleanerSettings(
            hiddenItemIds: ["com.apple.Spotlight:Wi-Fi", "com.apple.controlcenter:Battery"]
        )
        store.saveMenuBarCleanerSettings(original)
        let loaded = store.loadMenuBarCleanerSettings()
        XCTAssertEqual(loaded, original)
    }

    @MainActor
    func testCorruptedJSONFallsBackToDefaults() {
        let backend = InMemorySettingsBackend()
        backend.setData(Data([0x00, 0xFF, 0x00]), forKey: MenuBarCleanerSettingsKey.settings.rawValue)
        let store = SettingsStore(backend: backend)
        let loaded = store.loadMenuBarCleanerSettings()
        XCTAssertEqual(loaded, MenuBarCleanerSettings())
    }

    func testEqualityByHiddenSet() {
        let a = MenuBarCleanerSettings(hiddenItemIds: ["a", "b"])
        let b = MenuBarCleanerSettings(hiddenItemIds: ["b", "a"])
        let c = MenuBarCleanerSettings(hiddenItemIds: ["a"])
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }
}
