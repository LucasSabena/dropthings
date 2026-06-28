import XCTest
@testable import DropThingsModules

final class ColorMathTests: XCTestCase {

    // MARK: - rgbToHSL

    func testRedIsHueZero() {
        let h = ColorMath.rgbToHSL(r: 255, g: 0, b: 0)
        XCTAssertEqual(h.h, 0, accuracy: 0.001)
        XCTAssertEqual(h.s, 1.0, accuracy: 0.001)
        XCTAssertEqual(h.l, 0.5, accuracy: 0.001)
    }

    func testGreenIsHue120() {
        let h = ColorMath.rgbToHSL(r: 0, g: 255, b: 0)
        XCTAssertEqual(h.h, 120, accuracy: 0.001)
        XCTAssertEqual(h.s, 1.0, accuracy: 0.001)
        XCTAssertEqual(h.l, 0.5, accuracy: 0.001)
    }

    func testBlueIsHue240() {
        let h = ColorMath.rgbToHSL(r: 0, g: 0, b: 255)
        XCTAssertEqual(h.h, 240, accuracy: 0.001)
        XCTAssertEqual(h.s, 1.0, accuracy: 0.001)
        XCTAssertEqual(h.l, 0.5, accuracy: 0.001)
    }

    func testGrayIsAchromatic() {
        let h = ColorMath.rgbToHSL(r: 128, g: 128, b: 128)
        XCTAssertEqual(h.s, 0, accuracy: 0.001)
        XCTAssertEqual(h.h, 0, accuracy: 0.001)
        XCTAssertEqual(h.l, 128.0 / 255.0, accuracy: 0.001)
    }

    // MARK: - hslToRGB round-trip

    func testHslToRgbRoundTripsPrimaryColors() {
        let cases: [(Int, Int, Int, Double)] = [
            (255, 0, 0, 0),
            (0, 255, 0, 120),
            (0, 0, 255, 240),
        ]
        for (r, g, b, _) in cases {
            let hsl = ColorMath.rgbToHSL(r: r, g: g, b: b)
            let back = ColorMath.hslToRGB(h: hsl.h, s: hsl.s, l: hsl.l)
            XCTAssertEqual(back.r, r, accuracy: 1)
            XCTAssertEqual(back.g, g, accuracy: 1)
            XCTAssertEqual(back.b, b, accuracy: 1)
        }
    }

    // MARK: - shiftedHue

    func testShiftedHueWrapsAround() {
        XCTAssertEqual(ColorMath.shiftedHue(350, by: 20), 10, accuracy: 0.001)
        XCTAssertEqual(ColorMath.shiftedHue(10, by: -20), 350, accuracy: 0.001)
        XCTAssertEqual(ColorMath.shiftedHue(180, by: 360), 180, accuracy: 0.001)
    }

    // MARK: - lighter / darker

    func testLighterClampsToOne() {
        let hsl = ColorMath.HSL(h: 0, s: 1, l: 0.9)
        let light = ColorMath.lighter(hsl, amount: 0.5)
        XCTAssertEqual(light.l, 1.0, accuracy: 0.001)
    }

    func testDarkerClampsToZero() {
        let hsl = ColorMath.HSL(h: 0, s: 1, l: 0.1)
        let dark = ColorMath.darker(hsl, amount: 0.5)
        XCTAssertEqual(dark.l, 0.0, accuracy: 0.001)
    }

    // MARK: - saturated / desaturated

    func testSaturatedClampsToOne() {
        let hsl = ColorMath.HSL(h: 0, s: 0.9, l: 0.5)
        XCTAssertEqual(ColorMath.saturated(hsl, amount: 0.5).s, 1.0, accuracy: 0.001)
    }

    func testDesaturatedClampsToZero() {
        let hsl = ColorMath.HSL(h: 0, s: 0.1, l: 0.5)
        XCTAssertEqual(ColorMath.desaturated(hsl, amount: 0.5).s, 0.0, accuracy: 0.001)
    }

    // MARK: - complement / analogues

