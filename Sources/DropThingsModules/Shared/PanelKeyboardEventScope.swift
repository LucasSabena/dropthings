import AppKit

/// Prevents a local keyboard monitor owned by a hidden panel from consuming
/// events delivered to a different DropThings window.
enum PanelKeyboardEventScope {
    static func accepts(_ event: NSEvent, expectedWindowNumber: Int) -> Bool {
        accepts(
            windowNumber: event.windowNumber,
            isKeyWindow: event.window?.isKeyWindow == true,
            expectedWindowNumber: expectedWindowNumber
        )
    }

    static func accepts(
        windowNumber: Int,
        isKeyWindow: Bool,
        expectedWindowNumber: Int
    ) -> Bool {
        isKeyWindow && windowNumber == expectedWindowNumber
    }
}
