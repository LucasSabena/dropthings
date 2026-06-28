import Foundation
import CoreGraphics
import AppKit

/// Pure mapping from an AppKit bottom-left screen point to a `CGImage`
/// pixel coordinate (top-left origin). Built from the union of
/// `NSScreen.frame` (AppKit coords) and `CGDisplayBounds` per display
/// (CG coords).
///
/// Without this mapper, a click on a secondary monitor above or to the
/// left of the primary screen maps to the wrong pixel because the overlay
/// window and the captured `CGImage` use different coordinate spaces.
public struct ScreenCoordinateMapper: Sendable {
    public struct Screen: Sendable, Equatable {
        public let appKitFrame: CGRect
        public let cgBounds: CGRect
        public init(appKitFrame: CGRect, cgBounds: CGRect) {
            self.appKitFrame = appKitFrame
            self.cgBounds = cgBounds
        }
    }

    public let screens: [Screen]
    public let imageSize: CGSize

    public init(screens: [Screen], imageSize: CGSize) {
        self.screens = screens
        self.imageSize = imageSize
    }

    /// Build the mapper from the live display list. Fails gracefully if
    /// `CGDisplayBounds` returns nonsense for some display — the resulting
    /// mapper only contains the screens we understood.
    public static func current() -> ScreenCoordinateMapper {
        let screens: [Screen] = NSScreen.screens.compactMap { screen in
            let deviceDescription = screen.deviceDescription
            guard let idNumber = deviceDescription[NSDeviceDescriptionKey(rawValue: "NSScreenNumber")] as? NSNumber else {
                return nil
            }
            let cgBounds = CGDisplayBounds(idNumber.uint32Value)
            return Screen(appKitFrame: screen.frame, cgBounds: cgBounds)
        }
        // Image is the union of CG bounds, top-left origin (CG style).
        let cgUnion = union(of: screens.map(\.cgBounds))
        return ScreenCoordinateMapper(screens: screens, imageSize: cgUnion.size)
    }

    /// Map an AppKit point to an image pixel coordinate. Falls back to
    /// `(0, 0)` when the point is not on any known screen, which only
    /// happens if a display disappeared between capture and click.
    public func imagePoint(forAppKitPoint point: CGPoint) -> CGPoint {
        guard let screen = screens.first(where: { $0.appKitFrame.contains(point) }) else {
            return .zero
        }
        // AppKit is bottom-left origin; CGDisplayBounds is top-left.
        let localAppKit = CGPoint(
            x: point.x - screen.appKitFrame.minX,
            y: point.y - screen.appKitFrame.minY
        )
        // Convert AppKit local Y (measured from screen bottom) to CG local
        // Y (measured from screen top). Then offset by the screen's CG
        // origin so we land in image coordinates.
        let cgY = screen.cgBounds.minY + (screen.appKitFrame.height - localAppKit.y)
        let cgX = screen.cgBounds.minX + localAppKit.x
        return CGPoint(x: cgX, y: cgY)
    }

    /// Union of rectangles. Empty input returns a zero rect.
    public static func union(of rects: [CGRect]) -> CGRect {
        guard let first = rects.first else { return .zero }
        var minX = first.minX, minY = first.minY
        var maxX = first.maxX, maxY = first.maxY
        for r in rects.dropFirst() {
            minX = min(minX, r.minX)
            minY = min(minY, r.minY)
            maxX = max(maxX, r.maxX)
            maxY = max(maxY, r.maxY)
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}
