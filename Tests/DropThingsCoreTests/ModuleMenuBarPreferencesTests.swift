import XCTest
@testable import DropThingsCore

@MainActor
final class ModuleMenuBarPreferencesTests: XCTestCase {
    func testUsesModuleDefaultUntilUserChooses() {
        let preferences = ModuleMenuBarPreferences(settings: SettingsStore(backend: InMemorySettingsBackend()))

        XCTAssertTrue(preferences.isVisible(for: .audioControl, default: true))
        XCTAssertFalse(preferences.isVisible(for: .audioControl, default: false))
    }

    func testChoicePersistsAcrossInstances() {
        let backend = InMemorySettingsBackend()
        let store = SettingsStore(backend: backend)
        let preferences = ModuleMenuBarPreferences(settings: store)

        preferences.setVisible(false, for: .audioControl)

        let restored = ModuleMenuBarPreferences(settings: store)
        XCTAssertFalse(restored.isVisible(for: .audioControl, default: true))
    }

    func testPruneRemovesRetiredModulesOnly() {
        let backend = InMemorySettingsBackend()
        let store = SettingsStore(backend: backend)
        let preferences = ModuleMenuBarPreferences(settings: store)
        preferences.setVisible(true, for: .audioControl)
        preferences.setVisible(true, for: ModuleID("retired"))

        preferences.prune(registeredModuleIDs: [.audioControl])

        XCTAssertEqual(preferences.explicitVisibility, [ModuleID.audioControl.rawValue: true])
    }
}
