import AppKit

/// Parses a pasteboard into `FileShelfItemKind` values. Each item on the
/// pasteboard becomes one shelf item; the caller decides what to do with the
/// list (deduplicate, persist, drop on the floor).
///
/// The reader is `Sendable` because it holds no state; the AppKit-facing
/// method is `@MainActor` because `NSPasteboard` only works on the main
/// thread. Keeping the method isolated matches how `ShelfContentView` calls
/// it during drops.
public struct PasteboardItemReader: Sendable {
    public init() {}

    @MainActor
    public func read(from pasteboard: NSPasteboard) -> [FileShelfItemKind] {
        guard let items = pasteboard.pasteboardItems else { return [] }

        var results: [FileShelfItemKind] = []
        for item in items {
            if let kind = parseFileURL(item: item) {
                results.append(kind)
                continue
            }
            if let kind = parseText(item: item) {
                results.append(kind)
                continue
            }
        }
        return results
    }

    private func parseFileURL(item: NSPasteboardItem) -> FileShelfItemKind? {
        if let data = item.data(forType: .fileURL),
           let url = URL(dataRepresentation: data, relativeTo: nil) {
            return classifyAsFileOrFolder(url)
        }
        // Legacy macOS .filenames pasteboard type. Older sources (pre-Mavericks
        // save panels, some terminal apps) still publish as `NSFilenamesPboardType`
        // which on modern SDKs maps to `com.apple.filepasteboard.pasteboard-type`.
        let legacyType = NSPasteboard.PasteboardType("com.apple.filepasteboard.pasteboard-type")
        if let legacy = item.propertyList(forType: legacyType) as? [String],
           let first = legacy.first {
            return classifyAsFileOrFolder(URL(fileURLWithPath: first))
        }
        return nil
    }

    private func classifyAsFileOrFolder(_ url: URL) -> FileShelfItemKind {
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) {
            return isDir.boolValue ? .folder(url) : .file(url)
        }
        // Path might be offline (network volume), an unresolved alias, or
        // a stale reference. Surface it as a file so the user can reveal
        // it in Finder and decide what to do.
        return .file(url)
    }

    private func parseText(item: NSPasteboardItem) -> FileShelfItemKind? {
        if let string = item.string(forType: .string), !string.isEmpty {
            return .text(string)
        }
        return nil
    }
}
