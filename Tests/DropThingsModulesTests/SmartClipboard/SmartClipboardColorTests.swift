import XCTest
@testable import DropThingsModules

final class SmartClipboardColorTests: XCTestCase {
    func testParseHex6() {
        let c = SmartClipboardColor.parse("#FF8040")
        XCTAssertEqual(c?.r, 255)
        XCTAssertEqual(c?.g, 128)
        XCTAssertEqual(c?.b, 64)
        XCTAssertEqual(c?.a, 255)
    }

    func testParseHex3Expands() {
        let c = SmartClipboardColor.parse("#F00")
        XCTAssertEqual(c?.r, 255)
        XCTAssertEqual(c?.g, 0)
        XCTAssertEqual(c?.b, 0)
    }

    func testParseHex8PreservesAlpha() {
        let c = SmartClipboardColor.parse("#FF000080")
        XCTAssertEqual(c?.a, 128)
        XCTAssertEqual(c?.hex, "#FF000080")
    }

    func testParseHexWithoutHash() {
        let c = SmartClipboardColor.parse("00ff00")
        XCTAssertEqual(c?.g, 255)
    }

    func testParseRGB() {
        let c = SmartClipboardColor.parse("rgb(10, 20, 30)")
        XCTAssertEqual(c?.r, 10)
        XCTAssertEqual(c?.g, 20)
        XCTAssertEqual(c?.b, 30)
    }

    func testParseRGBA() {
        let c = SmartClipboardColor.parse("rgba(255, 0, 0, 0.5)")
        XCTAssertEqual(c?.a, 128)
    }

    func testParseHSLRed() {
        let c = SmartClipboardColor.parse("hsl(0, 100%, 50%)")
        XCTAssertEqual(c?.r, 255)
        XCTAssertEqual(c?.g, 0)
        XCTAssertEqual(c?.b, 0)
    }

    func testParseHSLA() {
        let c = SmartClipboardColor.parse("hsla(120, 100%, 50%, 0.25)")
        XCTAssertNotNil(c)
        XCTAssertNotEqual(c?.a, 255)
    }

    func testParseNamedColors() {
        XCTAssertEqual(SmartClipboardColor.parse("red")?.r, 255)
        XCTAssertEqual(SmartClipboardColor.parse("WHITE")?.r, 255)
        XCTAssertEqual(SmartClipboardColor.parse("transparent")?.a, 0)
    }

    func testInvalidReturnsNil() {
        XCTAssertNil(SmartClipboardColor.parse(""))
        XCTAssertNil(SmartClipboardColor.parse("not a color"))
        XCTAssertNil(SmartClipboardColor.parse("#GGG"))
    }

    func testFormatStringsPreserveAlpha() {
        let opaque = SmartClipboardColor(r: 255, g: 0, b: 0)
        XCTAssertEqual(opaque.hex, "#FF0000")
        XCTAssertEqual(opaque.rgbString, "rgb(255, 0, 0)")
        XCTAssertEqual(opaque.hslString, "hsl(0, 100%, 50%)")
        XCTAssertEqual(opaque.cssString, "#ff0000")

        let alpha = SmartClipboardColor(r: 255, g: 0, b: 0, a: 128)
        XCTAssertEqual(alpha.hex, "#FF000080")
        XCTAssertTrue(alpha.rgbString.contains("rgba"))
        XCTAssertTrue(alpha.hslString.contains("hsla"))
        XCTAssertTrue(alpha.swiftUIColorString.contains("opacity"))
    }

    func testSwiftUIColorStringFormat() {
        let c = SmartClipboardColor(r: 0, g: 128, b: 255)
        let s = c.swiftUIColorString
        XCTAssertTrue(s.contains("Color(red:"))
        XCTAssertTrue(s.contains("green"))
    }
}