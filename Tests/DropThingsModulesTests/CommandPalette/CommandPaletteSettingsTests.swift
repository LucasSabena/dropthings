import XCTest
import Carbon.HIToolbox
@testable import DropThingsModules
@testable import DropThingsCore
import DropThingsPlatform

final class CommandPaletteSettingsTests: XCTestCase {
    func testDefaults() {
        let settings = CommandPaletteSettings()
        XCTAssertTrue(settings.hotkeyEnabled)
        XCTAssertEqual(settings.hotkey, GlobalHotkey.defaultCommandPaletteHotkey)
    }

    @MainActor
    func testRoundTripThroughSettingsStore() {
        let backend = InMemorySettingsBackend()
        let store = SettingsStore(backend: backend)
        let original = CommandPaletteSettings(
            hotkeyEnabled: false,
            hotkey: GlobalHotkey.Definition(keyCode: UInt32(kVK_ANSI_P), modifiers: UInt32(cmdKey), id: 99)
        )
        store.saveCommandPaletteSettings(original)
        let loaded = store.loadCommandPaletteSettings()
        XCTAssertEqual(loaded, original)
    }

    func testSanitizedPreservesValues() {
        let custom = GlobalHotkey.Definition(keyCode: UInt32(kVK_ANSI_A), modifiers: UInt32(optionKey), id: 99)
        let sanitized = CommandPaletteSettings.sanitized(
            hotkeyEnabled: false,
            hotkey: custom
        )
        XCTAssertFalse(sanitized.hotkeyEnabled)
        XCTAssertEqual(sanitized.hotkey, custom)
    }

    func testMissingFieldsDecodeToDefaults() throws {
        let json = Data("{}".utf8)
        let decoded = try JSONDecoder().decode(CommandPaletteSettings.self, from: json)
        XCTAssertTrue(decoded.hotkeyEnabled)
        XCTAssertEqual(decoded.hotkey, GlobalHotkey.defaultCommandPaletteHotkey)
    }
}
