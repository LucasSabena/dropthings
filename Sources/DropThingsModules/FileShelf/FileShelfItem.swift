import Foundation

/// What a dropped item actually is on the shelf. The shelf accepts file paths,
/// folder paths, and free-form text (URLs, code snippets, prose — anything the
/// source app puts on the pasteboard as plain text).
public enum FileShelfItemKind: Hashable, Sendable, Codable {
    case file(URL)
    case folder(URL)
    case text(String)

    public var displayName: String {
        switch self {
        case .file(let url): return url.lastPathComponent.isEmpty ? url.path : url.lastPathComponent
        case .folder(let url): return url.lastPathComponent.isEmpty ? url.path : url.lastPathComponent
        case .text(let s):
            let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "Empty text" : String(trimmed.prefix(60))
        }
    }

    public var displayPath: String? {
        switch self {
        case .file(let url), .folder(let url): return url.path
        case .text: return nil
        }
    }

    public var iconName: String {
        switch self {
        case .file: return "doc"
        case .folder: return "folder"
        case .text: return "text.alignleft"
        }
    }
}

/// One item sitting on the shelf. Identity is derived from the payload so two
/// drops of the same file collapse into one slot — deduplication is then just
/// "is it already in the list?".
public struct FileShelfItem: Identifiable, Hashable, Sendable, Codable {
    public let kind: FileShelfItemKind
    public let addedAt: Date
    public let isPinned: Bool

    public init(kind: FileShelfItemKind, addedAt: Date = Date(), isPinned: Bool = false) {
        self.kind = kind
        self.addedAt = addedAt
        self.isPinned = isPinned
    }

    public var id: String {
        switch kind {
        case .file(let url): return "file:" + url.standardizedFileURL.path
        case .folder(let url): return "folder:" + url.standardizedFileURL.path
        // A leading sigil that cannot appear in a path-derived id, so a
        // text item whose content literally starts with "file:" cannot
        // collide with a file item.
        case .text(let s): return "text\u{1F}:" + s
        }
    }

    public var displayName: String { kind.displayName }
    public var displayPath: String? { kind.displayPath }
    public var iconName: String { kind.iconName }

    /// File/folder URL for actions that need one. `nil` for text items.
    public var fileURL: URL? {
        switch kind {
        case .file(let url), .folder(let url): return url
        case .text: return nil
        }
    }

    /// Returns a copy with `isPinned` flipped.
    public func pinning(_ pinned: Bool) -> FileShelfItem {
        FileShelfItem(kind: kind, addedAt: addedAt, isPinned: pinned)
    }
}
