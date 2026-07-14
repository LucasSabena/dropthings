import AppKit

/// A pixel-accurate editor surface. The view is always the exact size of the
/// current crop; NSScrollView is the only owner of zoom and panning.
@MainActor
final class AnnotationCanvasView: NSView, NSTextFieldDelegate {
    enum Tool: CaseIterable {
        case select, crop, arrow, line, rectangle, ellipse
        case freehand, text, highlight, marker, blur, pixelate

        var label: String {
            switch self {
            case .select: "Select"
            case .crop: "Crop"
            case .arrow: "Arrow"
            case .line: "Line"
            case .rectangle: "Rectangle"
            case .ellipse: "Ellipse"
            case .freehand: "Pencil"
            case .text: "Text"
            case .highlight: "Highlight"
            case .marker: "Counter"
            case .blur: "Blur"
            case .pixelate: "Pixelate"
            }
        }

        var symbol: String {
            switch self {
            case .select: "cursorarrow"
            case .crop: "crop"
            case .arrow: "arrow.up.right"
            case .line: "line.diagonal"
            case .rectangle: "rectangle"
            case .ellipse: "circle"
            case .freehand: "pencil"
            case .text: "textformat"
            case .highlight: "highlighter"
            case .marker: "1.circle"
            case .blur: "drop"
            case .pixelate: "square.grid.3x3.fill"
            }
        }

        var annotationKind: ScreenshotAnnotationKind? {
            switch self {
            case .select, .crop: nil
            case .arrow: .arrow
            case .line: .line
            case .rectangle: .rectangle
            case .ellipse: .ellipse
            case .freehand: .freehand
            case .text: .text
            case .highlight: .highlight
            case .marker: .marker
            case .blur: .blur
            case .pixelate: .pixelate
            }
        }
    }

    enum Command { case undo, redo, copy, save, zoomIn, zoomOut, zoomFit }

    let document: ScreenshotDocument
    var tool: Tool = .select { didSet { cancelInteraction(); updateCursor(); onToolChanged?(tool); needsDisplay = true } }
    var drawingColor = ScreenshotColor.red
    var lineWidth: CGFloat = 3
    var onCropChanged: (() -> Void)?
    var onCommand: ((Command) -> Void)?
    var onToolChanged: ((Tool) -> Void)?

    private enum EditMode { case move, resize }
    private var dragStart: CGPoint?
    private var draft: ScreenshotAnnotation?
    private var originalAnnotation: ScreenshotAnnotation?
    private var editMode: EditMode?
    private var textField: NSTextField?
    private var textOrigin: CGPoint?
    private var cancellingText = false

    init(document: ScreenshotDocument) {
        self.document = document
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        setAccessibilityLabel("Screenshot annotation canvas")
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }
    override var acceptsFirstResponder: Bool { true }

    private var crop: CGRect { document.effectiveCrop }
    private func sourcePoint(_ local: CGPoint) -> CGPoint {
        CGPoint(x: local.x + crop.minX, y: local.y + crop.minY)
    }
    private func localRect(_ source: CGRect) -> CGRect { source.offsetBy(dx: -crop.minX, dy: -crop.minY) }
    private func rect(from start: CGPoint, to end: CGPoint) -> CGRect {
        CGRect(x: start.x, y: start.y, width: end.x - start.x, height: end.y - start.y).standardized
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.controlBackgroundColor.setFill()
        bounds.fill()
        let annotations = previewAnnotations()
        if let image = AnnotationRenderer.render(source: document.source, crop: crop, annotations: annotations),
           let context = NSGraphicsContext.current?.cgContext {
            context.saveGState()
            context.interpolationQuality = .high
            context.draw(image, in: bounds)
            context.restoreGState()
        }
        drawSelection()
        if tool == .crop, let draft { drawCrop(localRect(draft.bounds.cgRect)) }
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: tool == .select ? .arrow : .crosshair)
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        let point = sourcePoint(convert(event.locationInWindow, from: nil))
        guard crop.contains(point) else { return }
        dragStart = point

