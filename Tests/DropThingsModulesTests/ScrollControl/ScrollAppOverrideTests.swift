import XCTest
@testable import DropThingsModules
import DropThingsPlatform

final class ScrollAppOverrideTests: XCTestCase {

    func testOverrideWinsOverDeviceDefault() {
        let settings = ScrollSettings(
            trackpadDirection: .natural,
            appOverrides: [ScrollAppOverride(bundleID: "com.apple.Safari", direction: .inverted, multiplier: 1.5)]
        )
        // On Safari, the trackpad uses the override (inverted), not the
        // device default (natural).
        XCTAssertEqual(settings.direction(for: .trackpad, activeBundleID: "com.apple.Safari"), .inverted)
        XCTAssertEqual(settings.multiplier(for: .trackpad, activeBundleID: "com.apple.Safari"), 1.5)
        // On another app, the device default applies.
        XCTAssertEqual(settings.direction(for: .trackpad, activeBundleID: "com.apple.TextEdit"), .natural)
        XCTAssertEqual(settings.multiplier(for: .trackpad, activeBundleID: "com.apple.TextEdit"), 1.0)
        // Without an active bundle, the device default applies.
        XCTAssertEqual(settings.direction(for: .trackpad), .natural)
        XCTAssertEqual(settings.multiplier(for: .trackpad), 1.0)
    }

    func testOverrideMultiplierClamped() {
        let overrides = [ScrollAppOverride(bundleID: "com.apple.Safari", direction: .inverted, multiplier: 100)]
        let sanitized = ScrollSettings.sanitized(
            trackpadDirection: .natural,
            mouseWheelDirection: .natural,
            magicMouseDirection: .natural,
            horizontalScrollEnabled: true,
            scrollMultiplier: 1.0,
            hotkey: nil,
            appOverrides: overrides
        )
        let safari = sanitized.appOverrides.first { $0.bundleID == "com.apple.Safari" }
        XCTAssertEqual(safari?.multiplier, ScrollSettings.multiplierMax)
    }

    func testNoOverrideFallsBackToDefault() {
        let settings = ScrollSettings(mouseWheelDirection: .inverted)
        XCTAssertEqual(settings.direction(for: .mouseWheel, activeBundleID: "com.apple.Safari"), .inverted)
    }

    func testDefaultDirectionIgnoresOverrides() {
        let settings = ScrollSettings(
            trackpadDirection: .natural,
            appOverrides: [ScrollAppOverride(bundleID: "com.apple.Safari", direction: .inverted)]
        )
        // `defaultDirection` always returns the device category value,
        // used by the settings UI to show the baseline.
        XCTAssertEqual(settings.defaultDirection(for: .trackpad), .natural)
    }

    func testSanitizedDedupesByBundleID() {
        let overrides = [
            ScrollAppOverride(bundleID: "com.apple.Safari", direction: .natural),
            ScrollAppOverride(bundleID: "com.apple.Safari", direction: .inverted),
            ScrollAppOverride(bundleID: "com.apple.TextEdit", direction: .inverted)
        ]
        let sanitized = ScrollSettings.sanitized(
            trackpadDirection: .natural,
            mouseWheelDirection: .natural,
            magicMouseDirection: .natural,
            horizontalScrollEnabled: true,
            scrollMultiplier: 1.0,
            hotkey: nil,
            appOverrides: overrides
        )
        // One entry per bundle ID, last write wins (Safari → inverted).
        XCTAssertEqual(sanitized.appOverrides.count, 2)
        let safari = sanitized.appOverrides.first { $0.bundleID == "com.apple.Safari" }
        XCTAssertEqual(safari?.direction, .inverted)
    }

    func testSanitizedSortsByBundleIDForDeterministicOutput() {
        let overrides = [
            ScrollAppOverride(bundleID: "com.apple.Z", direction: .inverted),
            ScrollAppOverride(bundleID: "com.apple.A", direction: .inverted)
        ]
        let sanitized = ScrollSettings.sanitized(
            trackpadDirection: .natural,
            mouseWheelDirection: .natural,
            magicMouseDirection: .natural,
            horizontalScrollEnabled: true,
            scrollMultiplier: 1.0,
            hotkey: nil,
            appOverrides: overrides
        )
        XCTAssertEqual(sanitized.appOverrides.map(\.bundleID), ["com.apple.A", "com.apple.Z"])
    }

    func testOverridesRoundTripThroughCodable() throws {
        let settings = ScrollSettings(
            trackpadDirection: .natural,
            appOverrides: [
                ScrollAppOverride(bundleID: "com.apple.Safari", direction: .inverted),
                ScrollAppOverride(bundleID: "com.googlecode.iterm2", direction: .natural)
            ]
        )
        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(ScrollSettings.self, from: data)
        XCTAssertEqual(decoded.appOverrides.count, 2)
        XCTAssertEqual(decoded.appOverrides.first?.bundleID, "com.apple.Safari")
    }

    func testOldBlobWithoutAppOverridesDecodesToEmpty() throws {
        // A blob saved before overrides shipped must decode with [].
        let json = """
        {"trackpadDirection":"natural","mouseWheelDirection":"inverted","magicMouseDirection":"natural","horizontalScrollEnabled":true,"scrollMultiplier":1.5}
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(ScrollSettings.self, from: json)
        XCTAssertEqual(decoded.appOverrides, [])
        XCTAssertEqual(decoded.scrollMultiplier, 1.5)
    }

    // MARK: - Transformer behavior with an active bundle

    func testTransformerAppliesOverrideForActiveBundle() {
        let settings = ScrollSettings(
            mouseWheelDirection: .natural,
            appOverrides: [ScrollAppOverride(bundleID: "com.apple.Terminal", direction: .inverted, multiplier: 2.0)]
        )
        let transformer = ScrollEventTransformer(settings: settings)
        // A discrete mouse wheel scroll (fixedDeltaY, non-continuous).
        let input = ScrollEventInput(
            pointDeltaY: 0,
            pointDeltaX: 0,
            fixedDeltaY: 10,
            fixedDeltaX: 0,
            phase: 0,
            momentumPhase: 0,
            isContinuous: false
        )
        // In Terminal: direction is inverted and multiplier doubled.
        let inTerminal = transformer.transform(input, activeBundleID: "com.apple.Terminal")
        XCTAssertTrue(inTerminal.didMutate)
        XCTAssertEqual(inTerminal.fixedDeltaY, -20)
        // In TextEdit: device default (natural, 1x) applies, no inversion.
        let inTextEdit = transformer.transform(input, activeBundleID: "com.apple.TextEdit")
        XCTAssertFalse(inTextEdit.didMutate)
        XCTAssertEqual(inTextEdit.fixedDeltaY, 10)
    }
}