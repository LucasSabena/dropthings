import XCTest
@testable import DropThingsModules
@testable import DropThingsCore
import DropThingsPlatform

final class SnippetsSettingsTests: XCTestCase {
    func testDefaults() {
        let settings = SnippetsSettings()
        XCTAssertTrue(settings.hotkeyEnabled)
        XCTAssertEqual(settings.hotkey, GlobalHotkey.defaultSnippetsHotkey)
        XCTAssertTrue(settings.snippets.isEmpty)
    }

    func testSanitizedTrimsAndDropsEmpty() {
        let settings = SnippetsSettings.sanitized(
            hotkeyEnabled: true,
            hotkey: GlobalHotkey.defaultSnippetsHotkey,
            snippets: [
                Snippet(title: "  Hello  ", content: "world", keyword: "  Hi  "),
                Snippet(title: "", content: "   ", keyword: nil),
                Snippet(title: "Valid", content: "content", keyword: "Key Word")
            ]
        )
        XCTAssertEqual(settings.snippets.count, 2)
        XCTAssertEqual(settings.snippets[0].title, "Hello")
        XCTAssertEqual(settings.snippets[0].keyword, "hi")
        XCTAssertEqual(settings.snippets[1].keyword, "keyword")
    }

    func testSanitizedCapsCount() {
        let many = (0..<SnippetsSettings.snippetsMaxCount + 10).map { index in
            Snippet(title: "Snippet \(index)", content: "content")
        }
        let settings = SnippetsSettings.sanitized(
            hotkeyEnabled: true,
            hotkey: nil,
            snippets: many
        )
        XCTAssertEqual(settings.snippets.count, SnippetsSettings.snippetsMaxCount)
    }

    @MainActor
    func testRoundTripThroughSettingsStore() {
        let backend = InMemorySettingsBackend()
        let store = SettingsStore(backend: backend)
        let snippet = Snippet(title: "Greeting", content: "Hello, world!", keyword: "hi")
        let original = SnippetsSettings(
            hotkeyEnabled: false,
            hotkey: GlobalHotkey.defaultSnippetsHotkey,
            snippets: [snippet]
        )
        store.saveSnippetsSettings(original)
        let loaded = store.loadSnippetsSettings()
        XCTAssertEqual(loaded, original)
    }

    func testSnippetNormalization() {
        let snippet = Snippet(title: "  Title  ", content: "content", keyword: "  KEY WORD  ")
        XCTAssertEqual(snippet.title, "Title")
        XCTAssertEqual(snippet.keyword, "keyword")
        XCTAssertFalse(snippet.isEmpty)
    }

    func testEmptySnippetIsDropped() {
        let snippet = Snippet(title: "   ", content: "   ", keyword: nil)
        XCTAssertTrue(snippet.isEmpty)
    }

    func testContentPreview() {
        let long = String(repeating: "a", count: 200)
        let snippet = Snippet(title: "Long", content: long)
        XCTAssertEqual(snippet.contentPreview.count, 121)
        XCTAssertTrue(snippet.contentPreview.hasSuffix("…"))

        let multiline = Snippet(title: "Lines", content: "first\nsecond\nthird")
        XCTAssertEqual(multiline.contentPreview, "first second third")
    }
}
