import XCTest
@testable import DropThingsModules
import DropThingsCore

final class MenuBarCleanerSettingsTests: XCTestCase {
    func testDefaults() {
        let settings = MenuBarCleanerSettings()
        XCTAssertFalse(settings.collapseOnLaunch)
        XCTAssertEqual(settings.hoverRevealDelay, 0)
        XCTAssertEqual(settings.profiles.count, 3)
        XCTAssertTrue(settings.alwaysVisibleBundleIDs.isEmpty)
    }

    func testProfileIDsAreStable() {
        let profile = MenuBarCleanerProfile(id: .work)
        XCTAssertEqual(profile.id, MenuBarCleanerProfile.ProfileID.work.id)
        XCTAssertEqual(profile.name, "Work")
        XCTAssertTrue(profile.collapsed)
    }

    @MainActor
    func testRoundTripThroughSettingsStore() {
        let backend = InMemorySettingsBackend()
        let store = SettingsStore(backend: backend)
        let original = MenuBarCleanerSettings(
            collapseOnLaunch: true,
            hoverRevealDelay: 0.5,
            alwaysVisibleBundleIDs: ["com.apple.Safari"]
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

    func testDecodingOldHiddenItemSettingsFallsBackToDefaults() throws {
        let data = #"{"hiddenItemIds":["old:id"]}"#.data(using: .utf8)!
        let loaded = try JSONDecoder().decode(MenuBarCleanerSettings.self, from: data)
        XCTAssertEqual(loaded, MenuBarCleanerSettings())
    }

    func testOldBlobWithoutProFieldsDecodesToDefaults() throws {
        let json = #"{"collapseOnLaunch":true}"#
        let decoded = try JSONDecoder().decode(MenuBarCleanerSettings.self, from: json.data(using: .utf8)!)
        XCTAssertTrue(decoded.collapseOnLaunch)
        XCTAssertEqual(decoded.hoverRevealDelay, 0)
        XCTAssertEqual(decoded.profiles.count, 3)
        XCTAssertTrue(decoded.alwaysVisibleBundleIDs.isEmpty)
    }
}
