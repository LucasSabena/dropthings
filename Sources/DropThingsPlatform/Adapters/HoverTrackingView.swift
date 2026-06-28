import AppKit

/// A tiny `NSView` that reports `mouseEntered`/`mouseExited` to closures.
/// Used by modules that need hover behavior on a status item button without
/// owning a view hierarchy.
public final class HoverTrackingView: NSView {
    public var onEnter: (() -> Void)?
    public var onExit: (() -> Void)?

    public init() {
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("HoverTrackingView is built in code only.")
    }

    public override func mouseEntered(with event: NSEvent) {
        onEnter?()
    }

    public override func mouseExited(with event: NSEvent) {
        onExit?()
    }
}
