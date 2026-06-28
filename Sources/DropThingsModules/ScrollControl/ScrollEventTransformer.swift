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
    /// continuous flag first: physical wheels are normally discrete. Trackpads
    /// advertise scroll or momentum phases; Magic Mouse often appears as a
    /// continuous point-delta event without those phases.
    public func classify(_ input: ScrollEventInput) -> ScrollDeviceKind {
        if !input.isContinuous && (input.fixedDeltaY != 0 || input.fixedDeltaX != 0) {
            return .mouseWheel
        }
        let hasPhase = input.phase != 0 || input.momentumPhase != 0
        if hasPhase {
            return .trackpad
        }
        if input.fixedDeltaY != 0 || input.fixedDeltaX != 0 {
            return .mouseWheel
        }
        if input.pointDeltaY != 0 || input.pointDeltaX != 0
            || input.fixedPointDeltaY != 0 || input.fixedPointDeltaX != 0 {
            return .magicMouse
        }
        return .unknown
    }

    public func transform(_ input: ScrollEventInput, activeBundleID: String? = nil) -> ScrollEventDecision {
        let kind = classify(input)
        let direction = settings.direction(for: kind, activeBundleID: activeBundleID)
        let invert = direction == .inverted
        let multiplier = settings.multiplier(for: kind, activeBundleID: activeBundleID)
        let verticalFactor = invert ? -multiplier : multiplier
        let horizontalFactor: Double = {
            guard settings.horizontalScrollEnabled else { return 0 }
            return invert ? -multiplier : multiplier
        }()

        let pointX = input.pointDeltaX * horizontalFactor
        let fixedX = Self.scaledInteger(input.fixedDeltaX, by: horizontalFactor)
        let fixedPointX = input.fixedPointDeltaX * horizontalFactor
        let horizontalWasSuppressed = !settings.horizontalScrollEnabled
            && (input.pointDeltaX != 0 || input.fixedDeltaX != 0 || input.fixedPointDeltaX != 0)
        return ScrollEventDecision(
            deviceKind: kind,
            pointDeltaY: input.pointDeltaY * verticalFactor,
            pointDeltaX: pointX,
            fixedDeltaY: Self.scaledInteger(input.fixedDeltaY, by: verticalFactor),
            fixedDeltaX: fixedX,
            fixedPointDeltaY: input.fixedPointDeltaY * verticalFactor,
            fixedPointDeltaX: fixedPointX,
            didMutate: invert || horizontalWasSuppressed
        )
    }

    private static func scaledInteger(_ value: Int64, by factor: Double) -> Int64 {
        guard value != 0, factor != 0 else { return 0 }
        let scaled = Double(value) * factor
        let rounded = Int64(scaled.rounded())
        if rounded != 0 { return rounded }
        return scaled > 0 ? 1 : -1
    }
}
