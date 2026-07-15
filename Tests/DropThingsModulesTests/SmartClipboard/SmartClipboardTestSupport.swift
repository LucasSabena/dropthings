import Foundation
import DropThingsCore
@testable import DropThingsModules

/// Deterministic permission backend that grants everything, never touching
/// the real system APIs.
@MainActor
final class SmartClipboardFakePermissionBackend: PermissionBackend, @unchecked Sendable {
    func currentState(for permission: SystemPermission) -> SystemPermissionState {
        .granted
    }
    func openSystemSettings(for permission: SystemPermission) -> Bool { true }
}

/// In-memory `PasteboardBackend` for module tests. Mirrors the Core test fake so
/// the module can be driven without touching `NSPasteboard`.
@MainActor
final class SmartClipboardTestBackend: PasteboardBackend, @unchecked Sendable {
    private var handler: (@MainActor @Sendable (PasteboardHub.Snapshot) -> Void)?
    private(set) var running = false

    func start(interval: TimeInterval, handler: @escaping @MainActor @Sendable (PasteboardHub.Snapshot) -> Void) {
        self.handler = handler
        running = true
    }

    func stop() {
        handler = nil
        running = false
    }

    var isRunning: Bool { running }

    func emit(_ snapshot: PasteboardHub.Snapshot) {
        handler?(snapshot)
    }
}

/// Deterministic URL title fetcher for tests.
struct FakeURLTitleFetcher: SmartClipboardURLTitleFetching, Sendable {
    var result: Result<String?, Error>

    func fetchTitle(url: URL) async throws -> String? {
        try result.get()
    }
}

/// A reference-typed box so a `@Sendable` handler closure can record the URLs
/// it was invoked with without capturing a mutable local.
final class URLBox: @unchecked Sendable {
    var urls: [URL] = []
}