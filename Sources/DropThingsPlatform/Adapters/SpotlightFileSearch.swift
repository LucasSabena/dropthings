import Foundation

public struct SpotlightFileRecord: Hashable, Sendable {
    public let id: String
    public let url: URL
    public let name: String
    public let parentPath: String
    public let isDirectory: Bool
    public let modifiedAt: Date?
    public let relevance: Double

    public init(id: String, url: URL, name: String, parentPath: String, isDirectory: Bool, modifiedAt: Date?, relevance: Double) {
        self.id = id
        self.url = url
        self.name = name
        self.parentPath = parentPath
        self.isDirectory = isDirectory
        self.modifiedAt = modifiedAt
        self.relevance = relevance
    }
}

public enum SpotlightFileSearchError: LocalizedError, Sendable {
    case unavailable
    case failed

    public var errorDescription: String? {
        switch self {
        case .unavailable: return "Spotlight search is unavailable."
        case .failed: return "Spotlight could not complete this search."
        }
    }
}

public protocol SpotlightFileSearching: Sendable {
    @MainActor
    func search(
        query: String,
        includeContents: Bool,
        includeHidden: Bool,
        excludedPaths: [String],
        maximumResults: Int
    ) async throws -> [SpotlightFileRecord]
}

/// One-shot cancellable wrapper around NSMetadataQuery. Each call owns its
/// observers and query, so cancellation cannot leak stale notifications into a
/// later generation.
@MainActor
public final class SpotlightFileSearch: SpotlightFileSearching, @unchecked Sendable {
    public init() {}

    public func search(
        query: String,
        includeContents: Bool,
        includeHidden: Bool,
        excludedPaths: [String],
        maximumResults: Int
    ) async throws -> [SpotlightFileRecord] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let session = Session(
            queryText: trimmed,
            includeContents: includeContents,
            includeHidden: includeHidden,
            excludedPaths: excludedPaths,
            maximumResults: maximumResults
        )
        return try await withTaskCancellationHandler {
            try await session.run()
        } onCancel: {
            Task { @MainActor in session.cancel() }
        }
    }
}

@MainActor
private final class Session {
    private let metadataQuery = NSMetadataQuery()
    private let includeHidden: Bool
    private let excludedPaths: [String]
    private let maximumResults: Int
    private var observer: NSObjectProtocol?
    private var continuation: CheckedContinuation<[SpotlightFileRecord], Error>?
    private var finished = false

    init(queryText: String, includeContents: Bool, includeHidden: Bool, excludedPaths: [String], maximumResults: Int) {
        self.includeHidden = includeHidden
        self.excludedPaths = excludedPaths.map { URL(fileURLWithPath: $0).standardizedFileURL.path }
        self.maximumResults = max(1, maximumResults)
        let escaped = queryText.replacingOccurrences(of: "*", with: "\\*").replacingOccurrences(of: "?", with: "\\?")
        let wildcard = "*\(escaped)*"
        let filename = NSPredicate(format: "%K ==[cd] %@", NSMetadataItemFSNameKey, wildcard)
        if includeContents {
            let content = NSPredicate(format: "%K ==[cd] %@", NSMetadataItemTextContentKey, wildcard)
            metadataQuery.predicate = NSCompoundPredicate(orPredicateWithSubpredicates: [filename, content])
        } else {
            metadataQuery.predicate = filename
        }
        metadataQuery.searchScopes = [NSMetadataQueryUserHomeScope, NSMetadataQueryLocalComputerScope]
        metadataQuery.sortDescriptors = [NSSortDescriptor(key: NSMetadataItemFSNameKey, ascending: true, selector: #selector(NSString.localizedStandardCompare(_:)))]
    }

    func run() async throws -> [SpotlightFileRecord] {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            observer = NotificationCenter.default.addObserver(
                forName: .NSMetadataQueryDidFinishGathering,
                object: metadataQuery,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in self?.complete() }
            }
            guard metadataQuery.start() else {
                finish(.failure(SpotlightFileSearchError.unavailable))
                return
            }
        }
    }

    func cancel() {
        finish(.failure(CancellationError()))
    }

    private func complete() {
        metadataQuery.disableUpdates()
        // Bound Foundation-object mapping on the main actor. Exclusions and
        // hidden-item filtering can discard candidates, so keep a small
        // overscan without walking an arbitrarily large Spotlight result set.
        let candidates = metadataQuery.results.prefix(maximumResults * 4)
        let mapped = candidates.compactMap { item -> SpotlightFileRecord? in
            guard let item = item as? NSMetadataItem,
                  let path = item.value(forAttribute: NSMetadataItemPathKey) as? String else { return nil }
            let url = URL(fileURLWithPath: path).standardizedFileURL
            let name = (item.value(forAttribute: NSMetadataItemFSNameKey) as? String) ?? url.lastPathComponent
            guard includeHidden || !name.hasPrefix(".") else { return nil }
            guard !excludedPaths.contains(where: { path == $0 || path.hasPrefix($0 + "/") }) else { return nil }
            let contentType = item.value(forAttribute: NSMetadataItemContentTypeKey) as? String
            let isDirectory = contentType == "public.folder" || (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
            let modified = item.value(forAttribute: NSMetadataItemFSContentChangeDateKey) as? Date
            return SpotlightFileRecord(
                id: "file:\(url.path)",
                url: url,
                name: name,
                parentPath: url.deletingLastPathComponent().path,
                isDirectory: isDirectory,
                modifiedAt: modified,
                relevance: 0
            )
        }
        finish(.success(Array(mapped.prefix(maximumResults))))
    }

    private func finish(_ result: Result<[SpotlightFileRecord], Error>) {
        guard !finished else { return }
        finished = true
        metadataQuery.stop()
        if let observer { NotificationCenter.default.removeObserver(observer) }
        observer = nil
        continuation?.resume(with: result)
        continuation = nil
    }
}
