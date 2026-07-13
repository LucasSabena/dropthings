import XCTest
import AppKit
@testable import DropThingsModules
import DropThingsCore
import DropThingsPlatform

private struct FakeCaptureService: ScreenCaptureService {
    let result: Result<CapturedImage, Error>
    func capture(_ request: ScreenCaptureRequest) async throws -> CapturedImage { try result.get() }
}

private final class StudioPermissionBackend: PermissionBackend, @unchecked Sendable {
    let screenRecording: SystemPermissionState
    init(_ screenRecording: SystemPermissionState) { self.screenRecording = screenRecording }
    func currentState(for permission: SystemPermission) -> SystemPermissionState {
        permission == .screenRecording ? screenRecording : .notDetermined
    }
    @MainActor func openSystemSettings(for permission: SystemPermission) -> Bool { true }
}

private final class StudioFileManager: FileManager {
    var entries: [String: Bool] = [:]
    override func fileExists(atPath path: String) -> Bool { entries[path] != nil }
    override func fileExists(atPath path: String, isDirectory: UnsafeMutablePointer<ObjCBool>?) -> Bool {
        guard let isDirectoryValue = entries[path] else { return false }
        isDirectory?.pointee = ObjCBool(isDirectoryValue)
        return true
    }
}

@MainActor
final class ScreenshotStudioModuleTests: XCTestCase {
    func testMissingPermissionDoesNotInvokeCaptureService() async throws {
        let settings = SettingsStore(backend: InMemorySettingsBackend())
        let permissions = PermissionCenter(backend: StudioPermissionBackend(.notDetermined))
        let module = ScreenshotStudioModule(settings: settings, permissions: permissions, captureService: FakeCaptureService(result: .failure(ScreenCaptureError.captureFailed)))
        module.capture(.display)
        XCTAssertEqual(module.state, .needsPermission(missing: [.screenRecording]))
    }

    func testSaveNameAvoidsCollision() {
        let manager = StudioFileManager()
        let settings = SettingsStore(backend: InMemorySettingsBackend())
        let permissions = PermissionCenter(backend: StudioPermissionBackend(.granted))
        let module = ScreenshotStudioModule(settings: settings, permissions: permissions, fileManager: manager)
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let directory = URL(fileURLWithPath: "/tmp/captures")
        let first = module.nextSaveURL(in: directory, date: date)
        manager.entries[first.path] = false
        let second = module.nextSaveURL(in: directory, date: date)
        XCTAssertNotEqual(first, second)
        XCTAssertTrue(second.lastPathComponent.hasSuffix(" 2.png"))
    }
}
