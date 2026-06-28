import XCTest
@testable import DropThingsModules
import DropThingsCore

final class MenuBarCleanerSettingsTests: XCTestCase {
    func testDefaults() {
        let settings = MenuBarCleanerSettings()
        XCTAssertFalse(settings.collapseOnLaunch)
    }

    @MainActor
    func testRoundTripThroughSettingsStore() {
        let backend = InMemorySettingsBackend()
        let store = SettingsStore(backend: backend)
        let original = MenuBarCleanerSettings(collapseOnLaunch: true)
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

    func testDecodingOldHiddenItemSettingsFallsBackToDefaults() throws {
        let data = #"{"hiddenItemIds":["old:id"]}"#.data(using: .utf8)!
        let loaded = try JSONDecoder().decode(MenuBarCleanerSettings.self, from: data)
        XCTAssertEqual(loaded, MenuBarCleanerSettings())
    }
}
