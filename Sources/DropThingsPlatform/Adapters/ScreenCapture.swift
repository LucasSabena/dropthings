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
        return CGWindowListCreateImage(
            rect,
            .optionOnScreenOnly,
            kCGNullWindowID,
            [.bestResolution]
        )
    }
}