import Foundation
import SwiftUI

public extension Notification.Name {
    /// Posted before a module presents a full-screen capture surface. The app
    /// shell uses it to move nonessential windows out of the way.
    static let dropThingsCaptureWillBegin = Notification.Name("app.dropthings.capture-will-begin")
}
import Combine

/// A single runnable action surfaced by a module for the menu bar and similar
/// one-tap entry points. Keep it stateless from the caller's point of view —
/// the module decides whether the action is available and what it does.
public struct ModulePrimaryAction: Sendable {
    public let title: String
    public let iconName: String
    public let action: @Sendable () -> Void

    public init(title: String, iconName: String, action: @escaping @Sendable () -> Void) {
        self.title = title
        self.iconName = iconName
        self.action = action
    }
}

/// Contract every module implements. The protocol stays small on purpose; add
/// members only after two real modules need the same shape.
///
/// Modules are reference types and run on `@MainActor`. Every module touches
/// AppKit or SwiftUI in practice, so the protocol makes that isolation
/// explicit instead of letting each conformer invent its own concurrency story.
@MainActor
public protocol DropThingsModule: AnyObject, ObservableObject, CommandSource
where ObjectWillChangePublisher == ObservableObjectPublisher {
    var id: ModuleID { get }
    var name: String { get }
    var summary: String { get }
    var iconName: String { get }
    var requiredPermissions: [SystemPermission] { get }

    /// Current state, observed by the registry.
    var state: ModuleState { get }

    /// Optional primary action exposed in the menu bar when the module is
    /// active. `nil` means the module has no one-tap action and the menu bar
    /// will fall back to opening the module's settings.
    var primaryAction: ModulePrimaryAction? { get }

    /// Begin doing work. Must be idempotent: calling `start()` on a running
    /// module should be a no-op.
    func start() async throws

    /// Stop doing work. Must release listeners, event taps, observers, and
    /// any background tasks. Must be safe to call from any state.
    func stop() async

    /// SwiftUI view rendered in the module detail pane. Keep it short; this is
    /// settings, not a marketing surface.
    func makeSettingsView() -> AnyView
}

extension DropThingsModule {
    public var iconName: String {
        switch id {
        case .scrollControl: return "scroll"
        case .fileShelf: return "tray.and.arrow.down"
        case .menuBarCleaner: return "menubar.rectangle"
        case .keepAwake: return "moon.zzz"
        case .colorPicker: return "eyedropper"
        case .clipboardHistory: return "clipboard"
        case .commandPalette: return "command"
        case .screenshotRegion, .screenshotStudio: return "camera.viewfinder"
        case .windowSnap: return "rectangle.split.2x2"
        case .snippets: return "doc.text"
        case .textTools: return "textformat"
        case .markdownViewer: return "doc.richtext"
        default: return "square.stack.3d.up"
        }
    }
}

extension DropThingsModule {
    /// Every module is a potential Command Palette source. Default is empty;
    /// modules override to expose actions.
    public var commands: [CommandDescriptor] { [] }

    /// Most modules do not expose a one-tap menu-bar action. Conforming types
    /// override this when they have a clear primary action.
    public var primaryAction: ModulePrimaryAction? { nil }
}
