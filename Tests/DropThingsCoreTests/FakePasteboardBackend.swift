import Foundation
@testable import DropThingsCore

/// In-memory `PasteboardBackend` for tests. Posts synthetic snapshots on
/// demand so tests never touch the real pasteboard.
@MainActor
final class FakePasteboardBackend: PasteboardBackend, @unchecked Sendable {
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

    /// Emit a snapshot to the hub as if a pasteboard change happened.
    func emit(_ snapshot: PasteboardHub.Snapshot) {
        handler?(snapshot)
    }
}