    func testComplementRotates180() {
        let hsl = ColorMath.HSL(h: 30, s: 0.5, l: 0.5)
        XCTAssertEqual(ColorMath.complement(hsl).h, 210, accuracy: 0.001)
    }

    func testAnaloguesAre30DegreesEitherSide() {
        let hsl = ColorMath.HSL(h: 180, s: 0.5, l: 0.5)
        let analogues = ColorMath.analogues(hsl)
        XCTAssertEqual(analogues.count, 2)
        XCTAssertEqual(analogues[0].h, 150, accuracy: 0.001)
        XCTAssertEqual(analogues[1].h, 210, accuracy: 0.001)
    }
}

final class ColorCopyFormatTests: XCTestCase {
    func testHexUppercase() {
        XCTAssertEqual(ColorCopyFormat.hex.string(r: 255, g: 99, b: 71), "#FF6347")
    }

    func testRgb() {
        XCTAssertEqual(ColorCopyFormat.rgb.string(r: 1, g: 2, b: 3), "rgb(1, 2, 3)")
    }

    func testCssLowercase() {
        XCTAssertEqual(ColorCopyFormat.css.string(r: 255, g: 99, b: 71), "#ff6347")
    }

    func testHsl() {
        // Red should be hsl(0, 100%, 50%).
        let s = ColorCopyFormat.hsl.string(r: 255, g: 0, b: 0)
        XCTAssertEqual(s, "hsl(0, 100%, 50%)")
    }

    func testSwift() {
        let s = ColorCopyFormat.swift.string(r: 255, g: 0, b: 0)
        XCTAssertTrue(s.hasPrefix("Color(hue: "))
        XCTAssertTrue(s.contains("saturation: 1.000"))
        XCTAssertTrue(s.contains("brightness: 0.500"))
    }

    func testAllCasesCoversFive() {
        XCTAssertEqual(ColorCopyFormat.allCases.map(\.label), ["HEX", "RGB", "HSL", "SwiftUI Color", "CSS"])
    }

    func testCodableRoundTrip() throws {
        let data = try JSONEncoder().encode(ColorCopyFormat.hsl)
        let decoded = try JSONDecoder().decode(ColorCopyFormat.self, from: data)
        XCTAssertEqual(decoded, .hsl)
    }
}

final class ColorPickerFavoritesTests: XCTestCase {
    func testSanitizedKeepsFavoritesUnderCap() {
        let fav1 = PickedColor(r: 1, g: 1, b: 1, isFavorite: true)
        let fav2 = PickedColor(r: 2, g: 2, b: 2, isFavorite: true)
        let others = (0..<10).map { PickedColor(r: $0, g: $0, b: $0) }
        let sanitized = ColorPickerSettings.sanitized(
            hotkeyEnabled: true,
            history: others + [fav1, fav2],
            historyLimit: 3,
            hotkey: nil
        )
        // Cap is 3, favorites (2) survive; one non-favorite slot remains.
        XCTAssertEqual(sanitized.history.count, 3)
        XCTAssertTrue(sanitized.history.contains(fav1))
        XCTAssertTrue(sanitized.history.contains(fav2))
    }

    func testSanitizedDropsFavoritesWhenCapIsZero() {
        // Cap of 1 with 2 favorites: keep the newest favorite only.
        let fav1 = PickedColor(r: 1, g: 1, b: 1, isFavorite: true)
        let fav2 = PickedColor(r: 2, g: 2, b: 2, isFavorite: true)
        let sanitized = ColorPickerSettings.sanitized(
            hotkeyEnabled: true,
            history: [fav1, fav2],
            historyLimit: 1,
            hotkey: nil
        )
        XCTAssertEqual(sanitized.history.count, 1)
    }

    func testPickedColorDecodesWithoutIsFavorite() throws {
        // A blob saved before favorites shipped must still decode.
        let json = """
        {"id":"\(UUID().uuidString)","timestamp":0,"r":10,"g":20,"b":30}
        """.data(using: .utf8)!
        let picked = try JSONDecoder().decode(PickedColor.self, from: json)
        XCTAssertFalse(picked.isFavorite)
    }
}