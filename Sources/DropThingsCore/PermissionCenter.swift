import Foundation
import Combine
import AppKit

/// Source of truth for "is this permission granted right now?". Wrapped in a
/// protocol so tests can substitute a deterministic fake. The real backend
/// hits AppKit / CoreGraphics each call.
public protocol PermissionBackend: Sendable {
    @MainActor
    func currentState(for permission: SystemPermission) -> SystemPermissionState

    /// Open System Settings on the right pane. Returns `true` if macOS accepted
    /// the open request; the user may still decline inside System Settings.
    @MainActor
    func openSystemSettings(for permission: SystemPermission) -> Bool
}

/// Coarse-grained permission state. `unknown` covers permissions macOS does
/// not let us query directly (Full Disk Access, Automation on some setups).
public enum SystemPermissionState: Hashable, Sendable {
    case granted
    case denied
    case notDetermined
    case unknown
}

extension SystemPermissionState {
    public var displayName: String {
        switch self {
        case .granted: return "Allowed"
        case .denied: return "Needs attention"
        case .notDetermined: return "Not requested"
        case .unknown: return "Check in Settings"
        }
    }

    public var isGranted: Bool { self == .granted }
}

extension PermissionBackend {
    /// `true` when the user can use features behind this permission.
    @MainActor
    public func isUsable(_ permission: SystemPermission) -> Bool {
        currentState(for: permission) == .granted
    }
}

/// Default macOS backend. Re-checks on demand because macOS can revoke
/// permissions at any time (especially Accessibility and Screen Recording).
public struct MacOSPermissionBackend: PermissionBackend {
    public init() {}

    public func currentState(for permission: SystemPermission) -> SystemPermissionState {
        switch permission {
        case .accessibility:
            return AXIsProcessTrusted() ? .granted : .notDetermined
        case .screenRecording:
            return CGPreflightScreenCaptureAccess() ? .granted : .notDetermined
        case .fullDiskAccess:
            // No public API to query. We surface `.unknown` and rely on the
            // module that needs it to attempt access and report failure.
            return .unknown
        case .automation:
            return .unknown
        }
    }

    @MainActor
    public func openSystemSettings(for permission: SystemPermission) -> Bool {
        guard let url = permission.settingsPaneURL else { return false }
        return NSWorkspace.shared.open(url)
    }

    /// Trigger macOS's native Accessibility prompt so the app appears in
    /// System Settings → Privacy & Security → Accessibility. Calling
    /// `AXIsProcessTrusted()` alone never registers the app; this is the
    /// only supported entry point.
    @MainActor
    public func requestAccessibility() -> Bool {
        let promptKey = "AXTrustedCheckOptionPrompt" as CFString
        let options = [promptKey: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    /// Trigger macOS's native Screen Recording prompt. Same pattern as
    /// Accessibility: the OS dialog is what registers the app in System
    /// Settings.
    @MainActor
    public func requestScreenRecording() -> Bool {
        // CGRequestScreenCaptureAccess shows the system prompt directly on
        // macOS 10.15+. Returns true if the user already granted it.
        return CGRequestScreenCaptureAccess()
    }
}

/// Tracks permission state for every module and exposes a single observable
/// surface to the UI. Re-checking is cheap; we do not poll, we re-check on
/// `refresh()` and on app activation.
///
/// macOS does not expose a true "denied" state for Accessibility or Screen
/// Recording; the APIs only return `.granted` or `.notDetermined`. We infer
/// `.denied` by remembering whether we already showed the system prompt for a
/// permission. If the flag is set and the permission is still not granted, the
/// user declined it.
@MainActor
public final class PermissionCenter: ObservableObject {
    public static let promptedKey = SettingsKey("core.permissions.prompted")

    @Published public private(set) var states: [SystemPermission: SystemPermissionState] = [:]

    private let backend: PermissionBackend
    private let settings: SettingsStore?

    public init(backend: PermissionBackend = MacOSPermissionBackend(), settings: SettingsStore? = nil) {
        self.backend = backend
        self.settings = settings
        refresh()
    }

    public func state(for permission: SystemPermission) -> SystemPermissionState {
        states[permission] ?? .unknown
    }

    /// Re-query every known permission. Call on app activation and after the
    /// user returns from System Settings.
    public func refresh() {
        let prompted = promptedPermissions()
        var next: [SystemPermission: SystemPermissionState] = [:]
        for permission in SystemPermission.allCases {
            let backendState = backend.currentState(for: permission)
            if prompted.contains(permission.rawValue), backendState != .granted {
                next[permission] = .denied
            } else {
                next[permission] = backendState
            }
        }
        if states != next {
            states = next
        }
    }

    @discardableResult
    public func openSystemSettings(for permission: SystemPermission) -> Bool {
        backend.openSystemSettings(for: permission)
    }

    /// Trigger macOS's native permission prompt for the given permission.
    /// Without this, the app never appears in System Settings and the user
    /// has no way to grant the permission through normal UI flows.
    ///
    /// For Accessibility and Screen Recording we record that the prompt was
    /// shown so a later `refresh()` can report `.denied` if the user declined.
    @MainActor
    @discardableResult
    public func requestPermission(_ permission: SystemPermission) -> Bool {
        let result: Bool
        if let backend = backend as? MacOSPermissionBackend {
            switch permission {
            case .accessibility:
                result = backend.requestAccessibility()
            case .screenRecording:
                result = backend.requestScreenRecording()
            case .fullDiskAccess, .automation:
                result = backend.openSystemSettings(for: permission)
            }
        } else {
            result = backend.openSystemSettings(for: permission)
        }

        if permission.supportsSystemPrompt {
            markPrompted(permission)
        }
        // CGRequestScreenCaptureAccess and AXIsProcessTrustedWithOptions can
        // return after the user approves access. Refresh immediately so the
        // sheet does not keep showing a stale "Needs attention" state.
        refresh()
        return result
    }

    /// Clear the "prompt was shown" inference for explicit maintenance or
    /// tests. Normal enable/disable flows must preserve it so a rejection never
    /// masquerades as a first request.
    public func resetPromptState(for permission: SystemPermission) {
        var prompted = promptedPermissions()
        guard prompted.remove(permission.rawValue) != nil else { return }
        persistPrompted(prompted)
    }

    public func hasRequested(_ permission: SystemPermission) -> Bool {
        promptedPermissions().contains(permission.rawValue)
    }

    /// Convenience for the module detail pane: which of `required` are still
    /// missing given the latest known state.
    public func missing(from required: [SystemPermission]) -> Set<SystemPermission> {
        var missing: Set<SystemPermission> = []
        for permission in required where state(for: permission) != .granted {
            missing.insert(permission)
        }
        return missing
    }

    // MARK: - Prompted persistence

    private func markPrompted(_ permission: SystemPermission) {
        var prompted = promptedPermissions()
        guard prompted.insert(permission.rawValue).inserted else { return }
        persistPrompted(prompted)
    }

    private func promptedPermissions() -> Set<String> {
        guard let settings else { return [] }
        guard let data = settings.data(Self.promptedKey) else { return [] }
        return (try? JSONDecoder().decode(Set<String>.self, from: data)) ?? []
    }

    private func persistPrompted(_ prompted: Set<String>) {
        guard let settings else { return }
        guard let data = try? JSONEncoder().encode(prompted) else { return }
        settings.setData(data, Self.promptedKey)
    }
}
