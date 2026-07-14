import XCTest
@testable import DropThingsAudioControlKit

final class AudioProtocolTests: XCTestCase {
    func testProtocolRoundTripPreservesStableIdentityAndGeneration() throws {
        let app = AudioAppIdentity(bundleID: "com.example.player", processFallback: nil, displayName: "Player")
        let desired = AudioControlDesiredState(
            generation: 42,
            deadline: Date(timeIntervalSince1970: 1_000),
            sessionID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            apps: [.init(identity: app, volume: 0.4, isMuted: true)]
        )
        let data = try AudioControlCodec.encode(desired)
        let decoded = try AudioControlCodec.decode(AudioControlDesiredState.self, from: data)
        XCTAssertEqual(decoded, desired)
        XCTAssertEqual(decoded.apps.first?.identity.stableID, "bundle:com.example.player")
    }

    func testIgnoredAppNeverRequiresProcessing() {
        let app = AudioAppIdentity(bundleID: "com.example.player", processFallback: nil, displayName: "Player")
        let desired = AudioAppDesiredState(identity: app, volume: 0.2, isMuted: true, isIgnored: true)
        XCTAssertFalse(desired.requiresProcessing)
    }

    func testOwnedResourceMatchingDoesNotClaimForeignResources() {
        let session = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        XCTAssertTrue(OwnedAudioResource.isOwned(uid: "app.dropthings.audio.\(session.uuidString.lowercased()).tap", sessionID: session))
        XCTAssertFalse(OwnedAudioResource.isOwned(uid: "com.example.aggregate", sessionID: session))
    }
}