        if tool == .text {
            presentTextEditor(at: point)
            return
        }
        if tool == .select {
            beginSelection(at: point)
            return
        }
        updateDraft(to: point)
    }

    override func mouseDragged(with event: NSEvent) {
        guard dragStart != nil else { return }
        let point = constrained(sourcePoint(convert(event.locationInWindow, from: nil)))
        if tool == .select { updateSelection(to: point) }
        else { updateDraft(to: point) }
    }

    override func mouseUp(with event: NSEvent) {
        guard let start = dragStart else { return }
        let end = constrained(sourcePoint(convert(event.locationInWindow, from: nil)))
        defer { cancelInteraction(keepSelection: true) }

        if tool == .select {
            updateSelection(to: end)
            if let draft { document.replace(draft) }
            return
        }
        if tool == .crop {
            let cropRect = rect(from: start, to: end)
            guard cropRect.width >= 2, cropRect.height >= 2 else { return }
            document.setCrop(cropRect)
            onCropChanged?()
            return
        }
        updateDraft(to: end)
        guard let draft, isMeaningful(draft) else { return }
        document.add(draft)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { cancelInteraction(); return }
        if event.keyCode == 51 || event.keyCode == 117 {
            document.deleteSelected(); needsDisplay = true; return
        }
        if event.modifierFlags.contains(.command), handleCommand(event) { return }
        if let character = event.charactersIgnoringModifiers?.lowercased(), selectTool(character) { return }
        super.keyDown(with: event)
    }

    private func handleCommand(_ event: NSEvent) -> Bool {
        let key = event.charactersIgnoringModifiers?.lowercased()
        let command: Command?
        switch key {
        case "z": command = event.modifierFlags.contains(.shift) ? .redo : .undo
        case "c": command = .copy
        case "s": command = .save
        case "+", "=": command = .zoomIn
        case "-": command = .zoomOut
        case "0": command = .zoomFit
        default: command = nil
        }
        guard let command else { return false }
        onCommand?(command)
        return true
    }

    private func selectTool(_ key: String) -> Bool {
        let selected: Tool?
        switch key {
        case "v", "s": selected = .select
        case "k": selected = .crop
        case "a": selected = .arrow
        case "d": selected = .line
        case "r": selected = .rectangle
        case "o": selected = .ellipse
        case "p": selected = .freehand
        case "t": selected = .text
        case "h": selected = .highlight
        case "m": selected = .marker
        case "l": selected = .blur
        case "b": selected = .pixelate
        default: selected = nil
        }
        guard let selected else { return false }
        tool = selected
        return true
    }

    private func beginSelection(at point: CGPoint) {
        if let selected = document.annotations.first(where: { $0.id == document.selectedID }), resizeHandle(for: selected).insetBy(dx: -6, dy: -6).contains(point) {
            originalAnnotation = selected
            draft = selected
            editMode = .resize
            return
        }
        let selected = document.annotations.reversed().first { hit($0, point: point) }
        document.select(selected?.id)
        originalAnnotation = selected
        draft = selected
        editMode = selected == nil ? nil : .move
        needsDisplay = true
    }

    private func updateSelection(to point: CGPoint) {
        guard let dragStart, let original = originalAnnotation, let editMode else { return }
        var changed = original
        switch editMode {
        case .move:
            let dx = point.x - dragStart.x, dy = point.y - dragStart.y
            changed.bounds = ScreenshotRect(original.bounds.cgRect.offsetBy(dx: dx, dy: dy))
            changed.points = original.points.map { ScreenshotPoint(CGPoint(x: $0.x + dx, y: $0.y + dy)) }
        case .resize:
            let old = original.bounds.cgRect
            let resized = rect(from: old.origin, to: point)
            guard resized.width >= 4, resized.height >= 4 else { return }
            changed.bounds = ScreenshotRect(resized)
            changed.points = original.points.map { value in
                let x = old.width == 0 ? 0 : (value.x - old.minX) / old.width
                let y = old.height == 0 ? 0 : (value.y - old.minY) / old.height
                return ScreenshotPoint(CGPoint(x: resized.minX + x * resized.width, y: resized.minY + y * resized.height))
            }
        }
        draft = changed
        needsDisplay = true
    }

    private func updateDraft(to end: CGPoint) {
        guard let start = dragStart else { return }
        if tool == .crop {
            draft = ScreenshotAnnotation(kind: .rectangle, bounds: rect(from: start, to: end))
            needsDisplay = true
            return
        }
        guard let kind = tool.annotationKind else { return }
        let annotationBounds: CGRect
        if kind == .marker, abs(end.x - start.x) < 4, abs(end.y - start.y) < 4 {
            annotationBounds = CGRect(x: start.x - 16, y: start.y - 16, width: 32, height: 32)
        } else {
            annotationBounds = rect(from: start, to: end)
        }
        let points = kind == .freehand ? (draft?.points.map(\.cgPoint) ?? [start]) + [end] : [start, end]
        let color = kind == .highlight ? ScreenshotColor.yellow : drawingColor
        draft = ScreenshotAnnotation(
            kind: kind,
            bounds: annotationBounds,
            points: points,
            color: color,
            fill: kind == .highlight ? ScreenshotColor.yellow : nil,
            lineWidth: lineWidth,
            markerNumber: kind == .marker ? nextMarkerNumber : nil
        )
        needsDisplay = true
    }

    private var nextMarkerNumber: Int {
        (document.annotations.compactMap(\.markerNumber).max() ?? 0) + 1
    }

    private func previewAnnotations() -> [ScreenshotAnnotation] {
        guard let draft, tool != .crop else { return document.annotations }
        if document.annotations.contains(where: { $0.id == draft.id }) {
            return document.annotations.map { $0.id == draft.id ? draft : $0 }
        }
        return document.annotations + [draft]
    }

    private func drawSelection() {
        guard tool == .select,
              let selected = draft ?? document.annotations.first(where: { $0.id == document.selectedID }),
              let context = NSGraphicsContext.current?.cgContext else { return }
        let selection = localRect(selected.bounds.cgRect)
        context.saveGState()
        context.setStrokeColor(NSColor.controlAccentColor.cgColor)
        context.setLineWidth(1.5)
        context.setLineDash(phase: 0, lengths: [5, 3])
        context.stroke(selection)
        context.setLineDash(phase: 0, lengths: [])
        context.setFillColor(NSColor.controlAccentColor.cgColor)
        context.fillEllipse(in: localRect(resizeHandle(for: selected)))
        context.restoreGState()
    }

    private func drawCrop(_ rect: CGRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.saveGState()
        context.setStrokeColor(NSColor.controlAccentColor.cgColor)
        context.setLineWidth(2)
        context.setLineDash(phase: 0, lengths: [6, 4])
        context.stroke(rect)
        context.restoreGState()
    }

    private func resizeHandle(for annotation: ScreenshotAnnotation) -> CGRect {
        let point = CGPoint(x: annotation.bounds.cgRect.maxX, y: annotation.bounds.cgRect.maxY)
        return CGRect(x: point.x - 5, y: point.y - 5, width: 10, height: 10)
    }

    private func hit(_ annotation: ScreenshotAnnotation, point: CGPoint) -> Bool {
        annotation.bounds.cgRect.insetBy(dx: -8, dy: -8).contains(point)
    }

    private func isMeaningful(_ annotation: ScreenshotAnnotation) -> Bool {
        if annotation.kind == .freehand { return annotation.points.count > 1 }
        if annotation.kind == .line || annotation.kind == .arrow { return annotation.points.first != annotation.points.last }
        return annotation.bounds.cgRect.width >= 2 && annotation.bounds.cgRect.height >= 2
    }

    private func constrained(_ point: CGPoint) -> CGPoint {
        CGPoint(x: min(max(point.x, crop.minX), crop.maxX), y: min(max(point.y, crop.minY), crop.maxY))
    }

    private func presentTextEditor(at point: CGPoint) {
        cancelTextEditor()
        textOrigin = point
        let local = CGPoint(x: point.x - crop.minX, y: point.y - crop.minY)
        let field = NSTextField(frame: CGRect(x: local.x, y: local.y, width: 220, height: 30))
        field.placeholderString = "Type text"
        field.font = .systemFont(ofSize: 18, weight: .medium)
        field.textColor = NSColor(cgColor: drawingColor.cgColor)
        field.focusRingType = .default
        field.delegate = self
        field.target = self
        field.action = #selector(commitText(_:))
        addSubview(field)
        textField = field
        window?.makeFirstResponder(field)
    }

    @objc private func commitText(_ sender: NSTextField) {
        guard sender === textField, let origin = textOrigin else { return }
        let value = sender.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if !value.isEmpty {
            document.add(ScreenshotAnnotation(kind: .text, bounds: CGRect(x: origin.x, y: origin.y, width: 240, height: 32), text: value, color: drawingColor, fontSize: 18))
        }
        finishTextEditor()
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        guard !cancellingText, let field = obj.object as? NSTextField, field === textField else { return }
        commitText(field)
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            cancelTextEditor()
            return true
        }
        return false
    }

    private func cancelTextEditor() {
        cancellingText = true
        finishTextEditor()
        cancellingText = false
    }

    private func finishTextEditor() {
        textField?.removeFromSuperview()
        textField = nil
        textOrigin = nil
        dragStart = nil
        window?.makeFirstResponder(self)
        needsDisplay = true
    }

    private func cancelInteraction(keepSelection: Bool = false) {
        cancelTextEditor()
        dragStart = nil
        draft = nil
        originalAnnotation = nil
        editMode = nil
        if !keepSelection, tool != .select { document.select(nil) }
        needsDisplay = true
    }

    private func updateCursor() { window?.invalidateCursorRects(for: self) }
}
