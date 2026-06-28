import Foundation

/// The clipboard format the Color Picker copies after a pick. Persisted
/// in `ColorPickerSettings.copyFormat` so the user picks once and the
/// choice survives relaunches.
public enum ColorCopyFormat: String, Sendable, Codable, Hashable, CaseIterable, Identifiable {
    case hex, rgb, hsl, swift, css
    public var id: String { rawValue }

    /// Human label shown in the settings picker.
    public var label: String {
        switch self {
        case .hex:   return "HEX"
        case .rgb:   return "RGB"
        case .hsl:   return "HSL"
        case .swift: return "SwiftUI Color"
        case .css:   return "CSS"
        }
    }

    /// Render `r,g,b` (0–255) into this format.
    public func string(r: Int, g: Int, b: Int) -> String {
        switch self {
        case .hex:   return String(format: "#%02X%02X%02X", r, g, b)
        case .rgb:   return "rgb(\(r), \(g), \(b))"
        case .hsl:
            let h = ColorMath.rgbToHSL(r: r, g: g, b: b)
            return "hsl(\(Int(h.h.rounded())), \(Int((h.s * 100).rounded()))%, \(Int((h.l * 100).rounded()))%)"
        case .swift:
            let h = ColorMath.rgbToHSL(r: r, g: g, b: b)
            return String(
                format: "Color(hue: %.3f, saturation: %.3f, brightness: %.3f)",
                h.h / 360.0, h.s, h.l
            )
        case .css:
            return String(format: "#%02x%02x%02x", r, g, b)
        }
    }
}

/// Pure color math. No AppKit/Color dependencies, fully unit-testable.
/// All functions take and return 0–255 RGB or 0–360 / 0–1 HSL.
public enum ColorMath {
    public struct HSL: Equatable, Sendable, Hashable {
        public let h: Double   // 0...360
        public let s: Double   // 0...1
        public let l: Double   // 0...1
        public init(h: Double, s: Double, l: Double) {
            self.h = h
            self.s = s
            self.l = l
        }
    }

    /// Convert 0–255 RGB to HSL (h in 0–360, s/l in 0–1). Deterministic,
    /// no floating-point noise beyond the canonical algorithm.
    public static func rgbToHSL(r: Int, g: Int, b: Int) -> HSL {
        let rf = Double(r) / 255
        let gf = Double(g) / 255
        let bf = Double(b) / 255
        let max = Swift.max(rf, gf, bf)
        let min = Swift.min(rf, gf, bf)
        let l = (max + min) / 2
        let d = max - min
        let s: Double
        if d == 0 {
            s = 0
        } else {
            s = d / (1 - abs(2 * l - 1))
        }
        var h: Double
        if d == 0 {
            h = 0
        } else if max == rf {
            h = 60 * (((gf - bf) / d).truncatingRemainder(dividingBy: 6))
        } else if max == gf {
            h = 60 * (((bf - rf) / d) + 2)
        } else {
            h = 60 * (((rf - gf) / d) + 4)
        }
        if h < 0 { h += 360 }
        return HSL(h: h, s: s, l: l)
    }

    /// Convert HSL back to 0–255 RGB. Inverse of `rgbToHSL`; round-trips
    /// within ±1 due to integer RGB precision.
    public static func hslToRGB(h: Double, s: Double, l: Double) -> (r: Int, g: Int, b: Int) {
        let c = (1 - abs(2 * l - 1)) * s
        let hp = h / 60
        let x = c * (1 - abs(hp.truncatingRemainder(dividingBy: 2) - 1))
        let m = l - c / 2
        let r1: Double, g1: Double, b1: Double
        switch hp {
        case 0..<1:    r1 = c; g1 = x; b1 = 0
        case 1..<2:    r1 = x; g1 = c; b1 = 0
        case 2..<3:    r1 = 0; g1 = c; b1 = x
        case 3..<4:    r1 = 0; g1 = x; b1 = c
        case 4..<5:    r1 = x; g1 = 0; b1 = c
        default:       r1 = c; g1 = 0; b1 = x
        }
        let toByte = { (v: Double) -> Int in
            Int(((v + m) * 255).rounded())
        }
        return (toByte(r1), toByte(g1), toByte(b1))
    }

    /// A hue shifted by `degrees` and wrapped to 0–360.
    public static func shiftedHue(_ h: Double, by degrees: Double) -> Double {
        var v = h + degrees
        v = v.truncatingRemainder(dividingBy: 360)
        if v < 0 { v += 360 }
        return v
    }

    /// A lighter shade: same hue and saturation, lightness raised by
    /// `amount` (clamped to 1).
    public static func lighter(_ hsl: HSL, amount: Double) -> HSL {
        HSL(h: hsl.h, s: hsl.s, l: Swift.min(1, hsl.l + amount))
    }

    /// A darker shade.
    public static func darker(_ hsl: HSL, amount: Double) -> HSL {
        HSL(h: hsl.h, s: hsl.s, l: Swift.max(0, hsl.l - amount))
    }

    /// More saturated.
    public static func saturated(_ hsl: HSL, amount: Double) -> HSL {
        HSL(h: hsl.h, s: Swift.min(1, hsl.s + amount), l: hsl.l)
    }

    /// Less saturated, toward gray.
    public static func desaturated(_ hsl: HSL, amount: Double) -> HSL {
        HSL(h: hsl.h, s: Swift.max(0, hsl.s - amount), l: hsl.l)
    }

    /// Complement: hue rotated 180°.
    public static func complement(_ hsl: HSL) -> HSL {
        HSL(h: shiftedHue(hsl.h, by: 180), s: hsl.s, l: hsl.l)
    }

    /// Two analogous colors, ±30° on the hue wheel.
    public static func analogues(_ hsl: HSL) -> [HSL] {
        [
            HSL(h: shiftedHue(hsl.h, by: -30), s: hsl.s, l: hsl.l),
            HSL(h: shiftedHue(hsl.h, by:  30), s: hsl.s, l: hsl.l)
        ]
    }
}