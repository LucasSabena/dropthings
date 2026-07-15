import Foundation
import Combine

/// Backend contract for `PasteboardHub`. Platform provides the `NSPasteboard`-
/// backed implementation; tests inject an in-memory one that can post
/// synthetic changes. Isolated to `@MainActor` because every current consumer
/// drives UI state from the change callback and `NSPasteboard` is main-actor.
@MainActor
public protocol PasteboardBackend: AnyObject, Sendable {
    /// Begin observing. `handler` is called on the main actor for every
    /// detected change. Idempotent.
    func start(interval: TimeInterval, handler: @escaping @MainActor @Sendable (PasteboardHub.Snapshot) -> Void)
    /// Stop observing and release the timer/observer. Idempotent.
    func stop()
    /// `true` while the backend is actively polling/listening.
    var isRunning: Bool { get }
}

/// Single observable stream of pasteboard changes shared by every module that
/// needs to react to what the user copies. Owned by Core so modules never
/// create their own `NSPasteboard` poller — the architecture rule is "one
/// observer, no duplicate/self-trigger loops".
///
/// Core owns the contracts and the subscriber registry; the platform backend
/// (`PasteboardObserver`) owns the fragile `NSPasteboard` reads. The hub is
/// `@MainActor` because every current consumer (Clipboard History, File Shelf,
/// Smart Clipboard) drives SwiftUI/AppKit state from the change callback.
@MainActor
public final class PasteboardHub: ObservableObject {
    /// A bounded, typed view of the pasteboard at one `changeCount`. The
    /// observer fills this in; modules never read `NSPasteboard` themselves.
    public struct Snapshot: Sendable, Equatable {
        public let changeCount: Int
        public let text: String?
        public let url: URL?
        public let fileURLs: [URL]
        public let imageData: Data?
        public let colorHex: String?
        public let isTransient: Bool
        public let isConcealed: Bool
        public let sourceBundleID: String?

        public init(
            changeCount: Int,
            text: String?,
            url: URL?,
            fileURLs: [URL],
            imageData: Data?,
            colorHex: String?,
            isTransient: Bool,
            isConcealed: Bool,
            sourceBundleID: String?
        ) {
            self.changeCount = changeCount
            self.text = text
            self.url = url
            self.fileURLs = fileURLs
            self.imageData = imageData
            self.colorHex = colorHex
            self.isTransient = isTransient
            self.isConcealed = isConcealed
            self.sourceBundleID = sourceBundleID
        }
    }

    /// An opaque token identifying who authored a pasteboard write. Subscribers
    /// compare it against their own author identity to avoid re-processing a
    /// write they triggered (the self-trigger loop the architecture calls out).
    public struct OriginToken: Hashable, Sendable {
        public let rawValue: String
        public init(_ rawValue: String) { self.rawValue = rawValue }
    }

    /// One subscriber's handle. Cancelling it removes the subscriber. The
    /// handle itself is not main-actor-isolated (it only stores a UUID and a
    /// weak reference); `cancel()` hops to the main actor to mutate the hub.
    public final class Subscription: Hashable, @unchecked Sendable {
        public let id: UUID
        private weak var hub: PasteboardHub?
        fileprivate init(id: UUID, hub: PasteboardHub) {
            self.id = id
            self.hub = hub
        }
        @MainActor
        public func cancel() {
            hub?.removeSubscriber(id: id)
        }
        public nonisolated func hash(into hasher: inout Hasher) { hasher.combine(id) }
        public static func == (lhs: Subscription, rhs: Subscription) -> Bool { lhs.id == rhs.id }
    }

    @Published public private(set) var latestSnapshot: Snapshot?
    /// The origin token recorded for the most recent write, or `nil` when the
    /// change came from outside DropThings. Subscribers use this to drop their
    /// own echoes instead of deduplicating by content hash alone.
    @Published public private(set) var latestOrigin: OriginToken?

    private let backend: PasteboardBackend
    private var subscribers: [UUID: @MainActor @Sendable (Snapshot) -> Void] = [:]
    private var subscriberOrigins: [UUID: OriginToken] = [:]
    private var pollingInterval: TimeInterval = 0.25

    public init(backend: PasteboardBackend) {
        self.backend = backend
    }

    public var isRunning: Bool { backend.isRunning }

    /// Start the shared observer. Idempotent. The interval only applies on the
    /// first start; subsequent calls keep the existing cadence so a second
    /// module enabling cannot shrink the interval under a running one.
    public func start(interval: TimeInterval = 0.25) {
        guard !backend.isRunning else { return }
        self.pollingInterval = interval
        backend.start(interval: interval) { [weak self] snapshot in
            self?.dispatch(snapshot)
        }
    }

    public func stop() {
        backend.stop()
    }

    /// Register a subscriber. `origin` lets the subscriber identify its own
    /// writes via `latestOrigin` so it can drop echoes without content-hash
    /// deduplication. The returned subscription must be held for the lifetime
    /// of the subscription; cancelling it removes the subscriber.
    @discardableResult
    public func subscribe(
        origin: OriginToken,
        handler: @escaping @MainActor @Sendable (Snapshot) -> Void
    ) -> Subscription {
        let id = UUID()
        subscribers[id] = handler
        subscriberOrigins[id] = origin
        return Subscription(id: id, hub: self)
    }

    /// Record an author identity for a write the caller is about to perform.
    /// Subscribers whose origin matches see this as a self-authored change and
    /// can ignore it. Must be called right before the actual pasteboard write
    /// so the next poll picks it up with the right origin.
    public func recordWrite(origin: OriginToken) {
        latestOrigin = origin
    }

    /// Clear the recorded origin once the echo has been delivered, so a later
    /// external change with the same `changeCount` is not mis-attributed.
    public func clearOrigin() {
        latestOrigin = nil
    }

    /// Overwrite the cached snapshot. Used by a caller that needs to reflect a
    /// fresher pasteboard read than the next poll (e.g. an explicit panel
    /// refresh). The next poll will reconcile `changeCount` naturally.
    public func overrideLatest(_ snapshot: Snapshot) {
        latestSnapshot = snapshot
    }

    fileprivate func removeSubscriber(id: UUID) {
        subscribers.removeValue(forKey: id)
        subscriberOrigins.removeValue(forKey: id)
    }

    private func dispatch(_ snapshot: Snapshot) {
        latestSnapshot = snapshot
        for (id, handler) in subscribers {
            let origin = subscriberOrigins[id]
            // Echo suppression: if this subscriber authored the change, skip it.
            if let origin, latestOrigin == origin { continue }
            handler(snapshot)
        }
        // Reset origin after the dispatch so a subsequent external change at
        // the same changeCount is treated as external.
        clearOrigin()
    }
}