import Foundation

/// Coordinates short-lived module panels such as Command Palette, File Shelf,
/// and Clipboard History. Presenting one dismisses the others, and the app
/// shell can dismiss all of them when DropThings deactivates.
@MainActor
public final class TransientSurfaceCoordinator {
    public typealias DismissAction = @MainActor () -> Void

    private var dismissActions: [ModuleID: DismissAction] = [:]

    public init() {}

    public func register(_ id: ModuleID, dismiss: @escaping DismissAction) {
        dismissActions[id] = dismiss
    }

    public func unregister(_ id: ModuleID) {
        dismissActions[id] = nil
    }

    public func prepareToPresent(_ id: ModuleID) {
        for (otherID, dismiss) in dismissActions where otherID != id {
            dismiss()
        }
    }

    public func dismissAll() {
        for dismiss in dismissActions.values {
            dismiss()
        }
    }
}
