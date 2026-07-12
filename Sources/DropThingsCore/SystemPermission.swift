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
            return "Scroll Control uses this to adjust scroll-wheel events."
        case .screenRecording:
            return "Required by modules that capture visible screen content."
        case .fullDiskAccess:
            return "Required to read files outside the app sandbox."
        case .automation:
            return "Required to control other apps on your behalf."
        }
    }

    public var iconName: String {
        switch self {
        case .accessibility: return "accessibility"
        case .screenRecording: return "rectangle.inset.filled.and.person.filled"
        case .fullDiskAccess: return "externaldrive.badge.checkmark"
        case .automation: return "gearshape.2"
        }
    }

    /// Plain-language trust boundary shown before macOS presents its own
    /// permission UI. This is deliberately specific about what DropThings
    /// does and which broader capabilities it does not need.
    public var privacyDetail: String {
        switch self {
        case .accessibility:
            return "DropThings listens only for scroll events while Scroll Control is enabled. It does not need Screen Recording or Full Disk Access for this feature."
        case .screenRecording:
            return "Allows a feature to read pixels currently visible on your displays."
        case .fullDiskAccess:
            return "Allows access to protected files outside the app container."
        case .automation:
            return "Allows DropThings to send commands to another app after you approve that app."
        }
    }

    public var settingsPath: String {
        switch self {
        case .accessibility: return "Privacy & Security → Accessibility"
        case .screenRecording: return "Privacy & Security → Screen & System Audio Recording"
        case .fullDiskAccess: return "Privacy & Security → Full Disk Access"
        case .automation: return "Privacy & Security → Automation"
        }
    }

    public var supportsSystemPrompt: Bool {
        switch self {
        case .accessibility, .screenRecording: return true
        case .fullDiskAccess, .automation: return false
        }
    }

    /// Path in System Settings the user must visit to grant this permission.
    /// Returned as a `URL` so the OS can present the pane when supported.
    public var settingsPaneURL: URL? {
        var components = URLComponents()
        components.scheme = "x-apple.systempreferences"
        switch self {
        case .accessibility:
            components.host = "com.apple.preference.security"
            components.queryItems = [URLQueryItem(name: "Privacy_Accessibility", value: "1")]
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
