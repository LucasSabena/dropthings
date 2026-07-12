import AppKit
import CoreGraphics

/// Reads the pixel color at a specific point inside a 32-bit `CGImage`.
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
                srgbRed: CGFloat(r) / 255,
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
        guard bytesPerPixel >= 4,
              let channels = channelOffsets(for: image.bitmapInfo) else { return nil }
        let offset = y * bytesPerRow + x * bytesPerPixel
        let r = Int(bytes[offset + channels.r])
        let g = Int(bytes[offset + channels.g])
        let b = Int(bytes[offset + channels.b])
        return RGB(r: r, g: g, b: b)
    }

    private static func channelOffsets(for bitmapInfo: CGBitmapInfo) -> (r: Int, g: Int, b: Int)? {
        guard let alpha = CGImageAlphaInfo(
            rawValue: bitmapInfo.rawValue & CGBitmapInfo.alphaInfoMask.rawValue
        ) else { return nil }
        let littleEndian = bitmapInfo.intersection(.byteOrderMask) == .byteOrder32Little

        switch alpha {
        case .premultipliedFirst, .first, .noneSkipFirst:
            return littleEndian ? (2, 1, 0) : (1, 2, 3)
        case .premultipliedLast, .last, .noneSkipLast:
            return littleEndian ? (3, 2, 1) : (0, 1, 2)
        case CGImageAlphaInfo.none:
            return littleEndian ? (2, 1, 0) : (0, 1, 2)
        case .alphaOnly:
            return nil
        @unknown default:
            return nil
        }
    }
}
