import XCTest
@testable import DropThingsModules

final class FlickDetectorTests: XCTestCase {
    private func s(_ t: TimeInterval, _ y: Double, ceiling: Double = 900) -> FlickDetector.Sample {
        FlickDetector.Sample(timestamp: t, y: y, ceilingY: ceiling)
    }

    func testEmptyDoesNotFire() {
        XCTAssertFalse(FlickDetector().shouldFire())
    }

    func testReachesTopWithFastUpwardTravelFires() {
        var detector = FlickDetector(windowDuration: 0.35, minUpwardDistance: 200)
        // Start low, flick up to the very top (y=900 ceiling) within window.
        detector.record(s(0.00, 100))
        detector.record(s(0.05, 400))
        detector.record(s(0.10, 895))
        XCTAssertTrue(detector.shouldFire())
    }

    func testReachesTopButTooSlowDoesNotFire() {
        var detector = FlickDetector(windowDuration: 0.35, minUpwardDistance: 200)
        // The full travel happens, but spread over a second (outside window
        // for the early samples), so only the last short hop is in-window.
        detector.record(s(0.00, 100))
        detector.record(s(0.40, 400))   // older than window by the end
        detector.record(s(0.50, 895))
        // In-window travel is 895-400=495 → still large; tighten via window.
        // Use a shorter window to make the slow case fail.
        var slow = FlickDetector(windowDuration: 0.1, minUpwardDistance: 200)
        slow.record(s(0.00, 100))
        slow.record(s(0.12, 895))
        XCTAssertFalse(slow.shouldFire(), "samples older than the window should not count")
    }

    func testDoesNotFireWhenNotAtTop() {
        var detector = FlickDetector(windowDuration: 0.35, minUpwardDistance: 200)
        detector.record(s(0.00, 100))
        detector.record(s(0.05, 400))
        detector.record(s(0.10, 500))   // nowhere near the ceiling (900)
        XCTAssertFalse(detector.shouldFire())
    }

    func testDoesNotFireForSmallUpwardMotionAtTop() {
        var detector = FlickDetector(windowDuration: 0.35, minUpwardDistance: 200)
        // Cursor was already near the top and barely moved.
        detector.record(s(0.00, 880))
        detector.record(s(0.05, 895))
        XCTAssertFalse(detector.shouldFire())
    }

    func testResetClearsBuffer() {
        var detector = FlickDetector(windowDuration: 0.35, minUpwardDistance: 200)
        detector.record(s(0.00, 100))
        detector.record(s(0.05, 895))
        detector.reset()
        XCTAssertFalse(detector.shouldFire())
    }
}
