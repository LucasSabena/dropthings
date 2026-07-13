import AppKit

/// Selection-only overlay. Capture and output routing intentionally live in
/// the module so this AppKit surface has no filesystem or permission concerns.
final class RegionCaptureOverlay {
    enum Result { case region(CGRect), cancelled }
    private var window: NSWindow?
    private var completion: ((Result) -> Void)?

    func show(completion: @escaping (Result) -> Void) {
        self.completion = completion
        let frame = NSScreen.screens.map(\.frame).reduce(CGRect.null) { $0.union($1) }
        let window = RegionCaptureWindow(frame: frame) { [weak self] result in self?.finish(result) }
        self.window = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func cancel() { finish(.cancelled) }
    private func finish(_ result: Result) {
        window?.orderOut(nil)
        window = nil
        completion?(result)
        completion = nil
    }
}

private final class RegionCaptureWindow: NSWindow {
    init(frame: CGRect, completion: @escaping (RegionCaptureOverlay.Result) -> Void) {
        super.init(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
        level = .screenSaver
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        contentView = RegionCaptureView(frame: CGRect(origin: .zero, size: frame.size), completion: completion)
    }
}

private final class RegionCaptureView: NSView {
    private let completion: (RegionCaptureOverlay.Result) -> Void
    private var start: CGPoint?
    private var current: CGPoint?

    init(frame: CGRect, completion: @escaping (RegionCaptureOverlay.Result) -> Void) {
        self.completion = completion
        super.init(frame: frame)
    }
    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }
    override var acceptsFirstResponder: Bool { true }
    override func mouseDown(with event: NSEvent) { start = event.locationInWindow; current = start; needsDisplay = true }
    override func mouseDragged(with event: NSEvent) { current = event.locationInWindow; needsDisplay = true }
    override func mouseUp(with event: NSEvent) { completeSelection() }
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { completion(.cancelled) }
        else if event.keyCode == 36 || event.keyCode == 76 { completeSelection() }
        else { super.keyDown(with: event) }
    }
    private var rect: CGRect? {
        guard let start, let current else { return nil }
        return CGRect(x: start.x, y: start.y, width: current.x - start.x, height: current.y - start.y).standardized
    }
    private func completeSelection() {
        guard let rect, rect.width >= 2, rect.height >= 2, let window else { completion(.cancelled); return }
        completion(.region(window.convertToScreen(rect)))
    }
    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.withAlphaComponent(0.35).setFill(); bounds.fill()
        guard let rect else { return }
        NSColor.white.withAlphaComponent(0.08).setFill(); NSBezierPath(rect: rect).fill()
        NSColor.controlAccentColor.setStroke(); let path = NSBezierPath(rect: rect); path.lineWidth = 1; path.stroke()
        let text = String(format: "%.0f × %.0f", rect.width, rect.height)
        text.draw(at: CGPoint(x: rect.minX + 6, y: rect.maxY + 4), withAttributes: [.font: NSFont.systemFont(ofSize: 11, weight: .medium), .foregroundColor: NSColor.white])
    }
}
