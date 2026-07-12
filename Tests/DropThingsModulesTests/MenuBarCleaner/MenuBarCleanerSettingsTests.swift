import XCTest
@testable import DropThingsModules
import DropThingsCore

final class MenuBarCleanerSettingsTests: XCTestCase {
    func testDefaults() {
        let settings = MenuBarCleanerSettings()
        XCTAssertFalse(settings.collapseOnLaunch)
        XCTAssertEqual(settings.hoverRevealDelay, 0)
        XCTAssertEqual(settings.profiles.count, 3)
        XCTAssertFalse(settings.drawerMode)
        XCTAssertEqual(settings.dividers.count, 1)
        XCTAssertEqual(settings.dividers.first?.id, MenuBarCleanerDivider.mainID)
        XCTAssertTrue(settings.dividers.first?.isOverflow == true)
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
            drawerMode: true,
            dividers: [
                .defaultMain,
                MenuBarCleanerDivider(name: "Focus", symbolName: "circle.fill", isOverflow: false)
            ]
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
        XCTAssertFalse(decoded.drawerMode)
        XCTAssertEqual(decoded.dividers.count, 1)
    }

    func testSanitizedKeepsOnlyMainOverflowDivider() {
        let extraOverflow = MenuBarCleanerDivider(name: "Unsafe", isOverflow: true)
        let settings = MenuBarCleanerSettings(dividers: [extraOverflow]).sanitized()

        XCTAssertEqual(settings.dividers.first?.id, MenuBarCleanerDivider.mainID)
        XCTAssertTrue(settings.dividers.first?.isOverflow == true)
        XCTAssertTrue(settings.dividers.dropFirst().allSatisfy { !$0.isOverflow })
    }
}
