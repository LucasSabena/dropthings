import Foundation
import IOKit.pwr_mgt

/// Abstract interface for the KeepAwake assertion adapter so tests can
/// substitute a fake and avoid real IOKit calls.
@MainActor
public protocol KeepAwakeAssertionProtocol: AnyObject {
    var isActive: Bool { get }
    var currentAssertionIDs: [UInt32] { get }
    func acquireKeepAwakeAssertions(keepDisplayAwake: Bool) throws
    func release()
}

/// Single-purpose wrapper around `IOPMAssertionCreateWithName` /
/// `IOPMAssertionRelease`. Holds one assertion per reason so Keep Awake can
/// prevent both system idle sleep and display sleep at the same time.
/// `acquire` is idempotent: a second call before `release` is a no-op.
@MainActor
public final class KeepAwakeAssertion: KeepAwakeAssertionProtocol {
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
            case .systemSleep: return kIOPMAssertionTypePreventUserIdleSystemSleep as String
            case .displaySleep: return kIOPMAssertionTypePreventUserIdleDisplaySleep as String
            }
        }
    }

    private var idsByReason: [Reason: IOPMAssertionID] = [:]

    public init() {}

    public var isActive: Bool { !idsByReason.isEmpty }
    public var currentReasons: Set<Reason> { Set(idsByReason.keys) }
    public var currentAssertionIDs: [IOPMAssertionID] {
        Reason.allCases.compactMap { idsByReason[$0] }
    }
    public var currentAssertionID: IOPMAssertionID {
        currentAssertionIDs.first ?? 0
    }

    /// Acquire the assertion for one reason. Returns `true` when the
    /// assertion is now held for the requested reason.
    @discardableResult
    public func acquire(reason: Reason) throws -> Bool {
        if idsByReason[reason] != nil { return true }
        let name = "DropThings - \(reason.assertionType)" as CFString
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
        idsByReason[reason] = newId
        return true
    }

    /// Keep the system awake and optionally keep the display lit. Display sleep
    /// remains under the user's normal Energy settings unless explicitly asked
    /// for, which is the battery-friendly default.
    public func acquireKeepAwakeAssertions(keepDisplayAwake: Bool) throws {
        let desired: Set<Reason> = keepDisplayAwake ? [.systemSleep, .displaySleep] : [.systemSleep]
        do {
            for reason in idsByReason.keys where !desired.contains(reason) {
                release(reason: reason)
            }
            for reason in desired {
                try acquire(reason: reason)
            }
        } catch {
            release()
            throw error
        }
    }

    private func release(reason: Reason) {
        guard let id = idsByReason.removeValue(forKey: reason) else { return }
        IOPMAssertionRelease(id)
    }

    public func release() {
        for id in idsByReason.values {
            IOPMAssertionRelease(id)
        }
        idsByReason.removeAll()
    }
}
