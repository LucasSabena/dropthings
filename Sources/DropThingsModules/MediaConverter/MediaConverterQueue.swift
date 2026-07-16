import Foundation
import SwiftUI
import DropThingsCore
import DropThingsMediaConverterKit

/// Lifecycle phase of a single queued item. Surfaced to the UI as a meaningful
/// label instead of a generic spinner (EXPERIENCE.md "meaningful phases").
public enum MediaItemPhase: Hashable, Sendable {
    case pending
    case probing
    case validating
    case encoding(progress: Double)
    case reprobing
    case finalizing
    case completed(destination: URL, sizeDelta: Int64)
    case failed(reason: String)
    case skipped(reason: String)
    case cancelled

    public var shortLabel: String {
        switch self {
        case .pending: return "Pending"
        case .probing: return "Reading…"
        case .validating: return "Checking…"
        case .encoding: return "Converting…"
        case .reprobing: return "Verifying…"
        case .finalizing: return "Saving…"
        case .completed: return "Done"
        case .failed: return "Failed"
        case .skipped: return "Skipped"
        case .cancelled: return "Cancelled"
        }
    }

    public var progress: Double? {
        if case .encoding(let p) = self { return p }
        return nil
    }

    public var isTerminal: Bool {
        switch self {
        case .completed, .failed, .skipped, .cancelled: return true
        default: return false
        }
    }
}

/// A single item in the conversion queue. Identified by a stable UUID so the
/// UI can track rows across phases.
public struct MediaQueueItem: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let source: URL
    public var phase: MediaItemPhase
    public var displayName: String { source.lastPathComponent }

    public init(id: UUID = UUID(), source: URL, phase: MediaItemPhase = .pending) {
        self.id = id
        self.source = source
        self.phase = phase
    }
}

/// Observable queue of conversion items. Progress updates are throttled before
/// reaching SwiftUI to avoid swamping the main actor on long encodes.
@MainActor
public final class MediaConverterQueue: ObservableObject {
    @Published public private(set) var items: [MediaQueueItem] = []

    private let throttleInterval: TimeInterval
    private var pendingProgress: [UUID: Double] = [:]
    private var lastEmit: Date = .distantPast

    public init(throttleInterval: TimeInterval = 0.1) {
        self.throttleInterval = throttleInterval
    }

    public func enqueue(_ sources: [URL]) -> [UUID] {
        var ids: [UUID] = []
        for source in sources {
            let item = MediaQueueItem(source: source)
            items.append(item)
            ids.append(item.id)
        }
        return ids
    }

    public func setPhase(_ phase: MediaItemPhase, for id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].phase = phase
    }

    public func acceptPipelinePhase(_ phase: MediaItemPhase, for id: UUID) {
        guard let item = items.first(where: { $0.id == id }), !item.phase.isTerminal else { return }
        setPhase(phase, for: id)
    }

    /// Report fractional progress. Throttled: only flushes to the published
    /// property at most every `throttleInterval` seconds, so a long encode does
    /// not starve the main actor.
    public func reportProgress(_ progress: Double, for id: UUID) {
        pendingProgress[id] = progress
        let now = Date()
        guard now.timeIntervalSince(lastEmit) >= throttleInterval else { return }
        lastEmit = now
        flushProgress()
    }

    public func flushProgress() {
        for (id, progress) in pendingProgress {
            setPhase(.encoding(progress: progress), for: id)
        }
        pendingProgress.removeAll()
    }

    public func remove(id: UUID) {
        items.removeAll { $0.id == id }
    }

    public func clearCompleted() {
        items.removeAll { $0.phase.isTerminal }
    }

    public func clearAll() {
        items.removeAll()
    }
}
