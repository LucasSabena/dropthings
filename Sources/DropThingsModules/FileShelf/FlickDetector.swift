import Foundation

/// Pure, testable detector for a "flick the mouse up to the top of the
/// screen" gesture — the primary way to summon the shelf so it drops from
/// the notch / menu bar area. Fires when the cursor reaches the top band
/// of a screen having moved upward fast enough within the window.
///
/// The screen geometry is supplied by the caller on each sample, so this
/// type has no AppKit dependency and is fully unit-testable.
public struct FlickDetector: Sendable {
    public struct Sample: Equatable, Sendable {
        public let timestamp: TimeInterval
        public let y: Double
        public let ceilingY: Double

        public init(timestamp: TimeInterval, y: Double, ceilingY: Double) {
            self.timestamp = timestamp
            self.y = y
            self.ceilingY = ceilingY
        }
    }

    public let windowDuration: TimeInterval
    public let minUpwardDistance: Double
    public let ceilingBandHeight: Double

    private var samples: [Sample] = []

    public init(
        windowDuration: TimeInterval = 0.35,
        minUpwardDistance: Double = 220,
        ceilingBandHeight: Double = 6
    ) {
        self.windowDuration = windowDuration
        self.minUpwardDistance = minUpwardDistance
        self.ceilingBandHeight = ceilingBandHeight
    }

    public mutating func record(_ sample: Sample) {
        samples.append(sample)
        let cutoff = sample.timestamp - windowDuration
        if let firstFresh = samples.firstIndex(where: { $0.timestamp >= cutoff }), firstFresh > 0 {
            samples.removeFirst(firstFresh)
        }
    }

    public mutating func reset() {
        samples.removeAll(keepingCapacity: true)
    }

    /// `true` when the cursor ended in the top band of the screen and got
    /// there by moving up at least `minUpwardDistance` within the window.
    public func shouldFire() -> Bool {
        guard let last = samples.last else { return false }
        // macOS coordinate space: y grows upward, so "top of screen" is the
        // max-y edge. The ceiling band is [ceilingY - band, ceilingY].
        let ceiling = last.ceilingY
        guard last.y >= ceiling - ceilingBandHeight else { return false }

        // Find the lowest point in the window; the upward travel is the
        // distance from there to the current position.
        let lowestY = samples.map(\.y).min() ?? last.y
        let travel = last.y - lowestY
        return travel >= minUpwardDistance
    }
}
