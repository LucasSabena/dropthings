import AppKit
import os

/// Thin wrapper over `NSStatusItem` so modules do not deal with the
/// target/action dance. Each instance owns one status item and exposes a
/// closure-based click handler. The click is delivered on the main thread.
@MainActor
public final class DropThingsStatusItem {
    public let statusItem: NSStatusItem
    private let clickTarget: ClickTarget

    public init(length: CGFloat = NSStatusItem.variableLength) {
        statusItem = NSStatusBar.system.statusItem(withLength: length)
        clickTarget = ClickTarget()
        if let button = statusItem.button {
            button.target = clickTarget
            button.action = #selector(ClickTarget.handleClick(_:))
        }
    }

    deinit {
        NSStatusBar.system.removeStatusItem(statusItem)
    }

    public func setSymbol(_ name: String, accessibilityDescription: String? = nil) {
        statusItem.button?.image = NSImage(
            systemSymbolName: name,
            accessibilityDescription: accessibilityDescription
        )
    }

    public func setTitle(_ title: String) {
        statusItem.button?.title = title
    }

    public func setOnClick(_ handler: @escaping @MainActor () -> Void) {
        clickTarget.handler = handler
    }

    public func show() {
        statusItem.isVisible = true
    }

    public func hide() {
        statusItem.isVisible = false
    }

    public var isVisible: Bool {
        statusItem.isVisible
    }
}

private final class ClickTarget: NSObject {
    var handler: (() -> Void)?

    @objc func handleClick(_ sender: Any?) {
        handler?()
    }
}
