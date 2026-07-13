import CoreGraphics

/// Pure mapping between source pixels and a letterboxed canvas. Keeping this
/// outside AppKit makes zoom/crop behavior testable on mixed-scale displays.
public struct ImageCanvasTransform: Sendable, Equatable {
    public let sourceRect: CGRect
    public let viewRect: CGRect
    public init(sourceRect: CGRect, availableRect: CGRect, zoom: CGFloat = 1) {
        self.sourceRect = sourceRect
        guard sourceRect.width > 0, sourceRect.height > 0 else { viewRect = .zero; return }
        let scale = min(availableRect.width / sourceRect.width, availableRect.height / sourceRect.height) * zoom
        let size = CGSize(width: sourceRect.width * scale, height: sourceRect.height * scale)
        viewRect = CGRect(x: availableRect.midX - size.width / 2, y: availableRect.midY - size.height / 2, width: size.width, height: size.height)
    }
    public func sourcePoint(forViewPoint point: CGPoint) -> CGPoint {
        guard viewRect.width > 0, viewRect.height > 0 else { return sourceRect.origin }
        return CGPoint(x: sourceRect.minX + (point.x - viewRect.minX) * sourceRect.width / viewRect.width, y: sourceRect.minY + (point.y - viewRect.minY) * sourceRect.height / viewRect.height)
    }
    public func viewPoint(forSourcePoint point: CGPoint) -> CGPoint {
        guard sourceRect.width > 0, sourceRect.height > 0 else { return viewRect.origin }
        return CGPoint(x: viewRect.minX + (point.x - sourceRect.minX) * viewRect.width / sourceRect.width, y: viewRect.minY + (point.y - sourceRect.minY) * viewRect.height / sourceRect.height)
    }
}
