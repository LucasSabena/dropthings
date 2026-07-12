import XCTest
import AppKit
@testable import DropThingsModules
import DropThingsCore
import DropThingsPlatform

/// A `FileManager` substitute that records directory creation and lets tests
/// control what exists on disk without touching the real file system.
final class FakeFileManager: FileManager {
    /// Maps absolute paths to whether they represent a directory (`true`) or a
    /// regular file (`false`). Missing paths are not in the dictionary.
    var entries: [String: Bool] = [:]

    private(set) var createdDirectories: [URL] = []

    var desktopURL: URL = URL(fileURLWithPath: "/Users/test/Desktop")
    var tempURL: URL = URL(fileURLWithPath: "/tmp/test")
    var desktopDirectoryUnavailable = false

    override func fileExists(atPath path: String) -> Bool {
        entries[path] != nil
    }

    override func fileExists(atPath path: String, isDirectory: UnsafeMutablePointer<ObjCBool>?) -> Bool {
        guard let isDirectoryEntry = entries[path] else { return false }
        isDirectory?.pointee = ObjCBool(isDirectoryEntry)
        return true
    }

    override func urls(
        for directory: FileManager.SearchPathDirectory,
        in domainMask: FileManager.SearchPathDomainMask
    ) -> [URL] {
        if directory == .desktopDirectory {
            return desktopDirectoryUnavailable ? [] : [desktopURL]
        }
        return super.urls(for: directory, in: domainMask)
    }

    override var temporaryDirectory: URL {
        tempURL
    }

    override func createDirectory(
        at url: URL,
        withIntermediateDirectories createIntermediates: Bool,
        attributes: [FileAttributeKey: Any]? = nil
    ) throws {
        createdDirectories.append(url)
        entries[url.path] = true
    }
}

/// Deterministic permission backend that never hits the real system APIs.
final class StubPermissionBackend: PermissionBackend, @unchecked Sendable {
    let states: [SystemPermission: SystemPermissionState]

    init(states: [SystemPermission: SystemPermissionState] = [:]) {
        self.states = states
    }

    func currentState(for permission: SystemPermission) -> SystemPermissionState {
        states[permission] ?? .notDetermined
    }

    @MainActor
    func openSystemSettings(for permission: SystemPermission) -> Bool {
        true
    }
}

@MainActor
final class ScreenshotRegionSaveURLTests: XCTestCase {
    private var backend: InMemorySettingsBackend!
    private var store: SettingsStore!
    private var permissions: PermissionCenter!
    private var fileManager: FakeFileManager!

    override func setUp() {
        super.setUp()
        backend = InMemorySettingsBackend()
        store = SettingsStore(backend: backend)
        permissions = PermissionCenter(
            backend: StubPermissionBackend(states: [.screenRecording: .granted])
        )
        fileManager = FakeFileManager()
    }

    private func makeModule() -> ScreenshotRegionModule {
        ScreenshotRegionModule(
            settings: store,
            permissions: permissions,
            fileManager: fileManager,
            pasteboard: .general
        )
    }

    // MARK: - resolveSaveURL

    func testResolveSaveURLUsesConfiguredDirectory() {
        let module = makeModule()
        fileManager.entries["/custom/screenshots"] = true

        module.setSaveLocation(URL(fileURLWithPath: "/custom/screenshots"))

        XCTAssertEqual(module.resolveSaveURL().path, "/custom/screenshots")
    }

    func testResolveSaveURLFallsBackToDesktopWhenPathIsMissing() {
        let module = makeModule()

        module.setSaveLocation(URL(fileURLWithPath: "/missing/screenshots"))

        XCTAssertEqual(module.resolveSaveURL().path, fileManager.desktopURL.path)
    }

    func testResolveSaveURLFallsBackToDesktopWhenPathIsAFile() {
        let module = makeModule()
        fileManager.entries["/custom/file.txt"] = false

        module.setSaveLocation(URL(fileURLWithPath: "/custom/file.txt"))

        XCTAssertEqual(module.resolveSaveURL().path, fileManager.desktopURL.path)
    }

    func testResolveSaveURLFallsBackToTempWhenDesktopIsUnavailable() {
        let module = makeModule()
        fileManager.desktopDirectoryUnavailable = true

        module.setSaveLocation(URL(fileURLWithPath: "/missing/screenshots"))

        XCTAssertEqual(module.resolveSaveURL().path, fileManager.tempURL.path)
    }

    // MARK: - createDirectoryIfNeeded

    func testCreateDirectoryCreatesMissingPath() throws {
        let module = makeModule()
        let url = URL(fileURLWithPath: "/new/screenshots")

        let result = try module.createDirectoryIfNeeded(for: url)

        XCTAssertEqual(result.path, url.path)
        XCTAssertEqual(fileManager.createdDirectories.map(\.path), [url.path])
    }

    func testCreateDirectoryReturnsExistingDirectoryWithoutCreating() throws {
        let module = makeModule()
        let url = URL(fileURLWithPath: "/existing/screenshots")
        fileManager.entries[url.path] = true

        let result = try module.createDirectoryIfNeeded(for: url)

        XCTAssertEqual(result.path, url.path)
        XCTAssertTrue(fileManager.createdDirectories.isEmpty)
    }

    func testCreateDirectoryFallsBackWhenPathIsAFile() throws {
        let module = makeModule()
        let fileURL = URL(fileURLWithPath: "/custom/file.txt")
        fileManager.entries[fileURL.path] = false

        let result = try module.createDirectoryIfNeeded(for: fileURL)

        XCTAssertEqual(result.path, fileManager.desktopURL.path)
        XCTAssertEqual(fileManager.createdDirectories.map(\.path), [fileManager.desktopURL.path])
    }

    func testNextSaveURLDoesNotOverwriteSameSecondCapture() {
        let module = makeModule()
        let directory = URL(fileURLWithPath: "/screenshots")
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let first = module.nextSaveURL(in: directory, now: date)
        fileManager.entries[first.path] = false

        let second = module.nextSaveURL(in: directory, now: date)

        XCTAssertNotEqual(first, second)
        XCTAssertEqual(second.deletingPathExtension().lastPathComponent,
                       first.deletingPathExtension().lastPathComponent + " 2")
    }
}
