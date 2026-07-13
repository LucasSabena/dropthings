import AppKit

@MainActor
final class FloatingCaptureThumbnailController: NSWindowController {
    private let image: CGImage
    private let onEdit: () -> Void
    private let onPin: () -> Void
    private let onDismiss: () -> Void
    private let dismissAfter: TimeInterval
    private var dismissTimer: Timer?

    init(image: CGImage, onEdit: @escaping () -> Void, onPin: @escaping () -> Void, onDismiss: @escaping () -> Void, dismissAfter: TimeInterval) {
        self.image = image; self.onEdit = onEdit; self.onPin = onPin; self.onDismiss = onDismiss; self.dismissAfter = dismissAfter
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 260, height: 210), styleMask: [.nonactivatingPanel, .fullSizeContentView], backing: .buffered, defer: false)
        panel.level = .floating; panel.isFloatingPanel = true; panel.hidesOnDeactivate = false; panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        super.init(window: panel)
        let root = NSStackView(); root.orientation = .vertical; root.spacing = 8; root.edgeInsets = NSEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        let preview = NSImageView(image: NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))); preview.imageScaling = .scaleProportionallyUpOrDown; preview.translatesAutoresizingMaskIntoConstraints = false; preview.heightAnchor.constraint(equalToConstant: 145).isActive = true
        let actions = NSStackView(); actions.orientation = .horizontal; actions.distribution = .fillEqually; actions.spacing = 6
        [("Copy", #selector(copyImage)), ("Save", #selector(saveImage)), ("Edit", #selector(editImage)), ("Pin", #selector(pinImage)), ("Dismiss", #selector(dismiss))].forEach { title, action in let button = NSButton(title: title, target: self, action: action); button.bezelStyle = .rounded; actions.addArrangedSubview(button) }
        root.addArrangedSubview(preview); root.addArrangedSubview(actions); panel.contentView = root
    }
    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }
    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        let frame = NSScreen.main?.visibleFrame ?? .zero
        window?.setFrameOrigin(CGPoint(x: frame.maxX - 280, y: frame.minY + 30))
        dismissTimer = Timer.scheduledTimer(withTimeInterval: dismissAfter, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.close() }
        }
    }
    @objc private func copyImage() { let pasteboard = NSPasteboard.general; pasteboard.clearContents(); pasteboard.writeObjects([NSImage(cgImage: image, size: .zero)]) }
    @objc private func saveImage() { let panel = NSSavePanel(); panel.nameFieldStringValue = "Screenshot.png"; guard panel.runModal() == .OK, let url = panel.url, let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else { return }; try? data.write(to: url, options: .atomic) }
    @objc private func editImage() { onEdit(); close() }
    @objc private func pinImage() { onPin(); close() }
    @objc private func dismiss() { close() }
    override func close() { dismissTimer?.invalidate(); dismissTimer = nil; super.close(); onDismiss() }
}
