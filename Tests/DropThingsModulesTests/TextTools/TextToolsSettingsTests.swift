import XCTest
@testable import DropThingsModules
@testable import DropThingsCore
import DropThingsPlatform

final class TextToolsSettingsTests: XCTestCase {
    func testDefaults() {
        let settings = TextToolsSettings()
        XCTAssertTrue(settings.hotkeyEnabled)
        XCTAssertEqual(settings.hotkey, GlobalHotkey.defaultTextToolsHotkey)
    }

    @MainActor
    func testRoundTripThroughSettingsStore() {
        let backend = InMemorySettingsBackend()
        let store = SettingsStore(backend: backend)
        let customHotkey = GlobalHotkey.Definition(keyCode: 1, modifiers: 2, id: 999)
        let original = TextToolsSettings(hotkeyEnabled: false, hotkey: customHotkey)
        store.saveTextToolsSettings(original)
        let loaded = store.loadTextToolsSettings()
        XCTAssertEqual(loaded, original)
    }

    @MainActor
    func testNilHotkeyDecodesToDefault() {
        let backend = InMemorySettingsBackend()
        let store = SettingsStore(backend: backend)
        let original = TextToolsSettings(hotkeyEnabled: false, hotkey: nil)
        store.saveTextToolsSettings(original)
        let loaded = store.loadTextToolsSettings()
        XCTAssertFalse(loaded.hotkeyEnabled)
        XCTAssertEqual(loaded.hotkey, GlobalHotkey.defaultTextToolsHotkey)
    }

    func testSanitizedPreservesValues() {
        let settings = TextToolsSettings.sanitized(hotkeyEnabled: false, hotkey: nil)
        XCTAssertFalse(settings.hotkeyEnabled)
        XCTAssertNil(settings.hotkey)
    }

    func testDefaultHotkeyIsOptionCommandT() {
        let definition = GlobalHotkey.defaultTextToolsHotkey
        XCTAssertNotNil(definition)
        XCTAssertEqual(definition?.displayString, "⌥⌘T")
    }
}
