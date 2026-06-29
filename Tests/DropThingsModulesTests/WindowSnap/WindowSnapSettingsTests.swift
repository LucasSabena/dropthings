import XCTest
@testable import DropThingsModules
import DropThingsCore
import DropThingsPlatform

final class WindowSnapSettingsTests: XCTestCase {
    func testDefaultsMatchActionDefaults() {
        let settings = WindowSnapSettings()
        for action in WindowSnapAction.allCases {
            XCTAssertEqual(settings.hotkey(for: action), action.defaultHotkey)
        }
    }

    func testHotkeySetterMutatesCorrectField() {
        var settings = WindowSnapSettings()
        let custom = GlobalHotkey.Definition(keyCode: 1, modifiers: 2, id: 99)
        settings.setHotkey(custom, for: .leftHalf)
        XCTAssertEqual(settings.hotkey(for: .leftHalf), custom)
        XCTAssertEqual(settings.hotkey(for: .rightHalf), WindowSnapAction.rightHalf.defaultHotkey)
    }

    @MainActor
    func testRoundTripThroughSettingsStore() {
        let backend = InMemorySettingsBackend()
        let store = SettingsStore(backend: backend)
        var original = WindowSnapSettings()
        original.setHotkey(
            GlobalHotkey.Definition(keyCode: 5, modifiers: 6, id: 99),
            for: .maximize
        )
        original.setHotkey(
            GlobalHotkey.Definition(keyCode: 7, modifiers: 8, id: 100),
            for: .bottomRight
        )
        store.saveWindowSnapSettings(original)
        let loaded = store.loadWindowSnapSettings()
        XCTAssertEqual(loaded, original)
    }

    @MainActor
    func testCorruptedJSONFallsBackToDefaults() {
        let backend = InMemorySettingsBackend()
        backend.setData(Data([0x00, 0xFF, 0x00]), forKey: WindowSnapSettingsKey.settings.rawValue)
        let store = SettingsStore(backend: backend)
        let loaded = store.loadWindowSnapSettings()
        XCTAssertEqual(loaded, WindowSnapSettings())
    }

    func testOldBlobWithoutHotkeysDecodesToDefaults() throws {
        let json = "{}".data(using: .utf8)!
        let decoded = try JSONDecoder().decode(WindowSnapSettings.self, from: json)
        XCTAssertEqual(decoded, WindowSnapSettings())
    }
}
