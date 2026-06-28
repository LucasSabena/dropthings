import AppKit
import CoreGraphics
import os

/// Wraps `CGWindowListCreateImage` to capture the visible screen content.
/// Requires Screen Recording permission on macOS 10.15+ when capturing
/// other apps' windows.
@MainActor
public final class ScreenCapture {
    public enum CaptureError: Error, Equatable {
        case noPermission
        case captureFailed
    }

    public init() {}

    /// Capture the union of all on-screen windows (a "screen shot"). The
    /// returned image has the size of the user's main display unless
    /// `rect` is given, in which case it is clipped to that rect.
    public func captureScreen(rect: CGRect? = nil) throws -> CGImage {
        let bounds = rect ?? CGRect.infinite
        let options: CGWindowListOption = [.optionOnScreenOnly]
        guard let image = CGWindowListCreateImage(
            bounds,
            options,
            kCGNullWindowID,
            [.bestResolution]
        ) else {
            throw CaptureError.captureFailed
        }
        return image
    }

    /// Capture a small region around `point` (in screen coordinates). The
    /// returned image is `size` wide and tall, with the point at the center.
    public func captureRegion(center point: CGPoint, size: CGSize = CGSize(width: 200, height: 200)) throws -> CGImage {
        let origin = CGPoint(
            x: point.x - size.width / 2,
            y: point.y - size.height / 2
        )
        let rect = CGRect(origin: origin, size: size)
        return try captureScreen(rect: rect)
    }
}

private extension CGRect {
    static let infinite = CGRect(
        x: -CGFloat.greatestFiniteMagnitude / 2,
        y: -CGFloat.greatestFiniteMagnitude / 2,
        width: CGFloat.greatestFiniteMagnitude,
        height: CGFloat.greatestFiniteMagnitude
    )
}
