import AppKit
import DropThingsPlatform
import UniformTypeIdentifiers

@MainActor
final class ScreenshotEditorWindowController: NSWindowController, NSWindowDelegate {
    private let editorDocument: ScreenshotDocument
    private let canvas: AnnotationCanvasView
    private let onClose: () -> Void
    private let recognizer = VisionImageRecognitionService()
    private let scrollView = NSScrollView()
    private let toolControl: NSSegmentedControl
    private let feedbackLabel = NSTextField(labelWithString: "")
    private let zoomLabel = NSTextField(labelWithString: "100%")

    init(document: ScreenshotDocument, onClose: @escaping () -> Void) {
        editorDocument = document
        canvas = AnnotationCanvasView(document: document)
        self.onClose = onClose
        toolControl = NSSegmentedControl(
            images: AnnotationCanvasView.Tool.allCases.map {
                NSImage(systemSymbolName: $0.symbol, accessibilityDescription: $0.label) ?? NSImage()
            },
            trackingMode: .selectOne,
            target: nil,
            action: nil
        )
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1080, height: 760),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Screenshot Studio"
        window.minSize = NSSize(width: 720, height: 520)
        window.titlebarSeparatorStyle = .line
        window.center()
        super.init(window: window)
        window.delegate = self
        configureWindow()
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    private func configureWindow() {
        let toolbar = NSToolbar(identifier: "ScreenshotStudio.Editor")
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        toolbar.allowsUserCustomization = false
        window?.toolbar = toolbar

        let clipView = CenteredClipView()
        clipView.drawsBackground = true
        clipView.backgroundColor = .underPageBackgroundColor
        scrollView.contentView = clipView
        scrollView.hasHorizontalScroller = true
        scrollView.hasVerticalScroller = true
        scrollView.allowsMagnification = true
        scrollView.minMagnification = 0.1
        scrollView.maxMagnification = 8
        scrollView.borderType = .noBorder
        scrollView.documentView = canvas

        let root = NSStackView(views: [scrollView, makeInspectorBar()])
        root.orientation = .vertical
        root.spacing = 0
        root.setHuggingPriority(.defaultLow, for: .vertical)
        window?.contentView = root

        canvas.onCropChanged = { [weak self] in self?.refreshCanvasGeometry(fit: true) }
        canvas.onCommand = { [weak self] command in self?.perform(command) }
        canvas.onToolChanged = { [weak self] tool in
            self?.toolControl.selectedSegment = AnnotationCanvasView.Tool.allCases.firstIndex(of: tool) ?? 0
        }
        refreshCanvasGeometry(fit: true)
    }

