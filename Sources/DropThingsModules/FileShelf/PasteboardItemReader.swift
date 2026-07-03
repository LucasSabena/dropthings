import AppKit
import UniformTypeIdentifiers

/// A richer reading of a single pasteboard item, used by the ingest
/// coordinator to decide between reusing a local file, saving raw image
/// bytes to disk, downloading a web URL, or storing text. The plain
/// `FileShelfItemKind` is derived from these by the coordinator.
public enum PasteboardCandidate: Equatable, Sendable {
    /// A real file or folder already on disk.
    case fileURL(URL)
    /// Raw image bytes plus the best-guess UTI (TIFF/PNG from a browser
    /// drag). The coordinator writes these to disk.
    case image(Data, UTType)
    /// A remote http(s) link that should be downloaded.
    case webURL(URL)
    /// Free-form text.
    case text(String)
}

/// Parses a pasteboard into candidates. Each item on the pasteboard
/// becomes one candidate; the caller (ingest coordinator) decides what to
/// do with the list.
///
/// The reader is `Sendable` because it holds no state; the AppKit-facing
/// method is `@MainActor` because `NSPasteboard` only works on the main
/// thread. Keeping the method isolated matches how `ShelfContentView` calls
/// it during drops.
public struct PasteboardItemReader: Sendable {
    public init() {}

    /// Legacy path: read straight into shelf item kinds (file/folder/text).
    /// Kept for compatibility; the coordinator path uses `candidates(from:)`.
    @MainActor
    public func read(from pasteboard: NSPasteboard) -> [FileShelfItemKind] {
        let resolved = candidates(from: pasteboard)
        // Resolve the trivial ones; web/image candidates need async work
        // the legacy method cannot do, so they fall back to text here.
        return resolved.compactMap { candidate -> FileShelfItemKind? in
            switch candidate {
            case .fileURL(let url):
                return classifyAsFileOrFolder(url)
            case .text(let s):
                return .text(s)
            case .webURL(let url):
                return .text(url.absoluteString)
            case .image:
                return nil
            }
        }
    }

    /// Richer read that exposes raw image bytes and web URLs distinctly so
    /// the ingest coordinator can download/save them. Order of preference
    /// per item: file URL > raw image > web URL > text.
    @MainActor
    public func candidates(from pasteboard: NSPasteboard) -> [PasteboardCandidate] {
        guard let items = pasteboard.pasteboardItems else { return [] }

        var results: [PasteboardCandidate] = []
        for item in items {
            if let candidate = fileURLCandidate(item: item) {
                results.append(candidate)
                continue
            }
            if let candidate = imageCandidate(item: item) {
                results.append(candidate)
                continue
            }
            if let candidate = webURLCandidate(item: item) {
                results.append(candidate)
                continue
            }
            if let candidate = textCandidate(item: item) {
                results.append(candidate)
                continue
            }
        }
        return results
    }

    // MARK: - Per-type parsers

    private func fileURLCandidate(item: NSPasteboardItem) -> PasteboardCandidate? {
        if let data = item.data(forType: .fileURL),
           let url = URL(dataRepresentation: data, relativeTo: nil) {
            return .fileURL(url)
        }
        let legacyType = NSPasteboard.PasteboardType("com.apple.filepasteboard.pasteboard-type")
        if let legacy = item.propertyList(forType: legacyType) as? [String],
           let first = legacy.first {
            return .fileURL(URL(fileURLWithPath: first))
        }
        return nil
    }

    /// Raw image bytes dragged from a browser (TIFF or PNG on the
    /// pasteboard). Pick the most specific UTI we can identify.
    private func imageCandidate(item: NSPasteboardItem) -> PasteboardCandidate? {
        // Prefer PNG, then TIFF (the default image pasteboard type).
        let preferred: [NSPasteboard.PasteboardType] = [
            NSPasteboard.PasteboardType(UTType.png.identifier),
            NSPasteboard.PasteboardType(UTType.tiff.identifier)
        ]
        for type in preferred {
            if let data = item.data(forType: type) {
                let uti = (type == NSPasteboard.PasteboardType(UTType.png.identifier)) ? UTType.png : UTType.tiff
                return .image(data, uti)
            }
        }
        return nil
    }

    /// A web URL (http/https) that is not a file:// reference. Browser
    /// image drags usually publish this alongside the image bytes; we
    /// prefer the bytes when present, so this only wins on its own.
    private func webURLCandidate(item: NSPasteboardItem) -> PasteboardCandidate? {
        guard let raw = item.string(forType: .URL),
              let url = URL(string: raw),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            return nil
        }
        return .webURL(url)
    }

    private func textCandidate(item: NSPasteboardItem) -> PasteboardCandidate? {
        if let string = item.string(forType: .string), !string.isEmpty {
            return .text(string)
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
}
