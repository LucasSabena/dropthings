import Foundation
import XCTest
import DropThingsCore
import DropThingsTranscriptionKit
@testable import DropThingsModules

final class LocalTranscriptionSettingsTests: XCTestCase {
    func testRoundTripUsesStableIdentifiers() {
        let store = SettingsStore(backend: InMemorySettingsBackend())
        let expected = LocalTranscriptionSettings(
            selectedModel: .small,
            language: .spanish,
            mode: .translateToEnglish,
            outputFormats: [.json],
            initialPrompt: "Buenos Aires"
        )

        store.saveLocalTranscriptionSettings(expected)

        XCTAssertEqual(store.loadLocalTranscriptionSettings(), expected)
    }

    func testSanitizationKeepsAtLeastOneOutputAndBoundsPrompt() {
        var settings = LocalTranscriptionSettings(outputFormats: [], initialPrompt: String(repeating: "x", count: 3_000))
        settings.sanitize()

        XCTAssertEqual(settings.outputFormats, [.text])
        XCTAssertEqual(settings.initialPrompt.count, 2_000)
        XCTAssertEqual(settings.version, LocalTranscriptionSettings.currentVersion)
    }

    func testOlderBlobMigratesMissingFieldsToDefaults() throws {
        let decoded = try JSONDecoder().decode(
            LocalTranscriptionSettings.self,
            from: Data(#"{"version":0,"selectedModel":"tiny"}"#.utf8)
        )

        XCTAssertEqual(decoded.version, LocalTranscriptionSettings.currentVersion)
        XCTAssertEqual(decoded.selectedModel, .tiny)
        XCTAssertEqual(decoded.language, .automatic)
        XCTAssertEqual(decoded.outputFormats, [.text, .json])
    }
}
