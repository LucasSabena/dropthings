import XCTest
@testable import DropThingsModules

final class ShakeDetectorTests: XCTestCase {
    private func sample(at seconds: TimeInterval, x: Double, y: Double = 0) -> ShakeDetector.Sample {
        ShakeDetector.Sample(timestamp: seconds, x: x, y: y)
    }

    func testEmptyDetectorDoesNotFire() {
        XCTAssertFalse(ShakeDetector().shouldFire())
    }

    func testFewerThanFourSamplesDoesNotFire() {
        var detector = ShakeDetector(windowDuration: 0.6, minStepSpeed: 500, minFlips: 3)
        detector.record(sample(at: 0.00, x: 100))
        detector.record(sample(at: 0.05, x: 400))
        detector.record(sample(at: 0.10, x: 120))
        XCTAssertFalse(detector.shouldFire())
    }

    func testSlowBackAndForthDoesNotFire() {
        // 1 second between samples → low speed per step, even though swings are big.
        var detector = ShakeDetector(windowDuration: 0.5, minStepSpeed: 1800, minFlips: 4)
        detector.record(sample(at: 0.0, x: 100))
        detector.record(sample(at: 1.0, x: 800))
        detector.record(sample(at: 2.0, x: 100))
        detector.record(sample(at: 3.0, x: 800))
        detector.record(sample(at: 4.0, x: 100))
        XCTAssertFalse(detector.shouldFire())
    }

    func testSmallJitterDoesNotFire() {
        var detector = ShakeDetector(windowDuration: 0.6, minStepSpeed: 700, minFlips: 3)
        detector.record(sample(at: 0.00, x: 500))
        detector.record(sample(at: 0.05, x: 502))
        detector.record(sample(at: 0.10, x: 499))
        detector.record(sample(at: 0.15, x: 503))
        detector.record(sample(at: 0.20, x: 500))
        XCTAssertFalse(detector.shouldFire())
    }

    func testFastHorizontalShakeFires() {
        var detector = ShakeDetector(windowDuration: 0.5, minStepSpeed: 1500, minFlips: 4)
        // Right, left, right, left — fast.
        let sequence: [(TimeInterval, Double)] = [
            (0.00, 100), (0.05, 400), (0.10, 120), (0.15, 380),
            (0.20, 110), (0.25, 420), (0.30, 100), (0.35, 410),
            (0.40, 110)
        ]
        for (t, x) in sequence {
            detector.record(sample(at: t, x: x))
        }
        XCTAssertTrue(detector.shouldFire())
    }

    func testFastDiagonalShakeFiresViaDominantAxis() {
        // The whole point of the rewrite: a shake that is not purely
        // horizontal must still fire. Here the Y axis dominates.
        var detector = ShakeDetector(windowDuration: 0.5, minStepSpeed: 1500, minFlips: 4)
        let xs: [Double] = [0, 5, -5, 5, -5, 5, -5, 5, 0]   // tiny x noise
        let ys: [Double] = [100, 400, 120, 380, 110, 420, 100, 410, 110]
        for i in 0..<xs.count {
            detector.record(sample(at: Double(i) * 0.05, x: 500 + xs[i], y: ys[i]))
        }
        XCTAssertTrue(detector.shouldFire())
    }

    func testFastVerticalShakeFires() {
        var detector = ShakeDetector(windowDuration: 0.5, minStepSpeed: 1500, minFlips: 4)
        let ys: [Double] = [100, 400, 120, 380, 110, 420, 100, 410, 110]
        for i in 0..<ys.count {
            detector.record(sample(at: Double(i) * 0.05, x: 0, y: ys[i]))
        }
        XCTAssertTrue(detector.shouldFire())
    }

    func testResetClearsBuffer() {
        var detector = ShakeDetector(windowDuration: 0.6, minStepSpeed: 700, minFlips: 3)
        detector.record(sample(at: 0.00, x: 100))
        detector.record(sample(at: 0.05, x: 400))
        detector.reset()
        XCTAssertFalse(detector.shouldFire())
    }

    func testOldSamplesArePruned() {
        var detector = ShakeDetector(windowDuration: 0.2, minStepSpeed: 700, minFlips: 4)
        for (t, x) in [(0.0, 100.0), (0.05, 400.0), (0.1, 100.0), (0.15, 400.0)] {
            detector.record(sample(at: t, x: x))
        }
        // Fresh samples alone are not enough flips.
        detector.record(sample(at: 1.0, x: 500))
        detector.record(sample(at: 1.05, x: 510))
        XCTAssertFalse(detector.shouldFire())
    }

    // MARK: - sensitivity presets

    func testHighSensitivityEasierThanLow() {
        // A borderline shake: moderate speed, 3 flips.
        // High (minFlips 3, minSpeed 700) should fire; Low (5/1800) should not.
        let ts: [TimeInterval] = [0.00, 0.08, 0.16, 0.24, 0.32, 0.40]
        let xs: [Double] = [100, 300, 120, 290, 110, 300]

        var high = ShakeDetector(sensitivity: .high)
        var low = ShakeDetector(sensitivity: .low)
        for i in 0..<ts.count {
            high.record(sample(at: ts[i], x: xs[i]))
            low.record(sample(at: ts[i], x: xs[i]))
        }
        XCTAssertTrue(high.shouldFire(), "high sensitivity should fire on a moderate shake")
        XCTAssertFalse(low.shouldFire(), "low sensitivity should require a harder shake")
    }

    func testParametersMapSensitivity() {
        XCTAssertLessThan(
            ShakeDetector.parameters(for: .high).minSpeed,
            ShakeDetector.parameters(for: .low).minSpeed,
            "high sensitivity should have a lower speed threshold"
        )
        XCTAssertLessThan(
            ShakeDetector.parameters(for: .high).minFlips,
            ShakeDetector.parameters(for: .low).minFlips,
            "high sensitivity should require fewer flips"
        )
    }
}
