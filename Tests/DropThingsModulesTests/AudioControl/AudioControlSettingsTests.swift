import XCTest
import DropThingsAudioControlKit
@testable import DropThingsModules

final class AudioControlSettingsTests: XCTestCase {
    func testSettingsPersistByBundleIDInsteadOfDisplayName() {
        let first = AudioAppIdentity(bundleID: "com.example.player", processFallback: nil, displayName: "Old Name")
        let renamed = AudioAppIdentity(bundleID: "com.example.player", processFallback: nil, displayName: "New Name")
        var settings = AudioControlSettings()
        var app = settings.settings(for: first)
        app.volume = 0.3
        settings.update(app)

        XCTAssertEqual(settings.settings(for: renamed).volume, 0.3)
        XCTAssertEqual(settings.settings(for: renamed).identity.displayName, "New Name")
    }

    func testCorruptValuesAreSanitizedAndIgnoreMeansBypass() {
        let identity = AudioAppIdentity(bundleID: "com.example.player", processFallback: nil, displayName: "Player")
        var app = AudioControlAppSettings(identity: identity)
        app.volume = 9
        app.isMuted = true
        app.isIgnored = true
        var settings = AudioControlSettings()
        settings.update(app)
        let safe = settings.appsByStableID[identity.stableID]
        XCTAssertEqual(safe?.volume, 1)
        XCTAssertEqual(safe?.isMuted, false)
        XCTAssertFalse(safe?.desiredState.requiresProcessing ?? true)
    }
}
