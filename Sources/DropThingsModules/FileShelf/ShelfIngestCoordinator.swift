import Foundation
import UniformTypeIdentifiers
import DropThingsPlatform

/// The outcome of resolving one pasteboard candidate into shelf items.
/// Pure: the coordinator never touches the network or disk directly; it
/// delegates to the injected downloader and image saver.
public enum IngestDecision: Equatable {
    /// Candidate maps directly to an existing file item.
    case ready(FileShelfItemKind)
    /// Candidate needs async work (download or save bytes) before it can
    /// become an item. The coordinator runs the work and the caller awaits.
    case deferred(URL) // placeholder; replaced by the resolved file URL
}

/// Decides, for each `PasteboardCandidate`, whether it can become a shelf
/// item immediately (local file, text) or needs a download/save step
/// (web URL, raw image bytes). Pure decision logic is split from the
/// async execution so it can be unit-tested with a fake downloader.
public struct ShelfIngestCoordinator: Sendable {
    private let downloader: any WebItemDownloading
    private let imageSaver: any ImageSaverProtocol

    public init(downloader: any WebItemDownloading, imageSaver: any ImageSaverProtocol) {
        self.downloader = downloader
        self.imageSaver = imageSaver
    }

    /// Maps one candidate to a shelf kind, performing any async work
    /// needed. Failures are returned as `nil` (the caller surfaces an
    /// error summary); never throws silently — the result type carries the
    /// error so the UI can show it.
    public func resolve(
        _ candidate: PasteboardCandidate,
        progress: @escaping @MainActor (Double) -> Void
    ) async -> ResolveOutcome {
        switch candidate {
        case .fileURL(let url):
            return .item(.fileOrFolder(at: url))
        case .text(let s):
            return .item(.text(s))
        case .webURL(let url):
            let result = await downloader.download(url, progress: progress)
            switch result {
            case .saved(let local):
                return .item(.fileOrFolder(at: local))
            case .failed(let error):
                return .failed(url, error)
            }
        case .image(let data, let uti):
            do {
                let local = try await imageSaver.save(data: data, type: uti)
                return .item(.fileOrFolder(at: local))
            } catch {
                return .failed(nil, .writeFailure)
            }
        }
    }

    public enum ResolveOutcome: Equatable {
        case item(FileShelfItemKind)
        case failed(URL?, WebDownloadError)
    }
}

/// Saves raw image bytes to disk. Behind a protocol so the coordinator is
/// testable without real file IO.
public protocol ImageSaverProtocol: AnyObject, Sendable {
    func save(data: Data, type: UTType) async throws -> URL
}

/// Writes image bytes into the Dropthings downloads folder, picking the
/// extension from the UTI and de-duplicating the filename.
public final class ImageSaver: ImageSaverProtocol, @unchecked Sendable {
    private let directory: URL
    private let fileManager: FileManager
    private let now: @Sendable () -> Date
    private let lock = NSLock()

    public init(
        directory: URL? = nil,
        fileManager: FileManager = .default,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.fileManager = fileManager
        self.now = now
        if let directory {
            self.directory = directory
        } else {
            let downloads = (try? fileManager.url(
                for: .downloadsDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )) ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Downloads")
            self.directory = downloads.appendingPathComponent("Dropthings", isDirectory: true)
        }
        try? fileManager.createDirectory(at: self.directory, withIntermediateDirectories: true)
    }

    public func save(data: Data, type: UTType) async throws -> URL {
        try saveSynchronously(data: data, type: type)
    }

    private func saveSynchronously(data: Data, type: UTType) throws -> URL {
        lock.lock()
        defer { lock.unlock() }
        let ext = preferredExtension(for: type)
        let name = "Image \(timestamp(now()))\(ext)"
        let url = uniqueURL(for: name)
        try data.write(to: url, options: .atomic)
        return url
    }

    private func uniqueURL(for name: String) -> URL {
        let first = directory.appendingPathComponent(name)
        guard fileManager.fileExists(atPath: first.path) else { return first }
        let stem = (name as NSString).deletingPathExtension
        let ext = (name as NSString).pathExtension
        var suffix = 2
        while true {
            let candidateName = ext.isEmpty
                ? "\(stem) \(suffix)"
                : "\(stem) \(suffix).\(ext)"
            let candidate = directory.appendingPathComponent(candidateName)
            if !fileManager.fileExists(atPath: candidate.path) { return candidate }
            suffix += 1
        }
    }

    private func preferredExtension(for type: UTType) -> String {
        if type == .png { return ".png" }
        if type == .jpeg { return ".jpg" }
        // TIFF from browser drags is common; normalize to png if the bytes
        // look like a raster, otherwise keep tiff.
        if type == .tiff { return ".tiff" }
        return (type.preferredFilenameExtension.map { "." + $0 }) ?? ""
    }

    private func timestamp(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH.mm.ss"
        return f.string(from: date)
    }
}

public extension FileShelfItemKind {
    /// Classifies an on-disk URL as `.file` or `.folder` so callers don't
    /// each re-implement the `isDirectory` check.
    static func fileOrFolder(at url: URL) -> FileShelfItemKind {
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) {
            return isDir.boolValue ? .folder(url) : .file(url)
        }
        return .file(url)
    }
}
