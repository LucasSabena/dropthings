import Foundation
import AppKit

/// A parsed color with alpha, expressed in the canonical 0–255 sRGB space used
/// by the rest of DropThings. Pure value type; the only AppKit touch is the
/// `nsColor` bridge, kept here so callers do not reinvent it.
public struct SmartClipboardColor: Sendable, Equatable, Hashable {
    public let r: Int
    public let g: Int
    public let b: Int
    public let a: Int

    public init(r: Int, g: Int, b: Int, a: Int = 255) {
        self.r = min(max(r, 0), 255)
        self.g = min(max(g, 0), 255)
        self.b = min(max(b, 0), 255)
        self.a = min(max(a, 0), 255)
    }

    /// `#RRGGBB` when alpha is fully opaque, otherwise `#RRGGBBAA`.
    public var hex: String {
        if a == 255 {
            return String(format: "#%02X%02X%02X", r, g, b)
        }
        return String(format: "#%02X%02X%02X%02X", r, g, b, a)
    }

    public var rgbString: String {
        if a == 255 { return "rgb(\(r), \(g), \(b))" }
        return "rgba(\(r), \(g), \(b), \(formattedAlpha))"
    }

    public var cssString: String { hex.lowercased() }

    public var swiftUIColorString: String {
        if a == 255 {
            return String(format: "Color(red: %.3f, green: %.3f, blue: %.3f)", rgb(r), rgb(g), rgb(b))
        }
        return String(
            format: "Color(red: %.3f, green: %.3f, blue: %.3f, opacity: %.3f)",
            rgb(r), rgb(g), rgb(b), alpha
        )
    }

    public var hslString: String {
        let hsl = ColorMath.rgbToHSL(r: r, g: g, b: b)
        if a == 255 {
            return "hsl(\(Int(hsl.h.rounded())), \(Int((hsl.s * 100).rounded()))%, \(Int((hsl.l * 100).rounded()))%)"
        }
        return "hsla(\(Int(hsl.h.rounded())), \(Int((hsl.s * 100).rounded()))%, \(Int((hsl.l * 100).rounded()))%, \(formattedAlpha))"
    }

    /// Native pasteboard color, preserving alpha. `nil` only if the sRGB
    /// conversion fails (extremely rare for 0–255 inputs).
    public var nsColor: NSColor? {
        NSColor(
            srgbRed: CGFloat(r) / 255,
            green: CGFloat(g) / 255,
            blue: CGFloat(b) / 255,
            alpha: CGFloat(a) / 255
        )
    }

    private var alpha: Double { Double(a) / 255 }
    private var formattedAlpha: String {
        // Trim trailing zeros without losing precision for common values.
        let rounded = (alpha * 1000).rounded() / 1000
        return String(format: "%g", rounded)
    }
    private func rgb(_ v: Int) -> Double { Double(v) / 255 }

    // MARK: - Parsing

