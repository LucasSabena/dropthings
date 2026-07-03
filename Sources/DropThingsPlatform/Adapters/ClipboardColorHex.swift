import AppKit

/// Hex ↔ NSColor bridge for clipboard color data. Lives in Platform because it
/// adapts the AppKit `NSColor` type to a plain `String`; the module stores and
/// reasons about the hex string without touching `NSColor` at the store layer.
public enum ClipboardColorHex {
    /// `nil` if the color cannot be represented in sRGB.
    public static func hex(from color: NSColor) -> String? {
        guard let rgb = color.usingColorSpace(.sRGB) else { return nil }
        let r = Int(round(rgb.redComponent * 255))
        let g = Int(round(rgb.greenComponent * 255))
        let b = Int(round(rgb.blueComponent * 255))
        return String(format: "#%02X%02X%02X", r, g, b)
    }

    /// Parses `#RRGGBB` or `RRGGBB`. Returns `nil` on malformed input.
    public static func color(from hex: String) -> NSColor? {
        var s = hex
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let value = UInt32(s, radix: 16) else { return nil }
        let r = CGFloat((value >> 16) & 0xFF) / 255.0
        let g = CGFloat((value >> 8) & 0xFF) / 255.0
        let b = CGFloat(value & 0xFF) / 255.0
        return NSColor(srgbRed: r, green: g, blue: b, alpha: 1)
    }
}
