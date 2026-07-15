import Foundation
import AppKit
import DropThingsPlatform

/// Thin wrapper over the shared pasteboard reader so the module's call sites
/// stay narrow and testable. The real parsing lives in `ClipboardMonitor.read`
/// (Platform) so it never drifts from the poller's behavior.
public enum SmartClipboardReader {
    @MainActor
    public static func read(pasteboard: NSPasteboard) -> ClipboardMonitor.Item? {
        ClipboardMonitor.read(pasteboard)
    }
}