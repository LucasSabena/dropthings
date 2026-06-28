import AppKit
import DropThingsCore
import DropThingsDesignSystem
import DropThingsPlatform
import os

/// Borderless, top-most window shown during a color-pick session. Draws the
/// captured screen dimmed behind a crosshair that follows the cursor. The
/// user clicks to pick the pixel under the crosshair, or presses ESC to
/// cancel.
@MainActor
final class ColorPickerOverlayWindow: NSPanel {
    var onPick: ((CGPoint) -> Void)?
    var onCancel: (() -> Void)?

    private let capturedImage: CGImage
    private let overlayView: OverlayView

    init(capturedImage: CGImage) {
        self.capturedImage = capturedImage
        let view = OverlayView(capturedImage: capturedImage)
        self.overlayView = view
        let unionFrame = ColorPickerOverlayWindow.unionFrame()

        super.init(
            contentRect: unionFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        level = .screenSaver
        isOpaque = false
        backgroundColor = .clear
        ignoresMouseEvents = false
        collectionBehavior = [.fullScreenAuxiliary, .moveToActiveSpace]
        acceptsMouseMovedEvents = true
        contentView = view
        view.frame = unionFrame
        view.onPick = { [weak self] location in
            self?.onPick?(location)
        }
        view.onCancel = { [weak self] in
            self?.onCancel?()
        }
    }

    override var canBecomeKey: Bool { true }

    override func cancelOperation(_ sender: Any?) {
        onCancel?()
    }

    /// Union of every connected `NSScreen.frame`. AppKit's
    /// `NSScreen.screens` already returns full-frame coordinates, so a
    /// simple `min/max` of origin and size covers multi-monitor correctly.
    static func unionFrame() -> CGRect {
        let frames = NSScreen.screens.map(\.frame)
        guard let first = frames.first else {
            return CGRect(x: 0, y: 0, width: 1440, height: 900)
        }
        var minX = first.minX
        var minY = first.minY
        var maxX = first.maxX
        var maxY = first.maxY
        for frame in frames.dropFirst() {
            minX = min(minX, frame.minX)
            minY = min(minY, frame.minY)
            maxX = max(maxX, frame.maxX)
            maxY = max(maxY, frame.maxY)
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}

private final class OverlayView: NSView {
    let capturedImage: CGImage
    var onPick: ((CGPoint) -> Void)?
    var onCancel: (() -> Void)?

    init(capturedImage: CGImage) {
        self.capturedImage = capturedImage
        super.init(frame: .zero)
        let area = NSTrackingArea(
            rect: bounds,
            options: [.activeInKeyWindow, .mouseMoved, .inVisibleRect, .activeAlways],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        onPick?(convert(event.locationInWindow, from: nil))
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.saveGState()
        context.setAlpha(0.35)
        context.draw(capturedImage, in: bounds)
        context.restoreGState()

        let location = NSEvent.mouseLocation
        let local = convert(location, from: nil)

        let size: CGFloat = 12
        let path = NSBezierPath()
        path.lineWidth = 1
        path.move(to: NSPoint(x: local.x - size, y: local.y))
        path.line(to: NSPoint(x: local.x + size, y: local.y))
        path.move(to: NSPoint(x: local.x, y: local.y - size))
        path.line(to: NSPoint(x: local.x, y: local.y + size))
        NSColor.white.setStroke()
        path.stroke()

        let inset = NSBezierPath()
        inset.move(to: NSPoint(x: local.x - size, y: local.y))
        inset.line(to: NSPoint(x: local.x + size, y: local.y))
        inset.move(to: NSPoint(x: local.x, y: local.y - size))
        inset.line(to: NSPoint(x: local.x, y: local.y + size))
        inset.lineWidth = 1
        NSColor.systemBlue.setStroke()
        inset.stroke()
    }
}
