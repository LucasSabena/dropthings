import Carbon.HIToolbox
import XCTest
@testable import DropThingsCore
@testable import DropThingsModules
import DropThingsPlatform

final class CommandPaletteSettingsTests: XCTestCase {
    func testDefaultsEnableReplacementProvidersWithoutContentSearch() {
        let settings = CommandPaletteSettings()
        XCTAssertEqual(settings.version, CommandPaletteSettings.currentVersion)
        XCTAssertTrue(settings.hotkeyEnabled)
        XCTAssertTrue(settings.applicationsEnabled)
        XCTAssertTrue(settings.commandsEnabled)
        XCTAssertTrue(settings.calculatorEnabled)
        XCTAssertTrue(settings.filesEnabled)
        XCTAssertFalse(settings.fileContentSearchEnabled)
        XCTAssertFalse(settings.includeHiddenFiles)
    }

    func testRoundTripThroughSettingsStore() {
        let store = SettingsStore(backend: InMemorySettingsBackend())
        let original = CommandPaletteSettings(
            hotkeyEnabled: false,
            hotkey: GlobalHotkey.Definition(keyCode: UInt32(kVK_ANSI_P), modifiers: UInt32(cmdKey), id: 99),
            filesEnabled: false,
            applicationLocations: ["~/Applications"],
            applicationVisibility: .selected,
            selectedApplicationIDs: ["app:one"],
            pinnedApplicationIDs: ["app:one"],
            excludedPaths: ["~/Private"],
            webSearchEnabled: true,
            webSearchEngine: .duckDuckGo,
            webBrowserBundleIdentifier: "com.microsoft.edgemac",
            maximumResultsPerProvider: 45
        ).sanitized()
        store.saveCommandPaletteSettings(original)
        XCTAssertEqual(store.loadCommandPaletteSettings(), original)
    }

    func testLegacySettingsMigrateMissingFields() throws {
        let legacy = Data(#"{"hotkeyEnabled":false,"hotkey":null}"#.utf8)
        let decoded = try JSONDecoder().decode(CommandPaletteSettings.self, from: legacy)
        XCTAssertEqual(decoded.version, CommandPaletteSettings.currentVersion)
        XCTAssertFalse(decoded.hotkeyEnabled)
        XCTAssertTrue(decoded.applicationsEnabled)
        XCTAssertTrue(decoded.filesEnabled)
    }

    func testExplicitlyClearedHotkeyStaysCleared() throws {
        let settings = CommandPaletteSettings(hotkey: nil)
        let data = try JSONEncoder().encode(settings)
        XCTAssertNil(try JSONDecoder().decode(CommandPaletteSettings.self, from: data).hotkey)
    }

    func testSanitizationBoundsResultsAndCanonicalizesPaths() {
        let value = CommandPaletteSettings(
            applicationLocations: ["~/Applications", "~/Applications"],
            excludedPaths: ["~/Private", ""],
            maximumResultsPerProvider: 1_000
        ).sanitized()
        XCTAssertEqual(value.maximumResultsPerProvider, 100)
        XCTAssertEqual(value.applicationLocations.count, 1)
        XCTAssertTrue(value.applicationLocations[0].hasPrefix("/"))
        XCTAssertEqual(value.excludedPaths.count, 1)
    }

    func testCorruptSettingsResetOnlyCommandPaletteSettings() {
        let store = SettingsStore(backend: InMemorySettingsBackend())
        let unrelated = SettingsKey("unrelated.setting")
        store.setString("preserved", unrelated)
        store.setData(Data("not-json".utf8), CommandPaletteSettingsKey.settings)

        XCTAssertEqual(store.loadCommandPaletteSettings(), CommandPaletteSettings())
        XCTAssertNil(store.data(CommandPaletteSettingsKey.settings))
        XCTAssertEqual(store.string(unrelated), "preserved")
    }
}
