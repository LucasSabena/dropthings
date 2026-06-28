import Foundation
import CoreGraphics

/// Heuristic classification of a scroll source. Order matters: trackpad and
/// Magic Mouse share the inertial-phase path, mouse wheels never report
/// one. The transformer uses this to pick which setting to apply.
public enum ScrollDeviceKind: String, Codable, Sendable, CaseIterable {
    case trackpad
    case mouseWheel
    case magicMouse
    case unknown
}

/// Pure, testable snapshot of the scroll-event fields we care about. Lifting
/// them off `CGEvent` lets the transformer be unit-tested without spinning
/// up the CoreGraphics event system.
public struct ScrollEventInput: Equatable, Sendable {
    /// Trackpad point delta on the primary axis (vertical). Zero for mouse
    /// wheels.
    public let pointDeltaY: Double
    /// Trackpad point delta on the secondary axis (horizontal). Zero for
    /// mouse wheels.
    public let pointDeltaX: Double
    /// Discrete step on the primary axis. Non-zero for mouse wheels.
    public let fixedDeltaY: Int64
    /// Discrete step on the secondary axis. Non-zero for mouse wheels when
    /// the wheel tilts.
    public let fixedDeltaX: Int64
    /// Phase for inertial trackpad scrolling. `0` means "not a trackpad in
    /// momentum".
    public let phase: Int64
    /// Momentum phase. Non-zero for ongoing inertial scrolling.
    public let momentumPhase: Int64

    public init(
        pointDeltaY: Double,
        pointDeltaX: Double,
        fixedDeltaY: Int64,
        fixedDeltaX: Int64,
        phase: Int64,
        momentumPhase: Int64
    ) {
        self.pointDeltaY = pointDeltaY
        self.pointDeltaX = pointDeltaX
        self.fixedDeltaY = fixedDeltaY
        self.fixedDeltaX = fixedDeltaX
        self.phase = phase
        self.momentumPhase = momentumPhase
    }

    public static let empty = ScrollEventInput(
        pointDeltaY: 0,
        pointDeltaX: 0,
        fixedDeltaY: 0,
        fixedDeltaX: 0,
        phase: 0,
        momentumPhase: 0
    )
}

/// Decision returned by `ScrollEventTransformer`. The caller applies the
/// deltas back to the live `CGEvent`. `didMutate` lets the caller skip the
/// write-back when nothing changed (avoids touching events we passed
/// through).
public struct ScrollEventDecision: Equatable, Sendable {
    public let deviceKind: ScrollDeviceKind
    public let pointDeltaY: Double
    public let pointDeltaX: Double
    public let fixedDeltaY: Int64
    public let fixedDeltaX: Int64
    public let didMutate: Bool

    public init(
        deviceKind: ScrollDeviceKind,
        pointDeltaY: Double,
        pointDeltaX: Double,
        fixedDeltaY: Int64,
        fixedDeltaX: Int64,
        didMutate: Bool
    ) {
        self.deviceKind = deviceKind
        self.pointDeltaY = pointDeltaY
        self.pointDeltaX = pointDeltaX
        self.fixedDeltaY = fixedDeltaY
        self.fixedDeltaX = fixedDeltaX
        self.didMutate = didMutate
    }
}

extension ScrollEventInput {
    /// Pull the fields we care about out of a `CGEvent`. Centralizing this
    /// here means the transformer stays free of CoreGraphics types.
    public static func from(event: CGEvent) -> ScrollEventInput {
        let pointY = event.getDoubleValueField(.scrollWheelEventPointDeltaAxis1)
        let pointX = event.getDoubleValueField(.scrollWheelEventPointDeltaAxis2)
        let fixedY = event.getIntegerValueField(.scrollWheelEventDeltaAxis1)
        let fixedX = event.getIntegerValueField(.scrollWheelEventDeltaAxis2)
        let phase = event.getIntegerValueField(.scrollWheelEventScrollPhase)
        let momentum = event.getIntegerValueField(.scrollWheelEventMomentumPhase)
        return ScrollEventInput(
            pointDeltaY: pointY,
            pointDeltaX: pointX,
            fixedDeltaY: fixedY,
            fixedDeltaX: fixedX,
            phase: phase,
            momentumPhase: momentum
        )
    }
}

extension ScrollEventDecision {
    /// Write the decision back onto a live `CGEvent`. Caller must have
    /// already determined `didMutate` to avoid touching the event when no
    /// change is needed.
    public func apply(to event: CGEvent) {
        event.setDoubleValueField(.scrollWheelEventPointDeltaAxis1, value: pointDeltaY)
        event.setDoubleValueField(.scrollWheelEventPointDeltaAxis2, value: pointDeltaX)
        event.setIntegerValueField(.scrollWheelEventDeltaAxis1, value: fixedDeltaY)
        event.setIntegerValueField(.scrollWheelEventDeltaAxis2, value: fixedDeltaX)
    }
}
