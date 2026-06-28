import Foundation
import IOKit.pwr_mgt

/// Single-purpose wrapper around `IOPMAssertionCreateWithName` /
/// `IOPMAssertionRelease`. Holds at most one assertion at a time.
/// `acquire` is idempotent: a second call before `release` is a no-op.
@MainActor
public final class KeepAwakeAssertion {
    public enum FailureReason: Error, Equatable {
        case alreadyHeld
        case osStatus(Int32)
    }

    /// The two assertion types we wrap. The names match Apple's
    /// `kIOPMAssertionTypePreventUserIdleSystemSleep` /
    /// `kIOPMAssertionTypePreventUserIdleDisplaySleep`.
    ///
    /// Important: `displaySleep` keeps the display awake but does NOT
    /// prevent the system from idling to sleep. `systemSleep` keeps the
    /// system awake; the display may still dim if the user's power
    /// settings say so. Most users want `systemSleep` to "keep my Mac
    /// awake".
    public enum Reason: String, Sendable, CaseIterable, Codable {
        case systemSleep
        case displaySleep

        var assertionType: String {
            switch self {
            case .systemSleep: return "PreventUserIdleSystemSleep"
            case .displaySleep: return "PreventUserIdleDisplaySleep"
            }
        }
    }

    private var id: IOPMAssertionID = 0
    private var heldReason: Reason?

    public init() {}

    public var isActive: Bool { id != 0 }
    public var currentReason: Reason? { heldReason }
    public var currentAssertionID: IOPMAssertionID { id }

    /// Acquire the assertion. If the assertion is already held for a
    /// different reason, release the old one and acquire the new so the
    /// system reflects the user's latest choice. Returns `true` when the
    /// assertion is now held for the requested reason.
    @discardableResult
    public func acquire(reason: Reason) throws -> Bool {
        if id != 0 {
            if heldReason == reason { return true }
            release()
        }
        let name = "DropThings — \(reason.assertionType)" as CFString
        let type = reason.assertionType as CFString
        var newId: IOPMAssertionID = 0
        let status = IOPMAssertionCreateWithName(
            type,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            name,
            &newId
        )
        guard status == kIOReturnSuccess else {
            throw FailureReason.osStatus(status)
        }
        id = newId
        heldReason = reason
        return true
    }

    public func release() {
        guard id != 0 else { return }
        IOPMAssertionRelease(id)
        id = 0
        heldReason = nil
    }
}
