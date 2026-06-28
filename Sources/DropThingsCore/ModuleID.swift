import Foundation

/// Stable identifier for a module. Persisted in `UserDefaults` and used as the
/// key in the registry, so it must be unique, human-readable, and never change
/// once a module ships. Adding a new id is fine; renaming an existing one is a
/// breaking change that requires a settings migration.
public struct ModuleID: Hashable, RawRepresentable, Codable, Sendable, CustomStringConvertible {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    public var description: String { rawValue }
}

extension ModuleID {
    public static let fake = ModuleID("core.fake")
    public static let scrollControl = ModuleID("modules.scroll-control")
    public static let fileShelf = ModuleID("modules.file-shelf")
    public static let menuBarCleaner = ModuleID("modules.menu-bar-cleaner")
    public static let keepAwake = ModuleID("modules.keep-awake")
    public static let colorPicker = ModuleID("modules.color-picker")
    public static let screenshot = ModuleID("modules.screenshot")
}
