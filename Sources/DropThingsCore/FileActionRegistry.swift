import Foundation
import Combine

/// Core-owned registry for file actions that modules publish and consume
/// without importing each other. Producers (Media Converter, Workbench, Smart
/// Clipboard's file actions) register descriptors; consumers (Smart Clipboard,
/// the panel) discover them by content type and invoke through Core.
///
/// This is the only supported path for cross-module file workflows; modules
/// MUST NOT import each other.
@MainActor
public final class FileActionRegistry: ObservableObject {
    public struct Descriptor: Hashable, Sendable, Identifiable {
        public let id: String
        public let title: String
        public let systemImage: String
        /// Bundle identifier or module id of the producer, for diagnostics.
        public let producerID: String
        /// `true` when the producer is currently able to run (its module is
        /// enabled and healthy). Consumers hide disabled actions instead of
        /// failing when invoked.
        public let isAvailable: () -> @Sendable () -> Bool

        public init(
            id: String,
            title: String,
            systemImage: String,
            producerID: String,
            isAvailable: @escaping @Sendable () -> () -> Bool
        ) {
            self.id = id
            self.title = title
            self.systemImage = systemImage
            self.producerID = producerID
            self.isAvailable = isAvailable
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(id)
            hasher.combine(title)
            hasher.combine(systemImage)
            hasher.combine(producerID)
        }
        public static func == (lhs: Descriptor, rhs: Descriptor) -> Bool {
            lhs.id == rhs.id && lhs.title == rhs.title
                && lhs.systemImage == rhs.systemImage && lhs.producerID == rhs.producerID
        }
    }

    /// What a producer can do with a set of file URLs.
    public struct ActionHandler: Hashable, Sendable {
        public let id: String
        public let run: @Sendable ([URL]) -> Void

        public init(id: String, run: @escaping @Sendable ([URL]) -> Void) {
            self.id = id
            self.run = run
        }
        public func hash(into hasher: inout Hasher) { hasher.combine(id) }
        public static func == (lhs: ActionHandler, rhs: ActionHandler) -> Bool { lhs.id == rhs.id }
    }

    @Published public private(set) var descriptors: [Descriptor] = []

    private var handlers: [String: ActionHandler] = [:]

    public init() {}

    /// Register a file action. Producers call this once on module start.
    /// Re-registering with the same `id` replaces the handler atomically.
    public func register(_ descriptor: Descriptor, handler: ActionHandler) {
        descriptors.removeAll { $0.id == descriptor.id }
        descriptors.append(descriptor)
        handlers[descriptor.id] = handler
        descriptors.sort { $0.title < $1.title }
    }

    /// Remove a producer's action. Idempotent.
    public func unregister(id: String) {
        descriptors.removeAll { $0.id == id }
        handlers.removeValue(forKey: id)
    }

    /// Remove every action from a producer (used on module stop).
    public func unregisterProducer(_ producerID: String) {
        descriptors.removeAll { $0.producerID == producerID }
        handlers = handlers.filter { $0.value.id != producerID }
    }

    /// Descriptors currently available for the given file kind. Hides
    /// unavailable actions so consumers never present a dead button.
    public func availableActions() -> [Descriptor] {
        descriptors.filter { $0.isAvailable()() }
    }

    /// Run an action by id. Returns `false` when the action is missing or
    /// currently unavailable so the caller can surface a message instead of
    /// silently no-op'ing.
    @discardableResult
    public func run(id: String, for urls: [URL]) -> Bool {
        guard let descriptor = descriptors.first(where: { $0.id == id }),
              descriptor.isAvailable()() else { return false }
        guard let handler = handlers[id] else { return false }
        handler.run(urls)
        return true
    }

    /// Opaque references Smart Clipboard stores in its panel so it never
    /// imports a producer module.
    public func references() -> [FileActionRefShim] {
        availableActions().map { FileActionRefShim(id: $0.id, title: $0.title, systemImage: $0.systemImage) }
    }
}

/// Value-only reference consumed by Smart Clipboard so it avoids importing the
/// producer's module. Lives in Core so both sides share the shape.
public struct FileActionRefShim: Hashable, Sendable, Identifiable {
    public let id: String
    public let title: String
    public let systemImage: String
    public init(id: String, title: String, systemImage: String) {
        self.id = id
        self.title = title
        self.systemImage = systemImage
    }
}