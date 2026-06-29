import AppKit
import CoreGraphics

/// Full-screen drag-select overlay. Presents a dim layer over all screens and
/// lets the user drag a rectangle. ESC cancels, Return/Enter confirms.
public final class RegionSelectionOverlay {
    public enum Result {
        case region(CGRect)
        case cancelled
    }

    private var window: RegionSelectionWindow?
    private var completion: ((Result) -> Void)?

    public init() {}

    /// Show the overlay and call `completion` on the main actor when the user
    /// confirms or cancels.
    public func show(completion: @escaping @MainActor (Result) -> Void) {
        self.completion = completion

        let frame = NSScreen.screens.map(\.frame).reduce(CGRect.null) { $0.union($1) }
        let window = RegionSelectionWindow(frame: frame) { [weak self] result in
            self?.finish(result)
        }
        self.window = window

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    public func cancel() {
        finish(.cancelled)
    }

    private func finish(_ result: Result) {
        window?.orderOut(nil)
        window = nil
        completion?(result)
        completion = nil
    }
}

// MARK: - Window

private final class RegionSelectionWindow: NSWindow {
    private let onComplete: (RegionSelectionOverlay.Result) -> Void

    init(frame: CGRect, onComplete: @escaping (RegionSelectionOverlay.Result) -> Void) {
        self.onComplete = onComplete
        super.init(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        self.level = .screenSaver
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = false
        self.ignoresMouseEvents = false
        self.isReleasedWhenClosed = false
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.contentView = RegionSelectionView(frame: frame, onComplete: onComplete)
    }
}

// MARK: - View

private final class RegionSelectionView: NSView {
    private let onComplete: (RegionSelectionOverlay.Result) -> Void
    private var startPoint: CGPoint?
    private var currentPoint: CGPoint?

    init(frame: CGRect, onComplete: @escaping (RegionSelectionOverlay.Result) -> Void) {
        self.onComplete = onComplete
        super.init(frame: frame)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var acceptsFirstResponder: Bool { true }

    override func mouseDown(with event: NSEvent) {
        startPoint = event.locationInWindow
        currentPoint = event.locationInWindow
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        currentPoint = event.locationInWindow
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        currentPoint = event.locationInWindow
        guard let rect = selectionRect, rect.width >= 2, rect.height >= 2 else {
            onComplete(.cancelled)
            return
        }
        onComplete(.region(globalRect(from: rect)))
    }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 53: // ESC
            onComplete(.cancelled)
        case 36, 76: // Return / keypad Enter
            guard let rect = selectionRect, rect.width >= 2, rect.height >= 2 else {
                onComplete(.cancelled)
                return
            }
            onComplete(.region(globalRect(from: rect)))
        default:
            super.keyDown(with: event)
        }
    }

    private var selectionRect: CGRect? {
        guard let start = startPoint, let current = currentPoint else { return nil }
        return CGRect(origin: start, size: CGSize(width: current.x - start.x, height: current.y - start.y))
            .standardized
    }

    private func globalRect(from viewRect: CGRect) -> CGRect {
        CGRect(
            origin: CGPoint(x: viewRect.minX + frame.minX, y: viewRect.minY + frame.minY),
            size: viewRect.size
        )
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let dim = NSColor.black.withAlphaComponent(0.35)
        dim.setFill()
        bounds.fill()

        guard let rect = selectionRect else { return }

        let border = NSColor.controlAccentColor
        let fill = NSColor.white.withAlphaComponent(0.08)

        let path = NSBezierPath(rect: rect)
        fill.setFill()
        path.fill()
        border.setStroke()
        path.lineWidth = 1
        path.stroke()

        drawSizeLabel(for: rect)
    }

    private func drawSizeLabel(for rect: CGRect) {
        let size = CGSize(width: rect.width, height: rect.height)
        let text = String(format: "%.0f × %.0f", size.width, size.height)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .medium),
            .foregroundColor: NSColor.white,
            .paragraphStyle: NSParagraphStyle.default
        ]
        let attributed = NSAttributedString(string: text, attributes: attributes)
        let textSize = attributed.size()
        let labelOrigin = CGPoint(x: rect.minX + 6, y: rect.maxY + 4)
        let labelRect = CGRect(origin: labelOrigin, size: CGSize(width: textSize.width + 8, height: textSize.height + 4))

        NSColor.black.withAlphaComponent(0.6).setFill()
        NSBezierPath(roundedRect: labelRect, xRadius: 4, yRadius: 4).fill()

        let textRect = CGRect(
            origin: CGPoint(x: labelRect.minX + 4, y: labelRect.minY + 2),
            size: textSize
        )
        attributed.draw(in: textRect)
    }
}
