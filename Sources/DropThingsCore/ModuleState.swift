import Foundation

/// Canonical lifecycle and failure state shared by all modules.
///
/// The registry, settings UI, and diagnostics surface read this. Transitions are
/// driven by `ModuleRegistry`, not by the module itself, so the UI sees a single
/// authoritative source.
public enum ModuleState: Hashable, Sendable {
    /// The user has disabled the module. It must not run any listeners.
    case off
    /// `start()` has been called but is still in progress.
    case starting
    /// Active and healthy.
    case running
    /// Blocked because one or more `SystemPermission` values are not granted.
    /// The associated value is the set of missing permissions.
    case needsPermission(missing: Set<SystemPermission>)
    /// Unsupported on this macOS version or hardware.
    case unavailable(reason: String)
    /// Started but partially broken. The module should surface what still works.
    case degraded(reason: String)
    /// `start()` threw, or the module self-reported an unrecoverable error.
    case failed(reason: String, recovery: String?)
}

extension ModuleState {
    /// Short label suitable for `ModuleStatusPill`.
    public var shortLabel: String {
        switch self {
        case .off: return "Off"
        case .starting: return "Starting"
        case .running: return "Running"
        case .needsPermission: return "Needs permission"
        case .unavailable: return "Unavailable"
        case .degraded: return "Degraded"
        case .failed: return "Failed"
        }
    }

    /// `true` if the module is currently doing real work the user can rely on.
    public var isActive: Bool {
        switch self {
        case .running, .degraded: return true
        default: return false
        }
    }

    /// `true` if the module is intentionally disabled by the user.
    public var isOff: Bool {
        if case .off = self { return true }
        return false
    }

    /// `true` if the module has been started (or attempted) and is not
    /// waiting on a permission grant. Use this to gate side effects like
    /// re-registering a hotkey after a settings change: a module that is
    /// `.degraded` from a previous hotkey conflict should still retry
    /// when the user picks a new combo, but a module that is `.off` or
    /// waiting on Accessibility must not touch the global hotkey registry.
    public var isStarted: Bool {
        switch self {
        case .off, .needsPermission: return false
        case .starting, .running, .unavailable, .degraded, .failed: return true
        }
    }

    /// Concise detail for the bounded diagnostics buffer.
    public var diagnosticDescription: String {
        switch self {
        case .off, .starting, .running:
            return shortLabel
        case .needsPermission(let missing):
            let names = missing.map(\.displayName).sorted().joined(separator: ", ")
            return "Needs permission: \(names)"
        case .unavailable(let reason), .degraded(let reason):
            return "\(shortLabel): \(reason)"
        case .failed(let reason, let recovery):
            return recovery.map { "Failed: \(reason) — \($0)" } ?? "Failed: \(reason)"
        }
    }
}