    private func makeInspectorBar() -> NSView {
        let effect = NSVisualEffectView()
        effect.material = .headerView
        effect.blendingMode = .withinWindow
        effect.translatesAutoresizingMaskIntoConstraints = false

        let colorLabel = NSTextField(labelWithString: "Color")
        colorLabel.textColor = .secondaryLabelColor
        let colorWell = NSColorWell(frame: NSRect(x: 0, y: 0, width: 42, height: 25))
        colorWell.color = NSColor(cgColor: ScreenshotColor.red.cgColor) ?? .systemRed
        colorWell.target = self
        colorWell.action = #selector(changeColor(_:))

        let widthLabel = NSTextField(labelWithString: "Stroke")
        widthLabel.textColor = .secondaryLabelColor
        let widthSlider = NSSlider(value: 3, minValue: 1, maxValue: 18, target: self, action: #selector(changeLineWidth(_:)))
        widthSlider.frame.size.width = 120
        widthSlider.toolTip = "Annotation stroke width"

        feedbackLabel.textColor = .secondaryLabelColor
        feedbackLabel.lineBreakMode = .byTruncatingTail
        zoomLabel.textColor = .secondaryLabelColor
        zoomLabel.alignment = .right
        zoomLabel.frame.size.width = 54

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let stack = NSStackView(views: [colorLabel, colorWell, widthLabel, widthSlider, feedbackLabel, spacer, zoomLabel])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 10
        stack.edgeInsets = NSEdgeInsets(top: 8, left: 14, bottom: 8, right: 14)
        stack.translatesAutoresizingMaskIntoConstraints = false
        effect.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: effect.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: effect.trailingAnchor),
            stack.topAnchor.constraint(equalTo: effect.topAnchor),
            stack.bottomAnchor.constraint(equalTo: effect.bottomAnchor),
            effect.heightAnchor.constraint(equalToConstant: 44)
        ])
        return effect
    }

    private func refreshCanvasGeometry(fit: Bool = false) {
        let size = editorDocument.effectiveCrop.size
        canvas.frame = CGRect(origin: .zero, size: size)
        canvas.needsDisplay = true
        scrollView.tile()
        if fit { DispatchQueue.main.async { [weak self] in self?.fitImageToWindow() } }
    }

    private func fitImageToWindow() {
        let imageSize = editorDocument.effectiveCrop.size
        let viewport = scrollView.contentSize
        guard imageSize.width > 0, imageSize.height > 0, viewport.width > 0, viewport.height > 0 else { return }
        let scale = min((viewport.width - 32) / imageSize.width, (viewport.height - 32) / imageSize.height, 1)
        scrollView.setMagnification(max(scale, scrollView.minMagnification), centeredAt: CGPoint(x: imageSize.width / 2, y: imageSize.height / 2))
        updateZoomLabel()
    }

    private func changeZoom(by factor: CGFloat) {
        let next = min(max(scrollView.magnification * factor, scrollView.minMagnification), scrollView.maxMagnification)
        scrollView.setMagnification(next, centeredAt: CGPoint(x: canvas.bounds.midX, y: canvas.bounds.midY))
        updateZoomLabel()
    }

    private func updateZoomLabel() { zoomLabel.stringValue = "\(Int((scrollView.magnification * 100).rounded()))%" }

    private func perform(_ command: AnnotationCanvasView.Command) {
        switch command {
        case .undo: undo()
        case .redo: redo()
        case .copy: copyImage()
        case .save: save()
        case .zoomIn: zoomIn()
        case .zoomOut: zoomOut()
        case .zoomFit: zoomToFit()
        }
    }

    func windowDidBecomeKey(_ notification: Notification) { window?.makeFirstResponder(canvas) }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard editorDocument.isDirty else { return true }
        let alert = NSAlert()
        alert.messageText = "Discard unsaved screenshot?"
        alert.informativeText = "Your annotations have not been copied or saved."
        alert.addButton(withTitle: "Discard")
        alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn
    }

    func windowWillClose(_ notification: Notification) { onClose() }

    private func export(copy: Bool) {
        guard let image = AnnotationRenderer.render(document: editorDocument) else {
            showError(title: "Could not render screenshot", detail: "The editor could not create the final image.")
            return
        }
        if copy {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            guard pasteboard.writeObjects([NSImage(cgImage: image, size: .zero)]) else {
                showError(title: "Could not copy screenshot", detail: "The pasteboard rejected the image.")
                return
            }
            editorDocument.markSaved()
            showFeedback("Copied to clipboard")
            return
        }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png, .jpeg]
        panel.nameFieldStringValue = "Screenshot.png"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let representation = NSBitmapImageRep(cgImage: image)
        let type: NSBitmapImageRep.FileType = ["jpg", "jpeg"].contains(url.pathExtension.lowercased()) ? .jpeg : .png
        guard let data = representation.representation(using: type, properties: type == .jpeg ? [.compressionFactor: 0.92] : [:]) else {
            showError(title: "Could not encode screenshot", detail: "Try saving as PNG.")
            return
        }
        do {
            try data.write(to: url, options: .atomic)
            editorDocument.markSaved()
            showFeedback("Saved \(url.lastPathComponent)")
        } catch {
            showError(title: "Could not save screenshot", detail: error.localizedDescription)
        }
    }

    private func showFeedback(_ message: String) {
        feedbackLabel.stringValue = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            if self?.feedbackLabel.stringValue == message { self?.feedbackLabel.stringValue = "" }
        }
    }

    private func showError(title: String, detail: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = title
        alert.informativeText = detail
        alert.runModal()
    }
}

