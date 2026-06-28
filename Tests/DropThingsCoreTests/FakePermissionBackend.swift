import Foundation
import AppKit
@testable import DropThingsCore

/// Deterministic permission backend for tests.
final class FakePermissionBackend: PermissionBackend, @unchecked Sendable {
    var states: [SystemPermission: SystemPermissionState] = [:]
    var openCount: [SystemPermission: Int] = [:]

    init(states: [SystemPermission: SystemPermissionState] = [:]) {
        self.states = states
    }

    func currentState(for permission: SystemPermission) -> SystemPermissionState {
        if let stored = states[permission] { return stored }
        // Default unknown permissions (Full Disk Access, Automation) to
        // `.unknown` to mirror `MacOSPermissionBackend` so tests can assert
        // the production behavior without depending on the real backend.
        return permission.isAlwaysUnknown ? .unknown : .notDetermined
    }

    @MainActor
    func openSystemSettings(for permission: SystemPermission) -> Bool {
        openCount[permission, default: 0] += 1
        return true
    }
}

private extension SystemPermission {
    var isAlwaysUnknown: Bool {
        switch self {
        case .fullDiskAccess, .automation: return true
        case .accessibility, .screenRecording: return false
        }
    }
}
