import Foundation

/// Describes one runnable action surfaced by the Command Palette. Each module
/// returns descriptors for its current actions; the palette owns presentation
/// and ranking. Descriptors are not persisted.
public struct CommandDescriptor: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let subtitle: String?
    public let iconName: String?
    public let action: @Sendable () -> Void

    public init(
        id: String,
        title: String,
        subtitle: String? = nil,
        iconName: String? = nil,
        action: @escaping @Sendable () -> Void
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.iconName = iconName
        self.action = action
    }
}

/// Protocol adopted by modules (or core services) that expose actions to the
/// Command Palette. Keep the contract value-based: return descriptors for the
/// current state, never mutable shared state.
@MainActor
public protocol CommandSource: AnyObject {
    var commands: [CommandDescriptor] { get }
}
