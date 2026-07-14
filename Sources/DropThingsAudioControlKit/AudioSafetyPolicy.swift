import Foundation

public enum AudioSafetyPolicy {
    public static let minimumGain = 0.0
    public static let maximumCoreGain = 1.0
    public static let limiterCeiling: Float = 0.98

    public static func sanitizedGain(_ value: Double) -> Double {
        guard value.isFinite else { return 1 }
        return min(maximumCoreGain, max(minimumGain, value))
    }

    public static func decibels(forLinearGain gain: Double) -> Double {
        let clean = sanitizedGain(gain)
        guard clean > 0 else { return -.infinity }
        return 20 * log10(clean)
    }
}

public struct GainRamp: Sendable {
    public private(set) var current: Float

    public init(current: Float = 1) {
        self.current = current.isFinite ? current : 1
    }

    public mutating func render(target: Float, frameCount: Int, into output: inout [Float]) {
        guard frameCount > 0 else { return }
        if output.count < frameCount {
            output.append(contentsOf: repeatElement(0, count: frameCount - output.count))
        }
        let safeTarget = Float(AudioSafetyPolicy.sanitizedGain(Double(target)))
        let step = (safeTarget - current) / Float(frameCount)
        for index in 0..<frameCount {
            current += step
            output[index] = current
        }
        current = safeTarget
    }
}

public enum SoftLimiter {
    public static func process(_ sample: Float, ceiling: Float = AudioSafetyPolicy.limiterCeiling) -> Float {
        guard sample.isFinite else { return 0 }
        let safeCeiling = min(1, max(0.01, ceiling.isFinite ? ceiling : AudioSafetyPolicy.limiterCeiling))
        let knee = safeCeiling * 0.9
        let magnitude = abs(sample)
        guard magnitude > knee else { return sample }
        let remaining = safeCeiling - knee
        let limited = knee + remaining * (1 - exp(-(magnitude - knee) / remaining))
        return copysign(min(safeCeiling, limited), sample)
    }
}
