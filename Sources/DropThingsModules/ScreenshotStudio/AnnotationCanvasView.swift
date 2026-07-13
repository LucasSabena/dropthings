import AppKit

/// AppKit canvas for precise pointer interaction. The document remains the
/// source of truth; this view contains only tool and pointer state.
@MainActor
final class AnnotationCanvasView: NSView {
    enum Tool: Int, CaseIterable {
        case select, crop, arrow, line, rectangle, ellipse, freehand, text, highlight, marker, blur, pixelate
        var annotationKind: ScreenshotAnnotationKind? {
            switch self {
            case .select, .crop: return nil
            case .arrow: return .arrow; case .line: return .line; case .rectangle: return .rectangle
            case .ellipse: return .ellipse; case .freehand: return .freehand; case .text: return .text
            case .highlight: return .highlight; case .marker: return .marker; case .blur: return .blur; case .pixelate: return .pixelate
            }
        }
    }

    let document: ScreenshotDocument
    var tool: Tool = .select { didSet { draft = nil; needsDisplay = true } }
    var zoom: CGFloat = 1 { didSet { zoom = min(max(zoom, 0.1), 8); needsDisplay = true } }
    private var start: CGPoint?
    private var draft: ScreenshotAnnotation?
    private var textField: NSTextField?
    private var markerNumber = 1
    private var movingAnnotation: ScreenshotAnnotation?

    init(document: ScreenshotDocument) { self.document = document; super.init(frame: .zero); wantsLayer = true; layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor }
    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }
    override var acceptsFirstResponder: Bool { true }

    private var transform: ImageCanvasTransform { ImageCanvasTransform(sourceRect: document.effectiveCrop, availableRect: bounds, zoom: zoom) }
    private var renderedRect: CGRect { transform.viewRect }
    private func sourcePoint(_ point: CGPoint) -> CGPoint { transform.sourcePoint(forViewPoint: point) }
    private func sourceRect(from start: CGPoint, to end: CGPoint) -> CGRect {
        CGRect(x: start.x, y: start.y, width: end.x - start.x, height: end.y - start.y).standardized
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.windowBackgroundColor.setFill(); bounds.fill()
        let rect = renderedRect
        NSColor.gridColor.setFill(); NSBezierPath(rect: rect).fill()
        if let image = AnnotationRenderer.render(document: document) {
            NSGraphicsContext.current?.cgContext.saveGState()
            NSGraphicsContext.current?.cgContext.interpolationQuality = .high
            NSGraphicsContext.current?.cgContext.draw(image, in: rect)
            NSGraphicsContext.current?.cgContext.restoreGState()
        }
        if let draft { drawDraft(draft, in: NSGraphicsContext.current!.cgContext) }
    }

    private func drawDraft(_ annotation: ScreenshotAnnotation, in context: CGContext) {
        let rect = renderedRect
        let crop = document.effectiveCrop
        func view(_ point: CGPoint) -> CGPoint { CGPoint(x: rect.minX + (point.x - crop.minX) * zoom, y: rect.minY + (point.y - crop.minY) * zoom) }
        let sourceRect = annotation.bounds.cgRect
        let viewRect = CGRect(origin: view(sourceRect.origin), size: CGSize(width: sourceRect.width * zoom, height: sourceRect.height * zoom))
        context.saveGState(); defer { context.restoreGState() }
        context.setStrokeColor(NSColor.controlAccentColor.cgColor); context.setLineWidth(1); context.setLineDash(phase: 0, lengths: [4, 3])
        context.stroke(viewRect)
    }

    override func mouseDown(with event: NSEvent) {
        let point = sourcePoint(convert(event.locationInWindow, from: nil))
        guard document.effectiveCrop.contains(point) else { return }
        if tool == .select {
            let selected = document.annotations.last(where: { $0.bounds.cgRect.contains(point) })
            document.select(selected?.id)
            movingAnnotation = selected
            start = point
            needsDisplay = true
            return
        }
        start = point
        if tool == .text { presentTextEditor(at: point); return }
        updateDraft(at: point)
    }
    override func mouseDragged(with event: NSEvent) {
        guard let start else { return }
        let end = sourcePoint(convert(event.locationInWindow, from: nil))
        if tool == .select, let movingAnnotation {
            let delta = CGPoint(x: end.x - start.x, y: end.y - start.y)
            var moved = movingAnnotation
            let bounds = moved.bounds.cgRect.offsetBy(dx: delta.x, dy: delta.y)
            moved.bounds = ScreenshotRect(bounds)
            moved.points = movingAnnotation.points.map { ScreenshotPoint(CGPoint(x: $0.x + delta.x, y: $0.y + delta.y)) }
            draft = moved; needsDisplay = true; return
        }
        updateDraft(at: end)
    }
    override func mouseUp(with event: NSEvent) {
        guard let start else { return }; let end = sourcePoint(convert(event.locationInWindow, from: nil)); defer { self.start = nil; draft = nil; needsDisplay = true }
        if tool == .select { if let draft { document.replace(draft) }; movingAnnotation = nil; return }
        if tool == .crop { document.setCrop(sourceRect(from: start, to: end)); return }
        updateDraft(at: end); if let draft { document.add(draft) }
    }
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 51 || event.keyCode == 117 { document.deleteSelected(); needsDisplay = true }
        else { super.keyDown(with: event) }
    }

    private func updateDraft(at end: CGPoint) {
        guard let start, let kind = tool.annotationKind else { return }
        let bounds = sourceRect(from: start, to: end)
        let points = kind == .freehand ? (draft?.points.map(\.cgPoint) ?? [start]) + [end] : [start, end]
        draft = ScreenshotAnnotation(kind: kind, bounds: bounds, points: points, color: kind == .highlight ? .yellow : .red, fill: kind == .highlight ? .yellow : nil, markerNumber: kind == .marker ? markerNumber : nil)
        needsDisplay = true
    }

    private func presentTextEditor(at point: CGPoint) {
        textField?.removeFromSuperview()
        let viewPoint = CGPoint(x: renderedRect.minX + (point.x - document.effectiveCrop.minX) * zoom, y: renderedRect.minY + (point.y - document.effectiveCrop.minY) * zoom)
        let field = NSTextField(frame: CGRect(x: viewPoint.x, y: viewPoint.y, width: 180, height: 28))
        field.stringValue = "Text"; field.font = .systemFont(ofSize: 18); field.target = self; field.action = #selector(commitText(_:)); addSubview(field); textField = field; window?.makeFirstResponder(field)
    }
    @objc private func commitText(_ sender: NSTextField) {
        guard let start else { sender.removeFromSuperview(); return }
        document.add(ScreenshotAnnotation(kind: .text, bounds: CGRect(x: start.x, y: start.y, width: max(1, sender.bounds.width / zoom), height: max(1, sender.bounds.height / zoom)), text: sender.stringValue))
        sender.removeFromSuperview(); textField = nil; self.start = nil; needsDisplay = true
    }
}
