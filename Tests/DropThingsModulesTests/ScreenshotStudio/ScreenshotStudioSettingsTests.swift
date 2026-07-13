import XCTest
@testable import DropThingsModules
import DropThingsCore
import DropThingsPlatform

final class ScreenshotStudioSettingsTests: XCTestCase {
    func testDefaultsAssignDistinctShortcutsPerCaptureMode() {
        let settings = ScreenshotStudioSettings()
        XCTAssertEqual(settings.shortcuts.count, ScreenshotCaptureMode.allCases.count)
        XCTAssertTrue(settings.duplicateShortcuts.isEmpty)
        XCTAssertEqual(settings.shortcuts[.region]?.displayString, "⌃⌥4")
    }

    func testDefaultsUseIndependentOutputsForFastAndEditingCaptures() {
        let settings = ScreenshotStudioSettings()
        XCTAssertEqual(settings.output(for: .region), .copy)
        XCTAssertEqual(settings.output(for: .window), .editor)
        XCTAssertEqual(settings.output(for: .display), .editor)
        XCTAssertEqual(settings.output(for: .scrolling), .editor)
        XCTAssertTrue(settings.showCapturePreview)
    }

    func testDuplicateShortcutsAreReported() {
        let hotkey = GlobalHotkey.Definition(keyCode: 18, modifiers: 256, id: 410)
        var settings = ScreenshotStudioSettings()
        settings.shortcuts[.region] = hotkey
        settings.shortcuts[.window] = GlobalHotkey.Definition(keyCode: 18, modifiers: 256, id: 411)
        XCTAssertEqual(settings.duplicateShortcuts, Set([hotkey, settings.shortcuts[.window]!]))
    }

    func testNewFieldsDecodeFromOlderSettingsBlob() throws {
        let data = Data("{\"version\":1,\"shortcutsEnabled\":true}".utf8)
        let settings = try JSONDecoder().decode(ScreenshotStudioSettings.self, from: data)
        XCTAssertEqual(settings.fileFormat, .png)
        XCTAssertEqual(settings.jpegQuality, 0.92)
        XCTAssertEqual(settings.thumbnailDuration, 8)
        XCTAssertEqual(settings.scrollingMaxFrames, 30)
        XCTAssertEqual(settings.output(for: .region), .editor)
        XCTAssertTrue(settings.showCapturePreview)
    }

    @MainActor
    func testMigratesScreenshotRegionSettingsOnce() throws {
        let backend = InMemorySettingsBackend()
        let store = SettingsStore(backend: backend)
        let legacy = """
        {"hotkeyEnabled":false,"hotkey":{"keyCode":12,"modifiers":256,"id":4},"saveLocationPath":"/tmp/captures","copyPreviewToPasteboard":false}
        """
        store.setData(Data(legacy.utf8), SettingsKey("modules.screenshot-region.settings"))

        let settings = store.loadScreenshotStudioSettings()
        XCTAssertFalse(settings.shortcutsEnabled)
        XCTAssertEqual(settings.shortcuts[.region]?.keyCode, 12)
        XCTAssertEqual(settings.saveLocationPath, "/tmp/captures")
        XCTAssertEqual(settings.defaultOutput, .save)
        XCTAssertNotNil(store.data(ScreenshotStudioSettingsKey.settings))
    }
}
