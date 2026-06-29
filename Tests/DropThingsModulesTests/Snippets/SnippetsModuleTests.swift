import XCTest
import AppKit
@testable import DropThingsModules
@testable import DropThingsCore
import DropThingsPlatform

@MainActor
final class SnippetsModuleTests: XCTestCase {
    private var backend: InMemorySettingsBackend!
    private var store: SettingsStore!
    private var module: SnippetsModule!

    override func setUp() {
        super.setUp()
        backend = InMemorySettingsBackend()
        store = SettingsStore(backend: backend)
        module = SnippetsModule(settings: store)
    }

    func testInitLoadsDefaults() {
        XCTAssertEqual(module.settings.snippets.count, 0)
        XCTAssertTrue(module.settings.hotkeyEnabled)
        XCTAssertEqual(module.state, .off)
    }

    func testAddSnippet() {
        module.addSnippet(title: "Hello", content: "world", keyword: "hi")
        XCTAssertEqual(module.settings.snippets.count, 1)
        XCTAssertEqual(module.settings.snippets[0].title, "Hello")
        XCTAssertEqual(module.settings.snippets[0].keyword, "hi")

        let loaded = store.loadSnippetsSettings()
        XCTAssertEqual(loaded.snippets.count, 1)
    }

    func testAddEmptySnippetIsIgnored() {
        module.addSnippet(title: "   ", content: "   ", keyword: nil)
        XCTAssertTrue(module.settings.snippets.isEmpty)
    }

    func testUpdateSnippet() {
        module.addSnippet(title: "Original", content: "content", keyword: nil)
        let id = module.settings.snippets[0].id
        module.updateSnippet(id: id, title: "Updated", content: "new content", keyword: "upd")
        XCTAssertEqual(module.settings.snippets[0].title, "Updated")
        XCTAssertEqual(module.settings.snippets[0].content, "new content")
        XCTAssertEqual(module.settings.snippets[0].keyword, "upd")
    }

    func testUpdateSnippetToEmptyDeletes() {
        module.addSnippet(title: "Original", content: "content", keyword: nil)
        let id = module.settings.snippets[0].id
        module.updateSnippet(id: id, title: "   ", content: "   ", keyword: nil)
        XCTAssertTrue(module.settings.snippets.isEmpty)
    }

    func testDeleteSnippet() {
        module.addSnippet(title: "One", content: "1", keyword: nil)
        module.addSnippet(title: "Two", content: "2", keyword: nil)
        let id = module.settings.snippets[0].id
        module.deleteSnippet(id: id)
        XCTAssertEqual(module.settings.snippets.count, 1)
        XCTAssertNotEqual(module.settings.snippets[0].id, id)
    }

    func testCopyToPasteboard() {
        let snippet = Snippet(title: "Test", content: "copied text", keyword: nil)
        module.copyToPasteboard(snippet)
        XCTAssertEqual(NSPasteboard.general.string(forType: .string), "copied text")
    }

    func testSetHotkeyEnabledPersists() {
        module.setHotkeyEnabled(false)
        XCTAssertFalse(module.settings.hotkeyEnabled)
        XCTAssertFalse(store.loadSnippetsSettings().hotkeyEnabled)
    }

    func testCommandSourceExposesSnippets() {
        module.addSnippet(title: "Greeting", content: "Hello", keyword: "hi")
        let commands = module.commands
        XCTAssertEqual(commands.count, 1)
        XCTAssertEqual(commands[0].title, "Greeting")
        XCTAssertEqual(commands[0].subtitle, "Hello")

        commands[0].action()
        XCTAssertEqual(NSPasteboard.general.string(forType: .string), "Hello")
    }
}
