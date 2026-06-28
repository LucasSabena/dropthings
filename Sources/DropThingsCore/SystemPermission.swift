import Foundation

/// macOS permissions DropThings may ask for. Keep the set small: each extra
/// permission makes the app harder to trust. See
/// `docs/permissions-security.md` for the principles.
public enum SystemPermission: String, Hashable, Sendable, CaseIterable {
    case accessibility
    case screenRecording
    case fullDiskAccess
    case automation
}

extension SystemPermission {
    /// Human-readable title shown next to the toggle.
    public var displayName: String {
        switch self {
        case .accessibility: return "Accessibility"
        case .screenRecording: return "Screen Recording"
        case .fullDiskAccess: return "Full Disk Access"
        case .automation: return "Automation"
        }
    }

    /// Why a module needs this. Keep one sentence; longer copy belongs in the
    /// module's settings view.
    public var reason: String {
        switch self {
        case .accessibility:
            return "Required to observe and modify input events."
        case .screenRecording:
            return "Required only to detect menu bar items visually."
        case .fullDiskAccess:
            return "Required to read files outside the app sandbox."
        case .automation:
            return "Required to control other apps on your behalf."
        }
    }

    /// Path in System Settings the user must visit to grant this permission.
    /// Returned as a `URL` so the OS can present the pane when supported.
    public var settingsPaneURL: URL? {
        var components = URLComponents()
        components.scheme = "x-apple.systempreferences"
        switch self {
        case .accessibility:
            components.host = "com.apple.preference.universalaccess"
        case .screenRecording:
            components.host = "com.apple.preference.security"
            components.queryItems = [URLQueryItem(name: "Privacy_ScreenCapture", value: "1")]
        case .fullDiskAccess:
            components.host = "com.apple.preference.security"
            components.queryItems = [URLQueryItem(name: "Privacy_AllFiles", value: "1")]
        case .automation:
            return nil
        }
        return components.url
    }
}
