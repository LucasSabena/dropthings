import AppKit
import CoreGraphics

/// Captures a small region of the screen around a point. Used by the
/// Color Picker magnifier to render a live loupe that follows the
/// cursor. Coordinates are in global screen space (origin top-left for
/// `CGWindowListCreateImage`).
public enum ScreenCapture {
    /// Capture a square region of `size` points centered on `point`. The
    /// returned image is in the RGBA layout `PixelSampler` expects.
    public static func region(around point: CGPoint, size: CGFloat) -> CGImage? {
        let rect = CGRect(
            x: point.x - size / 2,
            y: point.y - size / 2,
            width: size,
            height: size
        )
        return Self.rect(rect)
    }

    /// Capture an arbitrary rectangle in global screen space. Returns `nil`
    /// when the rect is empty or when screen capture is not permitted.
    public static func rect(_ rect: CGRect) -> CGImage? {
        guard !rect.isEmpty, rect.width > 0, rect.height > 0 else { return nil }
        return CGWindowListCreateImage(
            rect,
            .optionOnScreenOnly,
            kCGNullWindowID,
            [.bestResolution]
        )
    }
}