extension ScreenshotEditorWindowController: NSToolbarDelegate {
    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.tools, .flexibleSpace, .zoomOut, .zoomFit, .zoomIn, .undo, .redo, .ocr, .qr, .copy, .save]
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.tools, .flexibleSpace, .zoomOut, .zoomFit, .zoomIn, .undo, .redo, .ocr, .qr, .copy, .save]
    }

    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier identifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        let item = NSToolbarItem(itemIdentifier: identifier)
        switch identifier {
        case .tools:
            toolControl.target = self
            toolControl.action = #selector(changeTool(_:))
            toolControl.selectedSegment = 0
            for (index, tool) in AnnotationCanvasView.Tool.allCases.enumerated() {
                toolControl.setToolTip(tool.label, forSegment: index)
                toolControl.setWidth(31, forSegment: index)
            }
            item.view = toolControl
            item.label = "Annotation tool"
        case .zoomOut: configure(item, label: "Zoom out", symbol: "minus.magnifyingglass", action: #selector(zoomOut))
        case .zoomFit: configure(item, label: "Fit image", symbol: "arrow.up.left.and.arrow.down.right", action: #selector(zoomToFit))
        case .zoomIn: configure(item, label: "Zoom in", symbol: "plus.magnifyingglass", action: #selector(zoomIn))
        case .undo: configure(item, label: "Undo", symbol: "arrow.uturn.backward", action: #selector(undo))
        case .redo: configure(item, label: "Redo", symbol: "arrow.uturn.forward", action: #selector(redo))
        case .ocr: configure(item, label: "Copy recognized text", symbol: "text.viewfinder", action: #selector(recognizeText))
        case .qr: configure(item, label: "Recognize QR", symbol: "qrcode.viewfinder", action: #selector(recognizeQR))
        case .copy: configure(item, label: "Copy", symbol: "doc.on.doc", action: #selector(copyImage))
        case .save: configure(item, label: "Save", symbol: "square.and.arrow.down", action: #selector(save))
        default: return nil
        }
        return item
    }

    private func configure(_ item: NSToolbarItem, label: String, symbol: String, action: Selector) {
        item.label = label
        item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: label)
        item.target = self
        item.action = action
    }

    @objc private func changeTool(_ sender: NSSegmentedControl) {
        guard AnnotationCanvasView.Tool.allCases.indices.contains(sender.selectedSegment) else { return }
        canvas.tool = AnnotationCanvasView.Tool.allCases[sender.selectedSegment]
        window?.makeFirstResponder(canvas)
    }
    @objc private func changeColor(_ sender: NSColorWell) { canvas.drawingColor = ScreenshotColor(sender.color) }
    @objc private func changeLineWidth(_ sender: NSSlider) { canvas.lineWidth = CGFloat(sender.doubleValue) }
    @objc private func zoomOut() { changeZoom(by: 1 / 1.25) }
    @objc private func zoomToFit() { fitImageToWindow() }
    @objc private func zoomIn() { changeZoom(by: 1.25) }
    @objc private func undo() { editorDocument.undo(); refreshCanvasGeometry() }
    @objc private func redo() { editorDocument.redo(); refreshCanvasGeometry() }
    @objc private func copyImage() { export(copy: true) }
    @objc private func save() { export(copy: false) }

    @objc private func recognizeText() {
        guard let image = AnnotationRenderer.render(document: editorDocument) else { return }
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let observations = try await recognizer.recognize(in: image, level: .accurate, languages: [])
                let text = observations.map(\.string).joined(separator: "\n")
                guard !text.isEmpty else { showError(title: "No text found", detail: "Vision did not identify selectable text."); return }
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
                showFeedback("Recognized text copied")
            } catch { showError(title: "Recognition failed", detail: error.localizedDescription) }
        }
    }

    @objc private func recognizeQR() {
        guard let image = AnnotationRenderer.render(document: editorDocument) else { return }
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                guard let value = try await recognizer.recognize(in: image).first else {
                    showError(title: "No QR or barcode found", detail: "No machine-readable code was detected.")
                    return
                }
                let alert = NSAlert()
                alert.messageText = "Open recognized code?"
                alert.informativeText = value
                alert.addButton(withTitle: "Open")
                alert.addButton(withTitle: "Cancel")
                guard alert.runModal() == .alertFirstButtonReturn, let url = URL(string: value) else { return }
                NSWorkspace.shared.open(url)
            } catch { showError(title: "Recognition failed", detail: error.localizedDescription) }
        }
    }
}

private final class CenteredClipView: NSClipView {
    override func constrainBoundsRect(_ proposedBounds: NSRect) -> NSRect {
        var bounds = super.constrainBoundsRect(proposedBounds)
        guard let documentView else { return bounds }
        if documentView.frame.width < self.bounds.width { bounds.origin.x = -(self.bounds.width - documentView.frame.width) / 2 }
        if documentView.frame.height < self.bounds.height { bounds.origin.y = -(self.bounds.height - documentView.frame.height) / 2 }
        return bounds
    }
}

private extension NSToolbarItem.Identifier {
    static let tools = Self("screenshotstudio.tools")
    static let zoomOut = Self("screenshotstudio.zoom-out")
    static let zoomFit = Self("screenshotstudio.zoom-fit")
    static let zoomIn = Self("screenshotstudio.zoom-in")
    static let undo = Self("screenshotstudio.undo")
    static let redo = Self("screenshotstudio.redo")
    static let copy = Self("screenshotstudio.copy")
    static let save = Self("screenshotstudio.save")
    static let ocr = Self("screenshotstudio.ocr")
    static let qr = Self("screenshotstudio.qr")
}
