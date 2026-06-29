import XCTest
@testable import DropThingsModules
@testable import DropThingsCore

final class CommandPaletteFilteringTests: XCTestCase {
    @MainActor
    func testFilterByTitle() {
        let commands = sampleCommands
        let filtered = CommandPaletteFilter.filter(commands, query: "color")
        XCTAssertEqual(filtered.map(\.id), ["pick-color"])
    }

    @MainActor
    func testFilterBySubtitle() {
        let commands = sampleCommands
        let filtered = CommandPaletteFilter.filter(commands, query: "file")
        XCTAssertEqual(filtered.map(\.id), ["open-shelf"])
    }

    @MainActor
    func testEmptyQueryReturnsAll() {
        let commands = sampleCommands
        let filtered = CommandPaletteFilter.filter(commands, query: "")
        XCTAssertEqual(filtered.map(\.id), ["open-shelf", "pick-color", "keep-awake"])
    }

    @MainActor
    func testWhitespaceQueryReturnsAll() {
        let commands = sampleCommands
        let filtered = CommandPaletteFilter.filter(commands, query: "   ")
        XCTAssertEqual(filtered.map(\.id), ["open-shelf", "pick-color", "keep-awake"])
    }

    @MainActor
    func testCaseInsensitiveFilter() {
        let commands = sampleCommands
        let filtered = CommandPaletteFilter.filter(commands, query: "SHELF")
        XCTAssertEqual(filtered.map(\.id), ["open-shelf"])
    }

    @MainActor
    func testNoMatchReturnsEmpty() {
        let commands = sampleCommands
        let filtered = CommandPaletteFilter.filter(commands, query: "foobar")
        XCTAssertTrue(filtered.isEmpty)
    }

    @MainActor
    private var sampleCommands: [CommandDescriptor] {
        [
            CommandDescriptor(id: "open-shelf", title: "Open Shelf", subtitle: "File Shelf", iconName: "tray", action: {}),
            CommandDescriptor(id: "pick-color", title: "Pick Color", subtitle: "Color Picker", iconName: "eyedropper", action: {}),
            CommandDescriptor(id: "keep-awake", title: "Keep Awake", subtitle: "Toggle sleep prevention", iconName: "moon", action: {})
        ]
    }
}
