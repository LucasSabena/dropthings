import Foundation
import AppKit
import ApplicationServices

/// Read-only bundle facts useful for the Diagnostics panel. Built once at
/// `AppServices` init because none of these change at runtime.
struct BundleInfo {
    let bundleIdentifier: String
    let bundlePath: String
    let shortVersion: String
    let buildNumber: String
    let axIsProcessTrusted: Bool

    static func current() -> BundleInfo {
        let bundle = Bundle.main
        return BundleInfo(
            bundleIdentifier: bundle.bundleIdentifier ?? "(missing CFBundleIdentifier)",
            bundlePath: bundle.bundlePath,
            shortVersion: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0",
            buildNumber: bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0",
            axIsProcessTrusted: AXIsProcessTrusted()
        )
    }

    /// Human-readable hint for the user when Accessibility appears stuck.
    /// The macOS TCC database keys entries by the bundle's absolute path at
    /// the moment the user granted access. If the app is rebuilt or moved,
    /// the stored entry does not match the current path and `AXIsProcessTrusted`
    /// returns false even though the user thinks they granted it. Resetting
    /// TCC and re-granting fixes it.
    static let resetHint = """
    If Accessibility shows Granted here but the module still says Needs permission:

    1. Quit DropThings.
    2. Run in Terminal.app:
         tccutil reset Accessibility app.dropthings
    3. Open DropThings again.
    4. Click "Request Access" on the Accessibility row.
    """
}
