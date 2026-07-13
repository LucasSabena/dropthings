import XCTest
@testable import DropThingsModules
@testable import DropThingsCore
import DropThingsPlatform
import Carbon.HIToolbox

final class MarkdownViewerSettingsTests: XCTestCase {

    func testDefaults() {
        let settings = MarkdownViewerSettings()
        XCTAssertTrue(settings.hotkeyEnabled)
        XCTAssertEqual(settings.hotkey, GlobalHotkey.defaultMarkdownViewerHotkey)
        XCTAssertEqual(settings.theme, .auto)
        XCTAssertEqual(settings.fontSize, 14)
        XCTAssertEqual(settings.layout, .split)
        XCTAssertFalse(settings.showLineNumbers)
        XCTAssertFalse(settings.openFinderSelectionWithHotkey)
        XCTAssertTrue(settings.recentFiles.isEmpty)
    }

    func testDefaultHotkeyIsOptionCommandM() {
        XCTAssertEqual(GlobalHotkey.defaultMarkdownViewerHotkey?.displayString, "⌥⌘M")
        XCTAssertEqual(GlobalHotkey.defaultMarkdownViewerHotkey?.id, 501)
    }

    func testSanitizedClampsFontSize() {
        let tooSmall = MarkdownViewerSettings.sanitized(
            hotkeyEnabled: true,
            hotkey: nil,
            theme: .light,
            fontSize: 4,
            layout: .split,
            showLineNumbers: false,
            openFinderSelectionWithHotkey: false,
            recentFiles: []
        )
        XCTAssertEqual(tooSmall.fontSize, MarkdownViewerSettings.fontSizeMin)

        let tooLarge = MarkdownViewerSettings.sanitized(
            hotkeyEnabled: true,
            hotkey: nil,
            theme: .dark,
            fontSize: 99,
            layout: .preview,
            showLineNumbers: true,
            openFinderSelectionWithHotkey: true,
            recentFiles: []
        )
        XCTAssertEqual(tooLarge.fontSize, MarkdownViewerSettings.fontSizeMax)
        XCTAssertTrue(tooLarge.openFinderSelectionWithHotkey)
    }

    func testSanitizedCapsRecentFiles() {
        let many = (0..<(MarkdownViewerSettings.recentFilesMax + 5)).map { index in
            MarkdownRecentFile(url: URL(fileURLWithPath: "/tmp/file\(index).md"),
                               name: "file\(index).md")
        }
        let settings = MarkdownViewerSettings.sanitized(
            hotkeyEnabled: true,
            hotkey: nil,
            theme: .auto,
            fontSize: 14,
            layout: .split,
            showLineNumbers: false,
            openFinderSelectionWithHotkey: false,
            recentFiles: many
        )
        XCTAssertEqual(settings.recentFiles.count, MarkdownViewerSettings.recentFilesMax)
    }

    @MainActor
    func testRoundTripThroughSettingsStore() {
        let backend = InMemorySettingsBackend()
        let store = SettingsStore(backend: backend)
        let file = MarkdownRecentFile(url: URL(fileURLWithPath: "/tmp/notes.md"), name: "notes.md")
        let original = MarkdownViewerSettings(
            hotkeyEnabled: false,
            hotkey: GlobalHotkey.defaultMarkdownViewerHotkey,
            theme: .dark,
            fontSize: 18,
            layout: .preview,
            showLineNumbers: true,
            openFinderSelectionWithHotkey: true,
            recentFiles: [file]
        )
        store.saveMarkdownViewerSettings(original)
        let loaded = store.loadMarkdownViewerSettings()
        XCTAssertEqual(loaded, original)
    }

    @MainActor
    func testMissingFieldsDecodeToDefaults() {
        let backend = InMemorySettingsBackend()
        let store = SettingsStore(backend: backend)
        let partial = try! JSONEncoder().encode(["hotkeyEnabled": false])
        store.setData(partial, MarkdownViewerSettingsKey.settings)

        let loaded = store.loadMarkdownViewerSettings()
        XCTAssertFalse(loaded.hotkeyEnabled)
        XCTAssertEqual(loaded.hotkey, GlobalHotkey.defaultMarkdownViewerHotkey)
        XCTAssertEqual(loaded.theme, .auto)
        XCTAssertEqual(loaded.fontSize, 14)
        XCTAssertEqual(loaded.layout, .split)
        XCTAssertFalse(loaded.showLineNumbers)
        XCTAssertFalse(loaded.openFinderSelectionWithHotkey)
        XCTAssertTrue(loaded.recentFiles.isEmpty)
    }

    @MainActor
    func testCorruptedBlobFallsBackToDefaults() {
        let backend = InMemorySettingsBackend()
        let store = SettingsStore(backend: backend)
        let bad = "{not valid json".data(using: .utf8)!
        store.setData(bad, MarkdownViewerSettingsKey.settings)

        let loaded = store.loadMarkdownViewerSettings()
        XCTAssertEqual(loaded, MarkdownViewerSettings())
    }

    func testRecentFileDecodesWithoutNameAndDate() {
        // Older blobs may not have `name` or `lastOpened`; the decoder must
        // synthesize them from the URL and `Date()` respectively. The URL is
        // stored as its absoluteString (file URL), matching what
        // JSONEncoder produces for a `URL(fileURLWithPath:)`.
        let json = """
        {"id":"00000000-0000-0000-0000-000000000000","url":"file:///tmp/legacy.md"}
        """.data(using: .utf8)!
        let file = try! JSONDecoder().decode(MarkdownRecentFile.self, from: json)
        XCTAssertEqual(file.url, URL(fileURLWithPath: "/tmp/legacy.md"))
        XCTAssertEqual(file.name, "legacy.md")
    }
}