    /// Parse HEX (#RGB, #RGBA, #RRGGBB, #RRGGBBAA with or without #), `rgb()`,
    /// `rgba()`, `hsl()`, `hsla()`, and CSS named colors. Returns `nil` for
    /// anything else so callers keep general text actions.
    public static func parse(_ input: String) -> SmartClipboardColor? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let hex = parseHex(trimmed) { return hex }
        if let functional = parseFunctional(trimmed) { return functional }
        if let named = Self.namedColors[trimmed.lowercased()] { return named }
        return nil
    }

    private static func parseHex(_ s: String) -> SmartClipboardColor? {
        var hex = s
        if hex.hasPrefix("#") { hex.removeFirst() }
        guard hex.allSatisfy({ $0.isHexDigit }), !hex.isEmpty else { return nil }
        switch hex.count {
        case 3:
            return SmartClipboardColor(
                r: hexValue(hex, hex.index(hex.startIndex, offsetBy: 0)) * 17,
                g: hexValue(hex, hex.index(hex.startIndex, offsetBy: 1)) * 17,
                b: hexValue(hex, hex.index(hex.startIndex, offsetBy: 2)) * 17
            )
        case 4:
            return SmartClipboardColor(
                r: hexValue(hex, hex.index(hex.startIndex, offsetBy: 0)) * 17,
                g: hexValue(hex, hex.index(hex.startIndex, offsetBy: 1)) * 17,
                b: hexValue(hex, hex.index(hex.startIndex, offsetBy: 2)) * 17,
                a: hexValue(hex, hex.index(hex.startIndex, offsetBy: 3)) * 17
            )
        case 6:
            return SmartClipboardColor(
                r: hexValue(hex, hex.index(hex.startIndex, offsetBy: 0)) * 16 + hexValue(hex, hex.index(hex.startIndex, offsetBy: 1)),
                g: hexValue(hex, hex.index(hex.startIndex, offsetBy: 2)) * 16 + hexValue(hex, hex.index(hex.startIndex, offsetBy: 3)),
                b: hexValue(hex, hex.index(hex.startIndex, offsetBy: 4)) * 16 + hexValue(hex, hex.index(hex.startIndex, offsetBy: 5))
            )
        case 8:
            return SmartClipboardColor(
                r: hexValue(hex, hex.index(hex.startIndex, offsetBy: 0)) * 16 + hexValue(hex, hex.index(hex.startIndex, offsetBy: 1)),
                g: hexValue(hex, hex.index(hex.startIndex, offsetBy: 2)) * 16 + hexValue(hex, hex.index(hex.startIndex, offsetBy: 3)),
                b: hexValue(hex, hex.index(hex.startIndex, offsetBy: 4)) * 16 + hexValue(hex, hex.index(hex.startIndex, offsetBy: 5)),
                a: hexValue(hex, hex.index(hex.startIndex, offsetBy: 6)) * 16 + hexValue(hex, hex.index(hex.startIndex, offsetBy: 7))
            )
        default:
            return nil
        }
    }

    private static func hexValue(_ s: String, _ index: String.Index) -> Int {
        Int(String(s[index]), radix: 16) ?? 0
    }

    private static func parseFunctional(_ s: String) -> SmartClipboardColor? {
        guard let open = s.firstIndex(of: "("), let close = s.lastIndex(of: ")") else { return nil }
        let name = String(s[..<open]).lowercased()
        let inner = String(s[s.index(after: open)..<close])
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        switch name {
        case "rgb":
            guard inner.count == 3 else { return nil }
            guard let r = Int(inner[0]), let g = Int(inner[1]), let b = Int(inner[2]) else { return nil }
            return SmartClipboardColor(r: r, g: g, b: b)
        case "rgba":
            guard inner.count == 4 else { return nil }
            guard let r = Int(inner[0]), let g = Int(inner[1]), let b = Int(inner[2]),
                  let alpha = Double(inner[3]) else { return nil }
            return SmartClipboardColor(r: r, g: g, b: b, a: Int((alpha * 255).rounded()))
        case "hsl":
            guard inner.count == 3 else { return nil }
            return fromHSL(inner)
        case "hsla":
            guard inner.count == 4 else { return nil }
            guard let alpha = Double(inner[3]) else { return nil }
            return fromHSL(Array(inner.prefix(3)))?.with(alpha: Int((alpha * 255).rounded()))
        default:
            return nil
        }
    }

    private static func fromHSL(_ parts: [String]) -> SmartClipboardColor? {
        guard parts.count == 3,
              let h = parseHue(parts[0]),
              let s = parsePercent(parts[1]),
              let l = parsePercent(parts[2]) else { return nil }
        let rgb = ColorMath.hslToRGB(h: h, s: s, l: l)
        return SmartClipboardColor(r: rgb.r, g: rgb.g, b: rgb.b)
    }

    private static func parseHue(_ s: String) -> Double? {
        let value = s.replacingOccurrences(of: "deg", with: "")
        return Double(value).map { $0.truncatingRemainder(dividingBy: 360) }
    }

    private static func parsePercent(_ s: String) -> Double? {
        let value = s.replacingOccurrences(of: "%", with: "")
        guard let n = Double(value) else { return nil }
        return min(max(n / 100, 0), 1)
    }

    private func with(alpha: Int) -> SmartClipboardColor {
        SmartClipboardColor(r: r, g: g, b: b, a: alpha)
    }

    /// A small subset of CSS named colors sufficient for design copy/paste.
    /// Anything not here falls back to text actions.
    private static let namedColors: [String: SmartClipboardColor] = {
        var map: [String: SmartClipboardColor] = [:]
        let basic: [(String, Int, Int, Int)] = [
            ("black", 0, 0, 0), ("white", 255, 255, 255),
            ("red", 255, 0, 0), ("lime", 0, 255, 0), ("blue", 0, 0, 255),
            ("yellow", 255, 255, 0), ("cyan", 0, 255, 255), ("magenta", 255, 0, 255),
            ("silver", 192, 192, 192), ("gray", 128, 128, 128), ("grey", 128, 128, 128),
            ("maroon", 128, 0, 0), ("olive", 128, 128, 0), ("green", 0, 128, 0),
            ("purple", 128, 0, 128), ("teal", 0, 128, 128), ("navy", 0, 0, 128),
            ("orange", 255, 165, 0), ("pink", 255, 192, 203), ("brown", 165, 42, 42),
            ("transparent", 0, 0, 0)
        ]
        for (name, r, g, b) in basic {
            let a = name == "transparent" ? 0 : 255
            map[name] = SmartClipboardColor(r: r, g: g, b: b, a: a)
        }
        return map
    }()
}