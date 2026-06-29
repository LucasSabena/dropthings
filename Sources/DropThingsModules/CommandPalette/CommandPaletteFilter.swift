import Foundation
import DropThingsCore

/// Pure filtering logic for the Command Palette. Kept separate so it can be
/// unit-tested without instantiating AppKit UI.
enum CommandPaletteFilter {
    static func filter(_ commands: [CommandDescriptor], query: String) -> [CommandDescriptor] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return commands }
        return commands.filter {
            $0.title.localizedCaseInsensitiveContains(trimmed)
                || ($0.subtitle?.localizedCaseInsensitiveContains(trimmed) ?? false)
        }
    }
}
