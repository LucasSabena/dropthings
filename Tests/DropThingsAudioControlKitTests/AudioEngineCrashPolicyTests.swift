import XCTest
@testable import DropThingsAudioControlKit

final class AudioEngineCrashPolicyTests: XCTestCase {
    func testBackoffIsBoundedAndCutsOffCrashLoop() {
        let policy = AudioEngineCrashPolicy(maximumRestarts: 3, window: 60, initialDelay: 1, maximumDelay: 4)
        let now = Date(timeIntervalSince1970: 100)
        XCTAssertEqual(policy.decision(after: [], now: now), .restart(after: 1))
        XCTAssertEqual(policy.decision(after: [now], now: now), .restart(after: 1))
        XCTAssertEqual(policy.decision(after: [now, now], now: now), .restart(after: 2))
        XCTAssertEqual(policy.decision(after: [now, now, now], now: now), .cutoff)
    }
}
