import Foundation

/// Pure, testable detector for a "shake the mouse" gesture. Looks for at
/// least `minFlips` direction reversals in the X axis within
/// `windowDuration` seconds, each covering at least `minDisplacement`
/// points. The math is small enough to run per-sample on a 60 Hz poll
/// without measurable cost.
public struct ShakeDetector: Sendable {
    public struct Sample: Equatable, Sendable {
        public let timestamp: TimeInterval
        public let x: Double

        public init(timestamp: TimeInterval, x: Double) {
            self.timestamp = timestamp
            self.x = x
        }
    }

    public let windowDuration: TimeInterval
    public let minDisplacement: Double
    public let minFlips: Int

    private var samples: [Sample] = []

    public init(
        windowDuration: TimeInterval = 0.8,
        minDisplacement: Double = 40,
        minFlips: Int = 3
    ) {
        self.windowDuration = windowDuration
        self.minDisplacement = minDisplacement
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

    /// `true` when the buffered samples contain enough sign flips in the X
    /// axis within the window to count as a deliberate shake.
    public func shouldFire() -> Bool {
        guard samples.count >= 2 else { return false }
        var flips = 0
        var prevSign: Int? = nil
        for index in 1..<samples.count {
            let delta = samples[index].x - samples[index - 1].x
            guard abs(delta) >= minDisplacement else { continue }
            let sign = delta > 0 ? 1 : -1
            if let prevSign, prevSign != sign {
                flips += 1
            }
            prevSign = sign
        }
        return flips >= minFlips
    }
}
