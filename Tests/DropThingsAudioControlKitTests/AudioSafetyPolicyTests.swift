import XCTest
@testable import DropThingsAudioControlKit

final class AudioSafetyPolicyTests: XCTestCase {
    func testGainSanitizationRejectsUnsafeValues() {
        XCTAssertEqual(AudioSafetyPolicy.sanitizedGain(-1), 0)
        XCTAssertEqual(AudioSafetyPolicy.sanitizedGain(2), 1)
        XCTAssertEqual(AudioSafetyPolicy.sanitizedGain(.nan), 1)
        XCTAssertEqual(AudioSafetyPolicy.sanitizedGain(.infinity), 1)
    }

    func testGainRampEndsExactlyAtTarget() {
        var ramp = GainRamp(current: 0)
        var values: [Float] = []
        ramp.render(target: 1, frameCount: 4, into: &values)
        XCTAssertEqual(values, [0.25, 0.5, 0.75, 1])
        XCTAssertEqual(ramp.current, 1)
    }

    func testLimiterBoundsAndSanitizesSamples() {
        XCTAssertEqual(SoftLimiter.process(0.5), 0.5, accuracy: 0.000_001)
        XCTAssertLessThanOrEqual(abs(SoftLimiter.process(1_000)), AudioSafetyPolicy.limiterCeiling)
        XCTAssertEqual(SoftLimiter.process(.nan), 0)
        XCTAssertEqual(SoftLimiter.process(.infinity), 0)
    }
}
