import XCTest
import Carbon.HIToolbox
@testable import DropThingsPlatform

final class GlobalHotkeyDefinitionTests: XCTestCase {

    // MARK: - displayString

    func testDisplayStringForDefaultColorPicker() {
        let def = GlobalHotkey.defaultColorPickerHotkey
        // Defaults use Carbon flags (cmdKey | optionKey). displayString
        // must translate to NSEvent flags and render the symbol order
        // ⌃, ⌥, ⇧, ⌘.
        XCTAssertEqual(def.displayString, "⌥⌘C")
    }

    func testDisplayStringForDefaultShelf() {
        let def = GlobalHotkey.defaultShelfHotkey
        XCTAssertEqual(def.displayString, "⌥⌘S")
    }

    func testDisplayStringIncludesAllModifiers() {
        let def = GlobalHotkey.Definition(
            keyCode: UInt32(kVK_ANSI_K),
            modifiers: UInt32(cmdKey | optionKey | controlKey | shiftKey),
            id: 1
        )
        XCTAssertEqual(def.displayString, "⌃⌥⇧⌘K")
    }

    func testDisplayStringFallsBackToKeyCodeName() {
        let def = GlobalHotkey.Definition(
            keyCode: UInt32(kVK_ANSI_1),
            modifiers: UInt32(cmdKey),
            id: 1
        )
        XCTAssertEqual(def.displayString, "⌘1")
    }

    func testDisplayStringForUnknownKeyCode() {
        let def = GlobalHotkey.Definition(
            keyCode: 999,
            modifiers: UInt32(cmdKey),
            id: 1
        )
        XCTAssertEqual(def.displayString, "⌘Key 999")
    }

    // MARK: - nsModifiers / carbonModifiers round-trip

    func testNSModifiersForCarbonFlags() {
        let def = GlobalHotkey.Definition(
            keyCode: 0,
            modifiers: UInt32(cmdKey | optionKey),
            id: 1
        )
        XCTAssertEqual(def.nsModifiers, [.command, .option])
    }

    func testNSModifiersEmptyForNoCarbonFlags() {
        let def = GlobalHotkey.Definition(keyCode: 0, modifiers: 0, id: 1)
        XCTAssertEqual(def.nsModifiers, [])
    }

    func testCarbonModifiersFromNSEventFlags() {
        let ns: NSEvent.ModifierFlags = [.command, .option, .shift]
        let carbon = GlobalHotkey.Definition.carbonModifiers(from: ns)
        XCTAssertEqual(carbon, UInt32(cmdKey | optionKey | shiftKey))
    }

    func testCarbonModifiersIgnoresNonCarbonFlags() {
        // Caps lock, function, etc. are not part of the four Carbon
        // modifiers set the recorder accepts; carbonModifiers must not
        // encode them.
        let ns: NSEvent.ModifierFlags = [.command, .capsLock, .function]
        let carbon = GlobalHotkey.Definition.carbonModifiers(from: ns)
        XCTAssertEqual(carbon, UInt32(cmdKey))
    }

    func testCarbonModifiersRoundTripsThroughNSModifiers() {
        let original = UInt32(cmdKey | optionKey | controlKey | shiftKey)
        let def = GlobalHotkey.Definition(keyCode: 0, modifiers: original, id: 1)
        let back = GlobalHotkey.Definition.carbonModifiers(from: def.nsModifiers)
        XCTAssertEqual(back, original)
    }

    // MARK: - hasModifier

    func testHasModifierTrueForCommandOnly() {
        let def = GlobalHotkey.Definition(keyCode: 0, modifiers: UInt32(cmdKey), id: 1)
        XCTAssertTrue(def.hasModifier)
    }

    func testHasModifierFalseForBareKey() {
        let def = GlobalHotkey.Definition(keyCode: 0, modifiers: 0, id: 1)
        XCTAssertFalse(def.hasModifier)
    }

    // MARK: - Codable

    func testCodableRoundTripPreservesDefinition() throws {
        let def = GlobalHotkey.Definition(
            keyCode: UInt32(kVK_ANSI_P),
            modifiers: UInt32(cmdKey | shiftKey),
            id: 42
        )
        let data = try JSONEncoder().encode(def)
        let decoded = try JSONDecoder().decode(GlobalHotkey.Definition.self, from: data)
        XCTAssertEqual(def, decoded)
    }
}