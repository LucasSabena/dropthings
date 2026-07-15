import XCTest
import DropThingsCore
import DropThingsPlatform
@testable import DropThingsModules

@MainActor
final class SmartClipboardSettingsTests: XCTestCase {
    private var backend: InMemorySettingsBackend!
    private var store: SettingsStore!

    override func setUp() {
        super.setUp()
        backend = InMemorySettingsBackend()
        store = SettingsStore(backend: backend)
    }

    func testDefaults() {
        let settings = SmartClipboardSettings()
        XCTAssertEqual(settings.schemaVersion, SmartClipboardSettings.currentSchemaVersion)
        XCTAssertTrue(settings.hotkeyEnabled)
        XCTAssertEqual(settings.colorFormat, .hex)
        XCTAssertFalse(settings.hideSensitivePreview)
        XCTAssertEqual(settings.undoCopyWindowSeconds, SmartClipboardSettings.defaultUndoWindowSeconds)
        XCTAssertFalse(settings.pasteBackEnabled)
    }

    func testRoundTripPersistsEveryField() {
        var original = SmartClipboardSettings()
        original.colorFormat = .hsl
        original.hideSensitivePreview = true
        original.undoCopyWindowSeconds = 60
        original.pasteBackEnabled = true
        store.saveSmartClipboardSettings(original)

        let loaded = store.loadSmartClipboardSettings()

        XCTAssertEqual(loaded.colorFormat, .hsl)
        XCTAssertTrue(loaded.hideSensitivePreview)
        XCTAssertEqual(loaded.undoCopyWindowSeconds, 60)
        XCTAssertTrue(loaded.pasteBackEnabled)
    }

    func testCorruptBlobFallsBackToDefaults() {
        store.setData(Data([0x00, 0x01]), SmartClipboardSettingsKey.settings)
        let loaded = store.loadSmartClipboardSettings()
        XCTAssertEqual(loaded.colorFormat, .hex)
        XCTAssertEqual(loaded.undoCopyWindowSeconds, SmartClipboardSettings.defaultUndoWindowSeconds)
    }

    func testSanitizedClampsUndoWindow() {
        let tooHigh = SmartClipboardSettings.sanitized(
            hotkeyEnabled: true, hotkey: nil, colorFormat: .hex,
            hideSensitivePreview: false, undoCopyWindowSeconds: 99999, pasteBackEnabled: false
        )
        XCTAssertEqual(tooHigh.undoCopyWindowSeconds, SmartClipboardSettings.maxUndoWindowSeconds)

        let negative = SmartClipboardSettings.sanitized(
            hotkeyEnabled: true, hotkey: nil, colorFormat: .hex,
            hideSensitivePreview: false, undoCopyWindowSeconds: -10, pasteBackEnabled: false
        )
        XCTAssertEqual(negative.undoCopyWindowSeconds, SmartClipboardSettings.minUndoWindowSeconds)
    }

    func testDecodingMissingFieldsUsesDefaults() {
        let json = #"{"hotkeyEnabled":false}"#.data(using: .utf8)!
        store.setData(json, SmartClipboardSettingsKey.settings)
        let loaded = store.loadSmartClipboardSettings()
        XCTAssertFalse(loaded.hotkeyEnabled)
        XCTAssertEqual(loaded.colorFormat, .hex)
    }
}