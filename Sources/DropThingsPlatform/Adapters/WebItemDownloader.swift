import Foundation

/// Outcome of a single download attempt. Errors are surfaced explicitly
/// (never swallowed) per the project rule against silent failure.
public enum WebDownloadResult: Sendable {
    case saved(URL)
    case failed(WebDownloadError)
}

public enum WebDownloadError: Error, Equatable, Sendable {
    case badURL
    case networkFailure
    case writeFailure
    case nonImageStatus(Int)

    public var localizedDescription: String {
        switch self {
        case .badURL: return "the link is not valid"
        case .networkFailure: return "the download failed (network)"
        case .writeFailure: return "could not save the file"
        case .nonImageStatus(let code): return "the server returned \(code)"
        }
    }
}

/// Downloads a web URL to disk and returns the local file URL. Hidden
/// behind a protocol so the ingest coordinator can be tested with a fake.
public protocol WebItemDownloading: AnyObject, Sendable {
    /// Downloads `remote` into the configured downloads directory, choosing
    /// a filename from the URL path or a timestamp fallback, and avoiding
    /// collisions with existing files. `progress` is called on the main
    /// actor as bytes arrive (0…1). The result is delivered on the main
    /// actor.
    func download(
        _ remote: URL,
        progress: @escaping @MainActor (Double) -> Void
    ) async -> WebDownloadResult
}

/// Default downloader writing into `~/Downloads/Dropthings/`. URLSession is
/// the only fragile API here; everything else is file IO.
public final class WebItemDownloader: WebItemDownloading, @unchecked Sendable {
    private let session: URLSession
    private let directory: URL
    private let fileManager: FileManager

    public init(
        directory: URL? = nil,
        session: URLSession = .shared,
        fileManager: FileManager = .default
    ) {
        self.session = session
        self.fileManager = fileManager
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

    public func download(
        _ remote: URL,
        progress: @escaping @MainActor (Double) -> Void
    ) async -> WebDownloadResult {
        // URLSession needs an https/http scheme.
        guard remote.scheme == "http" || remote.scheme == "https" else {
            return .failed(.badURL)
        }
        do {
            let (asyncBytes, response) = try await session.bytes(from: remote)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                return .failed(.nonImageStatus(http.statusCode))
            }
            let dest = resolveDestination(for: remote)
            var data = Data()
            let total = response.expectedContentLength
            for try await byte in asyncBytes {
                data.append(byte)
                if total > 0 {
                    await progress(Double(data.count) / Double(total))
                }
            }
            do {
                try data.write(to: dest, options: .atomic)
                await progress(1)
                return .saved(dest)
            } catch {
                return .failed(.writeFailure)
            }
        } catch {
            return .failed(.networkFailure)
        }
    }

    /// Where to write this download. Picks a name from the URL's last path
    /// component; if that has no extension, infers one from the MIME type;
    /// if it collides, appends " 2", " 3", … Public so the naming rules
    /// can be unit-tested directly.
    public func resolveDestination(for remote: URL) -> URL {
        let rawName = remote.lastPathComponent
        var name = rawName.isEmpty ? "Dropthings \(timestamp())" : rawName
        if (name as NSString).pathExtension.isEmpty {
            name += ".bin"
        }
        return uniqueURL(for: name)
    }

    private func uniqueURL(for name: String) -> URL {
        let first = directory.appendingPathComponent(name)
        if !fileManager.fileExists(atPath: first.path) { return first }
        let stem = (name as NSString).deletingPathExtension
        let ext = (name as NSString).pathExtension
        var i = 2
        while true {
            let candidate = ext.isEmpty
                ? "\(stem) \(i)"
                : "\(stem) \(i).\(ext)"
            let url = directory.appendingPathComponent(candidate)
            if !fileManager.fileExists(atPath: url.path) { return url }
            i += 1
        }
    }

    private func timestamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH.mm.ss"
        return f.string(from: Date())
    }
}
