import Foundation
import SwiftUI

/// Contract every module implements. The protocol stays small on purpose; add
/// members only after two real modules need the same shape.
///
/// Modules are reference types and run on `@MainActor`. Every module touches
/// AppKit or SwiftUI in practice, so the protocol makes that isolation
/// explicit instead of letting each conformer invent its own concurrency story.
@MainActor
public protocol DropThingsModule: AnyObject, CommandSource {
    var id: ModuleID { get }
    var name: String { get }
    var summary: String { get }
    var iconName: String { get }
    var requiredPermissions: [SystemPermission] { get }

    /// Current state, observed by the registry.
    var state: ModuleState { get }

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
        case .commandPalette: return "command"
        case .snippets: return "doc.text"
        case .textTools: return "textformat"
        case .screenshotRegion: return "camera.viewfinder"
        default: return "square.stack.3d.up"
        }
    }
}

extension DropThingsModule {
    /// Every module is a potential Command Palette source. Default is empty;
    /// modules override to expose actions.
    public var commands: [CommandDescriptor] { [] }
}
