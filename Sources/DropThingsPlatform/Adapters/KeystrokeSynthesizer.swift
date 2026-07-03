import AppKit
import CoreGraphics

/// Synthesizes a system-wide ⌘V so a clipboard item can be pasted into the app
/// that had focus before DropThings' panel came up. This is the only way to
/// "paste at the cursor" without an AXUIElement-per-app script; it requires
/// Accessibility permission because it posts input events into other apps.
///
/// Narrow interface on purpose: callers only ask to post a paste. The CGEvent
/// dance stays here. State is checkable via `isAccessibilityGranted()` so the
/// module can request the permission and fall back gracefully when denied.
public enum KeystrokeSynthesizer {
    /// `true` when macOS currently trusts this process for Accessibility.
    /// Re-checked on every call because the user can revoke at any time.
    public static func isAccessibilityGranted() -> Bool {
        AXIsProcessTrusted()
    }

    /// Posts a ⌘V keypress into the current keyboard target. Returns `false`
    /// if the event source could not be created (no permission, or the system
    /// refused). Does not throw: the caller decides what to show on `false`.
    @discardableResult
    public static func postPaste() -> Bool {
        guard let source = CGEventSource(stateID: .hidSystemState) else { return false }
        // kVK_ANSI_V == 9. maskCommand alone; we must not add other modifiers.
        let keyCode: CGKeyCode = 9
        guard
            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        else { return false }
        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
        return true
    }
}
