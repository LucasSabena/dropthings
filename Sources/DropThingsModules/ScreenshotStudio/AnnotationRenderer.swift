import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins

/// Deterministic renderer used for both canvas previews and exported files.
/// Selection state never reaches this type, therefore handles cannot leak into
/// an export.
public enum AnnotationRenderer {
    @MainActor public static func render(document: ScreenshotDocument) -> CGImage? {
        render(source: document.source, crop: document.effectiveCrop, annotations: document.annotations)
    }

    public static func render(source: CGImage, crop: CGRect? = nil, annotations: [ScreenshotAnnotation]) -> CGImage? {
        let crop = (crop ?? CGRect(x: 0, y: 0, width: source.width, height: source.height)).integral
        guard let context = CGContext(data: nil, width: Int(crop.width), height: Int(crop.height), bitsPerComponent: 8, bytesPerRow: 0, space: source.colorSpace ?? CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.translateBy(x: -crop.minX, y: -crop.minY)
        context.draw(source, in: CGRect(x: 0, y: 0, width: source.width, height: source.height))
        for annotation in annotations { draw(annotation, in: context, crop: crop, source: source) }
        return context.makeImage()
    }

    private static func draw(_ annotation: ScreenshotAnnotation, in context: CGContext, crop: CGRect, source: CGImage) {
        let rect = annotation.bounds.cgRect
        context.saveGState(); defer { context.restoreGState() }
        context.setStrokeColor(annotation.color.cgColor); context.setLineWidth(annotation.lineWidth); context.setLineCap(.round); context.setLineJoin(.round)
        if let fill = annotation.fill { context.setFillColor(fill.cgColor) }
        switch annotation.kind {
        case .rectangle, .highlight:
            if annotation.kind == .highlight { context.setFillColor(annotation.fill?.cgColor ?? ScreenshotColor.yellow.cgColor); context.fill(rect) }
            else { if annotation.fill != nil { context.fill(rect) }; context.stroke(rect) }
        case .ellipse, .marker:
            if annotation.kind == .marker { context.setFillColor(annotation.color.cgColor); context.fillEllipse(in: rect); drawMarkerText(annotation, in: context, rect: rect) }
            else { if annotation.fill != nil { context.fillEllipse(in: rect) }; context.strokeEllipse(in: rect) }
        case .line, .arrow:
            let start = annotation.points.first?.cgPoint ?? CGPoint(x: rect.minX, y: rect.minY)
            let end = annotation.points.last?.cgPoint ?? CGPoint(x: rect.maxX, y: rect.maxY)
            context.move(to: start); context.addLine(to: end); context.strokePath()
            if annotation.kind == .arrow { drawArrowHead(from: start, to: end, in: context) }
        case .freehand:
            guard let first = annotation.points.first?.cgPoint else { return }
            context.move(to: first); annotation.points.dropFirst().forEach { context.addLine(to: $0.cgPoint) }; context.strokePath()
        case .text:
            let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: annotation.fontSize), .foregroundColor: NSColor(cgColor: annotation.color.cgColor) ?? .labelColor]
            NSAttributedString(string: annotation.text, attributes: attributes).draw(in: rect)
        case .blur, .pixelate:
            applyRedaction(annotation.kind, rect: rect, source: source, context: context)
        }
    }

    private static func drawArrowHead(from start: CGPoint, to end: CGPoint, in context: CGContext) {
        let angle = atan2(end.y - start.y, end.x - start.x); let length: CGFloat = 12
        for offset in [CGFloat.pi * 0.82, -CGFloat.pi * 0.82] { context.move(to: end); context.addLine(to: CGPoint(x: end.x + cos(angle + offset) * length, y: end.y + sin(angle + offset) * length)); context.strokePath() }
    }
    private static func drawMarkerText(_ annotation: ScreenshotAnnotation, in context: CGContext, rect: CGRect) {
        guard let number = annotation.markerNumber else { return }
        let text = NSAttributedString(string: String(number), attributes: [.font: NSFont.boldSystemFont(ofSize: rect.height * 0.55), .foregroundColor: NSColor.white])
        let size = text.size(); text.draw(at: CGPoint(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2))
    }
    private static func applyRedaction(_ kind: ScreenshotAnnotationKind, rect: CGRect, source: CGImage, context: CGContext) {
        guard let ci = CIImage(cgImage: source).cropped(to: rect) as CIImage? else { return }
        let filter: CIFilter = kind == .blur ? CIFilter.gaussianBlur() : CIFilter.pixellate()
        filter.setValue(ci, forKey: kCIInputImageKey)
        filter.setValue(kind == .blur ? 10 : 12, forKey: kCIInputRadiusKey)
        guard let output = filter.outputImage?.cropped(to: rect), let image = CIContext(options: [.cacheIntermediates: false]).createCGImage(output, from: rect) else { return }
        context.draw(image, in: rect)
    }
}
