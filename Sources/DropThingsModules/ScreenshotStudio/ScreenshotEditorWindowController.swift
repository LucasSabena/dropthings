import AppKit
import DropThingsPlatform

@MainActor
final class ScreenshotEditorWindowController: NSWindowController, NSWindowDelegate {
    private let editorDocument: ScreenshotDocument
    private let canvas: AnnotationCanvasView
    private let onClose: () -> Void
    private let recognizer = VisionImageRecognitionService()
    private let scrollView = NSScrollView()

    init(document: ScreenshotDocument, onClose: @escaping () -> Void) {
        self.editorDocument = document; self.canvas = AnnotationCanvasView(document: document); self.onClose = onClose
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 900, height: 680), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "Screenshot Studio"; window.minSize = NSSize(width: 480, height: 360); window.center()
        super.init(window: window); window.delegate = self
        configureWindow()
    }
    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    private func configureWindow() {
        let toolbar = NSToolbar(identifier: "ScreenshotStudio.Editor"); toolbar.delegate = self; toolbar.displayMode = .iconOnly; window?.toolbar = toolbar
        scrollView.hasHorizontalScroller = true
        scrollView.hasVerticalScroller = true
        scrollView.allowsMagnification = true
        scrollView.minMagnification = 0.1
        scrollView.maxMagnification = 8
        scrollView.documentView = canvas
        canvas.frame = CGRect(origin: .zero, size: editorDocument.effectiveCrop.size)
        window?.contentView = scrollView
        fitImageToWindow()
    }

    private func fitImageToWindow() {
        let imageSize = editorDocument.effectiveCrop.size
        guard imageSize.width > 0, imageSize.height > 0 else { return }
        let viewport = scrollView.contentSize
        let scale = min(viewport.width / imageSize.width, viewport.height / imageSize.height)
        scrollView.magnification = min(max(scale, scrollView.minMagnification), 1)
    }

    private func changeZoom(by factor: CGFloat) {
        scrollView.magnification = min(max(scrollView.magnification * factor, scrollView.minMagnification), scrollView.maxMagnification)
    }
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard editorDocument.isDirty else { return true }
        let alert = NSAlert(); alert.messageText = "Discard unsaved screenshot?"; alert.informativeText = "Your annotations have not been exported."; alert.addButton(withTitle: "Discard"); alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn
    }
    func windowWillClose(_ notification: Notification) { onClose() }
    private func export(copy: Bool) {
        guard let image = AnnotationRenderer.render(document: editorDocument) else { return }
        if copy { let pb = NSPasteboard.general; pb.clearContents(); pb.writeObjects([NSImage(cgImage: image, size: .zero)]) }
        else { let panel = NSSavePanel(); panel.allowedContentTypes = [.png, .jpeg]; panel.nameFieldStringValue = "Screenshot.png"; guard panel.runModal() == .OK, let url = panel.url else { return }; let rep = NSBitmapImageRep(cgImage: image); let type: NSBitmapImageRep.FileType = url.pathExtension.lowercased() == "jpg" || url.pathExtension.lowercased() == "jpeg" ? .jpeg : .png; try? rep.representation(using: type, properties: [:])?.write(to: url, options: .atomic); editorDocument.markSaved() }
    }
}

