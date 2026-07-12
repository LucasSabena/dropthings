import XCTest
import AppKit
@testable import DropThingsModules
import DropThingsCore
import DropThingsPlatform

/// Deterministic permission backend that never hits the real system APIs.
@MainActor
final class ColorPickerFakePermissionBackend: PermissionBackend, @unchecked Sendable {
    func currentState(for permission: SystemPermission) -> SystemPermissionState {
        .granted
    }

    func openSystemSettings(for permission: SystemPermission) -> Bool {
        true
    }
}

@MainActor
final class ColorPickerModuleTests: XCTestCase {
    private var backend: InMemorySettingsBackend!
    private var store: SettingsStore!
    private var permissions: PermissionCenter!

    override func setUp() {
        super.setUp()
        backend = InMemorySettingsBackend()
        store = SettingsStore(backend: backend)
        permissions = PermissionCenter(backend: ColorPickerFakePermissionBackend())
    }

    private func makeModule(colorConverter: ColorPickerModule.ColorConverter? = nil) -> ColorPickerModule {
        if let colorConverter {
            return ColorPickerModule(
                settings: store,
                permissions: permissions,
                colorConverter: colorConverter
            )
        }
        return ColorPickerModule(settings: store, permissions: permissions)
    }

    // MARK: - setHistoryLimit

    func testSetHistoryLimitClampsToValidRange() {
        let module = makeModule()

        module.setHistoryLimit(0)
        XCTAssertEqual(module.colorPickerSettings.historyLimit, 1)

        module.setHistoryLimit(999)
        XCTAssertEqual(module.colorPickerSettings.historyLimit, ColorPickerSettings.historyLimitMax)
    }

    func testSetHistoryLimitTruncatesHistoryAndPersists() {
        let module = makeModule(colorConverter: { _ in NSColor(srgbRed: 0, green: 0, blue: 0, alpha: 1) })
        for _ in 0..<5 {
            module.handlePickedColor(.systemRed)
        }
        XCTAssertEqual(module.colorPickerSettings.history.count, 5)

        module.setHistoryLimit(2)

        XCTAssertEqual(module.colorPickerSettings.historyLimit, 2)
        XCTAssertEqual(module.colorPickerSettings.history.count, 2)

        let loaded = store.loadColorPickerSettings()
        XCTAssertEqual(loaded.historyLimit, 2)
        XCTAssertEqual(loaded.history.count, 2)
    }

    func testSetHistoryLimitKeepsFavoritesUnderCap() {
        let module = makeModule(colorConverter: { _ in NSColor(srgbRed: 0, green: 0, blue: 0, alpha: 1) })
        for _ in 0..<3 {
            module.handlePickedColor(.systemRed)
        }
        let favoriteID = module.colorPickerSettings.history[0].id
        module.toggleFavorite(id: favoriteID)

        module.setHistoryLimit(1)

        XCTAssertEqual(module.colorPickerSettings.history.count, 1)
        XCTAssertTrue(module.colorPickerSettings.history.first?.isFavorite == true)
    }

    // MARK: - color conversion

    func testFailedColorConversionSetsDegradedState() {
        let module = makeModule(colorConverter: { _ in nil })

        module.handlePickedColor(.systemRed)

        XCTAssertEqual(
            module.state,
            .degraded(reason: "Picked color could not be converted to RGB.")
        )
    }

    func testSuccessfulPickClearsPriorDegradedState() {
        var shouldFail = true
        let module = makeModule(colorConverter: { color in
            guard !shouldFail else { return nil }
            return color.usingColorSpace(.sRGB)
        })

        module.handlePickedColor(.systemRed)
        XCTAssertEqual(
            module.state,
            .degraded(reason: "Picked color could not be converted to RGB.")
        )

        shouldFail = false
        module.handlePickedColor(NSColor(srgbRed: 0, green: 0.5, blue: 0, alpha: 1))

        XCTAssertEqual(module.state, .running)
        XCTAssertEqual(module.colorPickerSettings.history.count, 1)
        let picked = module.colorPickerSettings.history.first
        XCTAssertEqual(picked?.r, 0)
        XCTAssertEqual(picked?.g, 128)
        XCTAssertEqual(picked?.b, 0)
    }

    func testSuccessfulPickRecordsColor() {
        let module = makeModule()
        let color = NSColor(srgbRed: 1, green: 0, blue: 0, alpha: 1)

        module.handlePickedColor(color)

        XCTAssertEqual(module.colorPickerSettings.history.count, 1)
        XCTAssertEqual(module.colorPickerSettings.history.first?.hex, "#FF0000")
    }

    func testCopyPublishesTextAndNativeColorRepresentations() {
        let module = makeModule()
        let picked = PickedColor(r: 12, g: 34, b: 56)

        module.copyToPasteboard(picked)

        XCTAssertEqual(NSPasteboard.general.string(forType: .string), "#0C2238")
        let copiedColor = NSPasteboard.general
            .readObjects(forClasses: [NSColor.self], options: nil)?
            .first as? NSColor
        let rgb = copiedColor?.usingColorSpace(.sRGB)
        XCTAssertEqual(Int(((rgb?.redComponent ?? 0) * 255).rounded()), 12)
        XCTAssertEqual(Int(((rgb?.greenComponent ?? 0) * 255).rounded()), 34)
        XCTAssertEqual(Int(((rgb?.blueComponent ?? 0) * 255).rounded()), 56)
    }
}
