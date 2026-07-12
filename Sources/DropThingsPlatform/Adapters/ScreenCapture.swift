import AppKit
import CoreGraphics

/// Captures screen regions while keeping the AppKit/Core Graphics coordinate
/// boundary explicit.
public enum ScreenCapture {
    /// Capture a square region centered on an AppKit global point (bottom-left
    /// origin), such as `NSEvent.mouseLocation`.
    public static func region(aroundAppKitPoint point: CGPoint, size: CGFloat) -> CGImage? {
        let appKitRect = CGRect(
            x: point.x - size / 2,
            y: point.y - size / 2,
            width: size,
            height: size
        )
        guard let captureRect = ScreenCoordinateMapper.current().cgRect(forAppKitRect: appKitRect) else {
            return nil
        }
        return Self.rect(captureRect)
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
