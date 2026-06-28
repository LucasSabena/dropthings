import Foundation
import DropThingsPlatform

/// Pure, deterministic scroll-event transformation. Given the raw fields and
/// the user's settings, decide what to write back. No CoreGraphics types
/// here, so this is testable without an event tap.
public struct ScrollEventTransformer: Sendable {
    public let settings: ScrollSettings

    public init(settings: ScrollSettings) {
        self.settings = settings
    }

    /// Classify a scroll event by device category. The heuristic looks at the
    /// inertial-scroll phases: trackpads and Magic Mouse set a non-zero phase
    /// during and after the user's gesture, mouse wheels always report zero.
    /// Between trackpad and Magic Mouse we differentiate by point delta:
    /// trackpads send high-resolution points, Magic Mouse sends the same data
    /// but only on contact (and discrete step events when the finger leaves
    /// the surface).
    public func classify(_ input: ScrollEventInput) -> ScrollDeviceKind {
        let hasPhase = input.phase != 0 || input.momentumPhase != 0
        if hasPhase {
            return .trackpad
        }
        if input.fixedDeltaY != 0 || input.fixedDeltaX != 0 {
            return .mouseWheel
        }
        if input.pointDeltaY != 0 || input.pointDeltaX != 0 {
            // No phase, no fixed steps, but there are point deltas: this is
            // Magic Mouse finger-scroll on the touch surface.
            return .magicMouse
        }
        return .unknown
    }

    public func transform(_ input: ScrollEventInput) -> ScrollEventDecision {
        let kind = classify(input)
        let direction = settings.direction(for: kind)

        guard direction == .inverted else {
            return ScrollEventDecision(
                deviceKind: kind,
                pointDeltaY: input.pointDeltaY,
                pointDeltaX: input.pointDeltaX,
                fixedDeltaY: input.fixedDeltaY,
                fixedDeltaX: input.fixedDeltaX,
                didMutate: false
            )
        }

        let multiplier = settings.scrollMultiplier
        return ScrollEventDecision(
            deviceKind: kind,
            pointDeltaY: -input.pointDeltaY * multiplier,
            pointDeltaX: settings.horizontalScrollEnabled ? -input.pointDeltaX * multiplier : 0,
            fixedDeltaY: Int64((Double(-input.fixedDeltaY) * multiplier).rounded()),
            fixedDeltaX: settings.horizontalScrollEnabled ? Int64((Double(-input.fixedDeltaX) * multiplier).rounded()) : 0,
            didMutate: true
        )
    }
}
