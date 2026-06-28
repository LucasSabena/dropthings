import AppKit
import CoreGraphics

/// Reads the pixel color at a specific point inside a `CGImage`. The image
/// is assumed to be 8 bits per channel, RGBA, premultiplied last (the
/// layout `CGWindowListCreateImage` produces).
public enum PixelSampler {
    public struct RGB: Equatable, Sendable, Hashable {
        public let r: Int
        public let g: Int
        public let b: Int

        public init(r: Int, g: Int, b: Int) {
            self.r = r
            self.g = g
            self.b = b
        }

        public var hex: String {
            String(format: "#%02X%02X%02X", r, g, b)
        }

        public var rgbString: String {
            "rgb(\(r), \(g), \(b))"
        }

        public var nsColor: NSColor {
            NSColor(
                calibratedRed: CGFloat(r) / 255,
                green: CGFloat(g) / 255,
                blue: CGFloat(b) / 255,
                alpha: 1.0
            )
        }
    }

    /// Sample the pixel at (x, y). Coordinates are in image space (origin
    /// bottom-left to match `CGImage`).
    public static func sample(at point: CGPoint, in image: CGImage) -> RGB? {
        let width = image.width
        let height = image.height
        guard width > 0, height > 0 else { return nil }
        let x = Int(point.x.rounded())
        let y = Int(point.y.rounded())
        guard x >= 0, x < width, y >= 0, y < height else { return nil }

        guard let provider = image.dataProvider,
              let data = provider.data,
              let bytes = CFDataGetBytePtr(data) else {
            return nil
        }

        let bytesPerRow = image.bytesPerRow
        let bytesPerPixel = image.bitsPerPixel / 8
        let offset = y * bytesPerRow + x * bytesPerPixel
        let r = Int(bytes[offset])
        let g = Int(bytes[offset + 1])
        let b = Int(bytes[offset + 2])
        return RGB(r: r, g: g, b: b)
    }
}
