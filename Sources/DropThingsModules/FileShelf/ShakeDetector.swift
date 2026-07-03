import Foundation

/// Pure, testable detector for a "shake the mouse" gesture.
///
/// The previous detector only looked at the X axis, so a natural diagonal
/// or vertical shake would not register — which is why the gesture felt
/// random. This version picks the **dominant axis** of motion and counts
/// direction reversals there, so any shake orientation works.
///
/// It also uses **per-step velocity**, not raw displacement, so the same
/// gesture fires regardless of how far apart the samples happen to land
/// in time. Sensitivity is a single knob that maps to concrete thresholds,
/// exposed to the user as Low / Medium / High.
public struct ShakeDetector: Sendable {
    public struct Sample: Equatable, Sendable {
        public let timestamp: TimeInterval
        public let x: Double
        public let y: Double

        public init(timestamp: TimeInterval, x: Double, y: Double) {
            self.timestamp = timestamp
            self.x = x
            self.y = y
        }
    }

    public let windowDuration: TimeInterval
    public let minStepSpeed: Double
    public let minFlips: Int
    public let sensitivity: ShakeSensitivity

    private var samples: [Sample] = []

    /// Sensitivity-tunable detector. Concrete thresholds are derived from
    /// `sensitivity` so callers only reason about a Low/Medium/High knob.
    public init(sensitivity: ShakeSensitivity = .medium) {
        self.sensitivity = sensitivity
        let params = ShakeDetector.parameters(for: sensitivity)
        self.windowDuration = params.window
        self.minStepSpeed = params.minSpeed
        self.minFlips = params.minFlips
    }

    /// Fully explicit init used by tests to pin exact thresholds.
    public init(windowDuration: TimeInterval, minStepSpeed: Double, minFlips: Int) {
        self.sensitivity = .medium
        self.windowDuration = windowDuration
        self.minStepSpeed = minStepSpeed
        self.minFlips = minFlips
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

    /// `true` when the buffered samples contain enough direction reversals
    /// along the dominant axis, fast enough, within the window.
    public func shouldFire() -> Bool {
        guard samples.count >= 4 else { return false }
        let axis = dominantAxis
        return flips(along: axis) >= minFlips
    }

    // MARK: - Private

    /// Whichever axis saw more total travel becomes the shake axis.
    private var dominantAxis: Axis {
        guard samples.count >= 2 else { return .x }
        var travelX: Double = 0
        var travelY: Double = 0
        for index in 1..<samples.count {
            travelX += abs(samples[index].x - samples[index - 1].x)
            travelY += abs(samples[index].y - samples[index - 1].y)
        }
        return travelY > travelX ? .y : .x
    }

    /// Count direction reversals along `axis`, ignoring steps that are too
    /// slow to be a deliberate shake (this filters slow drift and jitter).
    private func flips(along axis: Axis) -> Int {
        var flips = 0
        var prevSign: Int? = nil
        for index in 1..<samples.count {
            let dt = samples[index].timestamp - samples[index - 1].timestamp
            guard dt > 0 else { continue }
            let delta = axis == .x
                ? samples[index].x - samples[index - 1].x
                : samples[index].y - samples[index - 1].y
            let speed = abs(delta) / dt
            guard speed >= minStepSpeed else { continue }
            let sign = delta > 0 ? 1 : -1
            if let prevSign, prevSign != sign {
                flips += 1
            }
            prevSign = sign
        }
        return flips
    }

    private enum Axis { case x, y }

    /// Thresholds per sensitivity level. Higher sensitivity → slower / fewer
    /// reversals required to fire.
    static func parameters(for sensitivity: ShakeSensitivity) -> (window: TimeInterval, minSpeed: Double, minFlips: Int) {
        switch sensitivity {
        case .low:
            // Deliberate: fast and many reversals.
            return (window: 0.5, minSpeed: 1800, minFlips: 5)
        case .medium:
            return (window: 0.6, minSpeed: 1200, minFlips: 4)
        case .high:
            // Gentle: slower / fewer reversals fire.
            return (window: 0.8, minSpeed: 700, minFlips: 3)
        }
    }
}
