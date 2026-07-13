import CoreGraphics
import Foundation

/// Narrow boundary around synthetic scroll input. Screenshot Studio does not
/// retain an event tap or post events unless its scrolling mode is running.
public protocol ScrollDriver: Sendable {
    func scroll(at point: CGPoint, deltaY: Int32) throws
}

public enum ScrollDriverError: Error, LocalizedError, Equatable {
    case eventCreationFailed
    public var errorDescription: String? { "macOS could not create a scroll event." }
}

public struct AccessibilityScrollDriver: ScrollDriver {
    public init() {}
    public func scroll(at point: CGPoint, deltaY: Int32) throws {
        guard let event = CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 1, wheel1: deltaY, wheel2: 0, wheel3: 0) else { throw ScrollDriverError.eventCreationFailed }
        event.location = point
        event.post(tap: .cghidEventTap)
    }
}
