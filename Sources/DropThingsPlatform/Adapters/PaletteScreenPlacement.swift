import CoreGraphics
import Foundation

public struct PaletteDisplayGeometry: Equatable, Sendable {
    public let id: String
    public let frame: CGRect
    public let visibleFrame: CGRect

    public init(id: String, frame: CGRect, visibleFrame: CGRect) {
        self.id = id
        self.frame = frame
        self.visibleFrame = visibleFrame
    }
}

public enum PaletteScreenPlacement {
    public static func targetDisplay(
        mouseLocation: CGPoint,
        displays: [PaletteDisplayGeometry],
        fallbackID: String?
    ) -> PaletteDisplayGeometry? {
        displays.first(where: { $0.frame.contains(mouseLocation) })
            ?? displays.first(where: { $0.id == fallbackID })
            ?? displays.first
    }

    public static func panelOrigin(size: CGSize, visibleFrame: CGRect) -> CGPoint {
        let x = visibleFrame.midX - size.width / 2
        let preferredY = visibleFrame.maxY - size.height - min(visibleFrame.height * 0.16, 140)
        let y = max(visibleFrame.minY, min(preferredY, visibleFrame.maxY - size.height))
        return CGPoint(x: x, y: y)
    }
}
