import Foundation

/// Explicit cross-module event stream for captures. Capture producers publish
/// bytes or an already-saved file; the Shelf decides how and whether to store it.
public final class CaptureArchive {
    public enum Entry: Sendable, Equatable {
        case file(URL)
        case png(Data)
    }

    public typealias Observer = @MainActor (Entry) -> Void
    private var observers: [UUID: Observer] = [:]

    public init() {}

    @discardableResult
    @MainActor public func observe(_ observer: @escaping Observer) -> UUID {
        let id = UUID()
        observers[id] = observer
        return id
    }

    @MainActor public func removeObserver(_ id: UUID) {
        observers[id] = nil
    }

    @MainActor public func publish(_ entry: Entry) {
        observers.values.forEach { $0(entry) }
    }
}
