import CoreGraphics
import XCTest
@testable import DropThingsPlatform

final class CommandPalettePlatformTests: XCTestCase {
    func testApplicationDeduplicationUsesBundleIDAndCanonicalPath() {
        let first = ApplicationRecord(id: "one", name: "App", bundleIdentifier: "com.example.app", url: URL(fileURLWithPath: "/Applications/App.app"))
        let duplicateID = ApplicationRecord(id: "two", name: "App Copy", bundleIdentifier: "com.example.app", url: URL(fileURLWithPath: "/Users/me/Applications/App.app"))
        let unique = ApplicationRecord(id: "three", name: "Other", bundleIdentifier: "com.example.other", url: URL(fileURLWithPath: "/Applications/Other.app"))
        XCTAssertEqual(ApplicationCatalog.deduplicated([duplicateID, unique, first]).map(\.bundleIdentifier).compactMap { $0 }.sorted(), ["com.example.app", "com.example.other"])
    }

    func testScreenSelectionPrefersMouseThenFallback() {
        let left = PaletteDisplayGeometry(id: "left", frame: CGRect(x: -1000, y: 0, width: 1000, height: 800), visibleFrame: CGRect(x: -1000, y: 0, width: 1000, height: 760))
        let right = PaletteDisplayGeometry(id: "right", frame: CGRect(x: 0, y: 0, width: 1200, height: 900), visibleFrame: CGRect(x: 0, y: 20, width: 1200, height: 850))
        XCTAssertEqual(PaletteScreenPlacement.targetDisplay(mouseLocation: CGPoint(x: -50, y: 300), displays: [left, right], fallbackID: "right")?.id, "left")
        XCTAssertEqual(PaletteScreenPlacement.targetDisplay(mouseLocation: CGPoint(x: 5_000, y: 5_000), displays: [left, right], fallbackID: "right")?.id, "right")
    }

    func testPanelOriginStaysInsideVisibleFrame() {
        let visible = CGRect(x: -1000, y: 20, width: 1000, height: 740)
        let origin = PaletteScreenPlacement.panelOrigin(size: CGSize(width: 680, height: 480), visibleFrame: visible)
        XCTAssertGreaterThanOrEqual(origin.x, visible.minX)
        XCTAssertGreaterThanOrEqual(origin.y, visible.minY)
        XCTAssertLessThanOrEqual(origin.x + 680, visible.maxX)
        XCTAssertLessThanOrEqual(origin.y + 480, visible.maxY)
    }

    func testApplicationCatalogRejectsHelpersAndInvalidBundles() {
        let helper = URL(fileURLWithPath: "/Applications/Host.app/Contents/Helpers/Helper.app")
        XCTAssertNil(ApplicationCatalog.record(for: helper))
        XCTAssertNil(ApplicationCatalog.record(for: URL(fileURLWithPath: "/missing/Invalid.app")))
    }

    func testApplicationRecordUsesStableBundleIDAndAliases() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let app = root.appendingPathComponent("Visible Name.app", isDirectory: true)
        let contents = app.appendingPathComponent("Contents", isDirectory: true)
        let executableFolder = contents.appendingPathComponent("MacOS", isDirectory: true)
        try FileManager.default.createDirectory(at: executableFolder, withIntermediateDirectories: true)
        let executable = executableFolder.appendingPathComponent("SampleExecutable")
        try Data("#!/bin/sh\n".utf8).write(to: executable)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)
        let plist: [String: Any] = [
            "CFBundleIdentifier": "com.example.palette-sample",
            "CFBundleDisplayName": "Palette Sample",
            "CFBundleExecutable": "SampleExecutable",
            "CFBundlePackageType": "APPL"
        ]
        let plistData = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try plistData.write(to: contents.appendingPathComponent("Info.plist"))
        defer { try? FileManager.default.removeItem(at: root) }

        let record = try XCTUnwrap(ApplicationCatalog.record(for: app))
        XCTAssertEqual(record.id, "app:com.example.palette-sample")
        XCTAssertEqual(record.name, "Palette Sample")
        XCTAssertTrue(record.aliases.contains("Visible Name"))
        XCTAssertTrue(record.aliases.contains("SampleExecutable"))
    }

    @MainActor
    func testMissingApplicationLaunchReturnsExplicitError() async {
        do {
            try await PaletteWorkspace().launchApplication(at: URL(fileURLWithPath: "/missing/No.app"))
            XCTFail("Expected the missing item error")
        } catch let error as PaletteWorkspaceError {
            guard case .missingItem = error else { return XCTFail("Unexpected error: \(error)") }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
