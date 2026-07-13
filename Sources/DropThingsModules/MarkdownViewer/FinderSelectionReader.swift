import Foundation
import AppKit

/// Reads the current Finder selection via AppleScript so the Markdown Viewer
/// hotkey can open the file the user is standing on in Finder.
///
/// Sending an Apple Event to Finder triggers macOS' **Automation** permission
/// prompt the first time (`kTCCServiceAppleEvents` for `com.apple.finder`).
/// This is a progressive enhancement: the core module ships with
/// `requiredPermissions = []` and this is gated behind an opt-in setting.
/// If the user denies Automation, `selectedPaths()` returns nil and the
/// hotkey falls back to opening the viewer with the last document.
///
/// The pure helpers (`parsePaths`, `markdownOnly`) are split out so they can
/// be unit-tested without running AppleScript.
@MainActor
enum FinderSelectionReader {

    struct SelectionError: LocalizedError {
        let message: String

        var errorDescription: String? {
            "Could not read the Finder selection: \(message)"
        }
    }

    /// Run an AppleScript that returns the POSIX paths of the items selected
    /// in the frontmost Finder window, one per line. Throws when Finder or
    /// Automation is unavailable; an empty selection returns an empty array.
    @MainActor
    static func selectedPaths() throws -> [URL] {
        let source = """
        tell application "Finder"
            set sel to selection
            if sel is {} or sel is missing value then return ""
            set output to ""
            repeat with anItem in sel
                set output to output & (POSIX path of (anItem as alias)) & linefeed
            end repeat
            return output
        end tell
        """
        var errorInfo: NSDictionary?
        guard let script = NSAppleScript(source: source) else {
            throw SelectionError(message: "the AppleScript could not be created")
        }
        let result = script.executeAndReturnError(&errorInfo)
        if let errorInfo {
            let message = errorInfo[NSAppleScript.errorMessage] as? String
                ?? "macOS denied Automation access"
            throw SelectionError(message: message)
        }
        let output = result.stringValue ?? ""
        return parsePaths(output)
    }

    /// Pure: split the newline-delimited POSIX path string into URLs.
    /// Empty lines are dropped. `nonisolated` so it can be unit-tested and
    /// reused from any context — it touches no AppKit state.
    nonisolated static func parsePaths(_ output: String) -> [URL] {
        output.split(separator: "\n", omittingEmptySubsequences: true)
            .map { URL(fileURLWithPath: String($0)) }
    }

    /// Pure: keep only files whose extension is a Markdown type.
    nonisolated static func markdownOnly(_ urls: [URL]) -> [URL] {
        urls.filter(MarkdownFileType.accepts)
    }

    /// True when Finder is the frontmost app — the only moment when reading
    /// its selection makes sense.
    static func isFinderFrontmost() -> Bool {
        NSWorkspace.shared.frontmostApplication?.bundleIdentifier == "com.apple.finder"
    }
}
