import AppKit

@MainActor
final class PinnedImageController: NSWindowController {
    init(image: CGImage) {
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: max(160, min(700, image.width / 2)), height: max(120, min(600, image.height / 2))), styleMask: [.borderless, .resizable, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false; panel.backgroundColor = .clear; panel.level = .floating; panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]; panel.isMovableByWindowBackground = true
        super.init(window: panel)
        let imageView = NSImageView(image: NSImage(cgImage: image, size: .zero)); imageView.imageScaling = .scaleAxesIndependently; imageView.imageAlignment = .alignCenter; panel.contentView = imageView
    }
    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }
}
