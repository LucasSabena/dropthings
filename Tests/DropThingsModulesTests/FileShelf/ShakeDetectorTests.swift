import XCTest
@testable import DropThingsModules

final class ShakeDetectorTests: XCTestCase {
    private func sample(at seconds: TimeInterval, x: Double) -> ShakeDetector.Sample {
        ShakeDetector.Sample(timestamp: seconds, x: x)
    }

    func testEmptyDetectorDoesNotFire() {
        let detector = ShakeDetector()
        XCTAssertFalse(detector.shouldFire())
    }

    func testSingleSampleDoesNotFire() {
        var detector = ShakeDetector()
        detector.record(sample(at: 0, x: 100))
        XCTAssertFalse(detector.shouldFire())
    }

    func testSlowBackAndForthDoesNotFire() {
        var detector = ShakeDetector(windowDuration: 0.5, minDisplacement: 80, minFlips: 4)
        // Slow motion (1 sec between samples) with big swings.
        detector.record(sample(at: 0.0, x: 100))
        detector.record(sample(at: 1.0, x: 800))
        detector.record(sample(at: 2.0, x: 100))
        detector.record(sample(at: 3.0, x: 800))
        XCTAssertFalse(detector.shouldFire())
    }

    func testSmallJitterDoesNotFire() {
        var detector = ShakeDetector()
        detector.record(sample(at: 0.00, x: 500))
        detector.record(sample(at: 0.05, x: 502))
        detector.record(sample(at: 0.10, x: 499))
        detector.record(sample(at: 0.15, x: 503))
        XCTAssertFalse(detector.shouldFire())
    }

    func testFastShakeFires() {
        var detector = ShakeDetector(windowDuration: 0.5, minDisplacement: 80, minFlips: 4)
        // Right, left, right, left — 4 flips in 0.4 seconds.
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

    func testThreeFlipsAreNotEnough() {
        var detector = ShakeDetector(windowDuration: 0.5, minDisplacement: 80, minFlips: 4)
        // Right, left, right, left — 3 flips only, just under the threshold.
        detector.record(sample(at: 0.00, x: 100))
        detector.record(sample(at: 0.05, x: 400))
        detector.record(sample(at: 0.10, x: 120))
        detector.record(sample(at: 0.15, x: 380))
        detector.record(sample(at: 0.20, x: 110))
        XCTAssertFalse(detector.shouldFire())
    }

    func testResetClearsBuffer() {
        var detector = ShakeDetector()
        detector.record(sample(at: 0.00, x: 100))
        detector.record(sample(at: 0.05, x: 400))
        detector.reset()
        XCTAssertFalse(detector.shouldFire())
    }

    func testOldSamplesArePruned() {
        var detector = ShakeDetector(windowDuration: 0.2, minDisplacement: 80, minFlips: 4)
        // Fill with valid shakes older than the window.
        for (t, x) in [(0.0, 100.0), (0.05, 400.0), (0.1, 100.0), (0.15, 400.0)] {
            detector.record(sample(at: t, x: x))
        }
        // Now add fresh samples that on their own are not enough flips.
        detector.record(sample(at: 1.0, x: 500))
        detector.record(sample(at: 1.05, x: 510))
        XCTAssertFalse(detector.shouldFire())
    }
}
