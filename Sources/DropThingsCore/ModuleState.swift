import Foundation

/// Lifecycle state for a module. Mirrors `docs/architecture.md#failure-model`.
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
        if case .running = self { return true }
        return false
    }

    /// `true` if the module is intentionally disabled by the user.
    public var isOff: Bool {
        if case .off = self { return true }
        return false
    }
}