extension ScreenshotEditorWindowController: NSToolbarDelegate {
    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] { [.tools, .zoomOut, .zoomFit, .zoomIn, .undo, .redo, .crop, .ocr, .qr, .copy, .save] }
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] { [.tools, .flexibleSpace, .zoomOut, .zoomFit, .zoomIn, .undo, .redo, .crop, .ocr, .qr, .copy, .save] }
    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        let item = NSToolbarItem(itemIdentifier: itemIdentifier)
        switch itemIdentifier {
        case .tools:
            let control = NSSegmentedControl(labels: ["↖", "→", "╱", "□", "◯", "✎", "T", "▤", "1", "◼", "▦"], trackingMode: .selectOne, target: self, action: #selector(changeTool(_:))); control.selectedSegment = 0; item.view = control; item.label = "Tool"
        case .zoomOut: item.label = "Zoom out"; item.image = NSImage(systemSymbolName: "minus.magnifyingglass", accessibilityDescription: "Zoom out"); item.target = self; item.action = #selector(zoomOut)
        case .zoomFit: item.label = "Fit image"; item.image = NSImage(systemSymbolName: "arrow.up.left.and.arrow.down.right", accessibilityDescription: "Fit image"); item.target = self; item.action = #selector(zoomToFit)
        case .zoomIn: item.label = "Zoom in"; item.image = NSImage(systemSymbolName: "plus.magnifyingglass", accessibilityDescription: "Zoom in"); item.target = self; item.action = #selector(zoomIn)
        case .undo: item.label = "Undo"; item.image = NSImage(systemSymbolName: "arrow.uturn.backward", accessibilityDescription: "Undo"); item.target = self; item.action = #selector(undo)
        case .redo: item.label = "Redo"; item.image = NSImage(systemSymbolName: "arrow.uturn.forward", accessibilityDescription: "Redo"); item.target = self; item.action = #selector(redo)
        case .crop: item.label = "Crop"; item.image = NSImage(systemSymbolName: "crop", accessibilityDescription: "Crop"); item.target = self; item.action = #selector(crop)
        case .ocr: item.label = "Recognize text"; item.image = NSImage(systemSymbolName: "text.viewfinder", accessibilityDescription: "Recognize text"); item.target = self; item.action = #selector(recognizeText)
        case .qr: item.label = "Recognize QR"; item.image = NSImage(systemSymbolName: "qrcode.viewfinder", accessibilityDescription: "Recognize QR"); item.target = self; item.action = #selector(recognizeQR)
        case .copy: item.label = "Copy"; item.image = NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: "Copy"); item.target = self; item.action = #selector(copyImage)
        case .save: item.label = "Save"; item.image = NSImage(systemSymbolName: "square.and.arrow.down", accessibilityDescription: "Save"); item.target = self; item.action = #selector(save)
        default: return nil
        }; return item
    }
    @objc private func changeTool(_ sender: NSSegmentedControl) { canvas.tool = AnnotationCanvasView.Tool(rawValue: sender.selectedSegment) ?? .select }
    @objc private func zoomOut() { changeZoom(by: 1 / 1.25) }
    @objc private func zoomToFit() { fitImageToWindow() }
    @objc private func zoomIn() { changeZoom(by: 1.25) }
    @objc private func undo() { editorDocument.undo(); canvas.needsDisplay = true }
    @objc private func redo() { editorDocument.redo(); canvas.needsDisplay = true }
    @objc private func crop() { canvas.tool = .crop }
    @objc private func copyImage() { export(copy: true) }
    @objc private func save() { export(copy: false) }
    @objc private func recognizeText() {
        let image = editorDocument.source
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let observations = try await recognizer.recognize(in: image, level: .accurate, languages: [])
                let text = observations.map(\.string).joined(separator: "\n")
                let pasteboard = NSPasteboard.general; pasteboard.clearContents(); pasteboard.setString(text, forType: .string)
                let alert = NSAlert(); alert.messageText = text.isEmpty ? "No text found" : "Recognized text copied"; alert.informativeText = text.isEmpty ? "Vision did not identify selectable text." : "\(observations.count) text regions were copied to the clipboard."; alert.runModal()
            } catch { self.showRecognitionError(error) }
        }
    }
    @objc private func recognizeQR() {
        let image = editorDocument.source
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                guard let value = try await recognizer.recognize(in: image).first else { let alert = NSAlert(); alert.messageText = "No QR or barcode found"; alert.runModal(); return }
                let alert = NSAlert(); alert.messageText = "Open recognized code?"; alert.informativeText = value; alert.addButton(withTitle: "Open"); alert.addButton(withTitle: "Cancel")
                guard alert.runModal() == .alertFirstButtonReturn, let url = URL(string: value) else { return }
                NSWorkspace.shared.open(url)
            } catch { self.showRecognitionError(error) }
        }
    }
    private func showRecognitionError(_ error: Error) { let alert = NSAlert(); alert.messageText = "Recognition failed"; alert.informativeText = error.localizedDescription; alert.runModal() }
}

private extension NSToolbarItem.Identifier {
    static let zoomOut = NSToolbarItem.Identifier("ScreenshotStudio.zoom-out")
    static let zoomFit = NSToolbarItem.Identifier("ScreenshotStudio.zoom-fit")
    static let zoomIn = NSToolbarItem.Identifier("ScreenshotStudio.zoom-in")
}

private extension NSToolbarItem.Identifier {
    static let tools = Self("screenshotstudio.tools"); static let undo = Self("screenshotstudio.undo"); static let redo = Self("screenshotstudio.redo"); static let crop = Self("screenshotstudio.crop"); static let copy = Self("screenshotstudio.copy"); static let save = Self("screenshotstudio.save")
    static let ocr = Self("screenshotstudio.ocr"); static let qr = Self("screenshotstudio.qr")
}
