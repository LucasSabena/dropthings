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

    /// Acquire the assertion. Returns `true` if the assertion is now held
    /// (either freshly created or already held for the same reason).
    @discardableResult
    public func acquire(reason: Reason) throws -> Bool {
        if id != 0 {
            return heldReason == reason
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
