import AppKit

/// Resolves a bundle identifier to a human-readable application name.
///
/// Looks up the installed application via `NSWorkspace`, then reads
/// `CFBundleDisplayName` or `CFBundleName` from the bundle's info
/// dictionary. If no name is available, falls back to the executable
/// name derived from the app URL. If the bundle is not installed, the
/// original bundle identifier is returned so callers always get a
/// non-empty label.
public func applicationName(forBundleID bundleID: String) -> String {
    // Launch Services treats an empty identifier as a wildcard-like lookup on
    // some macOS releases and may return an unrelated helper application.
    // Preserve invalid input instead of leaking that implementation detail to
    // exclusion lists and diagnostics.
    guard !bundleID.isEmpty else { return bundleID }

    guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
        return bundleID
    }

    let bundle = Bundle(url: url)
    if let displayName = bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String,
       !displayName.isEmpty {
        return displayName
    }
    if let name = bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String,
       !name.isEmpty {
        return name
    }

    let fallback = url.deletingPathExtension().lastPathComponent
    return fallback.isEmpty ? bundleID : fallback
}
