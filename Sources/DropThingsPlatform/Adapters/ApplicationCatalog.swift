import AppKit
import Foundation

public struct ApplicationRecord: Hashable, Sendable {
    public let id: String
    public let name: String
    public let bundleIdentifier: String?
    public let url: URL
    public let aliases: [String]

    public init(id: String, name: String, bundleIdentifier: String?, url: URL, aliases: [String] = []) {
        self.id = id
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.url = url
        self.aliases = aliases
    }
}

public protocol ApplicationCataloging: Sendable {
    func applications(in additionalLocations: [URL]) async -> [ApplicationRecord]
    func invalidate() async
}

/// Discovers launchable application bundles once and keeps a bounded in-memory
/// snapshot. File-system objects never escape this adapter.
public actor ApplicationCatalog: ApplicationCataloging {
    private let fileManager: FileManager
    private var cached: (locationPaths: [String], records: [ApplicationRecord])?

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public static var defaultLocations: [URL] {
        defaultRoots(fileManager: .default)
    }

    public func applications(in additionalLocations: [URL] = []) async -> [ApplicationRecord] {
        let locationPaths = additionalLocations.map { $0.standardizedFileURL.path }.sorted()
        if let cached, cached.locationPaths == locationPaths { return cached.records }
        let roots = Self.defaultRoots(fileManager: fileManager) + additionalLocations
        let records = await Task.detached(priority: .utility) {
            Self.discover(roots: roots, fileManager: FileManager())
        }.value
        cached = (locationPaths, records)
        return records
    }

    public func invalidate() {
        cached = nil
    }

    public static func deduplicated(_ records: [ApplicationRecord]) -> [ApplicationRecord] {
        var bundleIDs = Set<String>()
        var paths = Set<String>()
        return records.sorted { $0.url.path.localizedStandardCompare($1.url.path) == .orderedAscending }.filter { record in
            let path = record.url.standardizedFileURL.resolvingSymlinksInPath().path
            guard paths.insert(path).inserted else { return false }
            if let bundleID = record.bundleIdentifier?.lowercased(), !bundleID.isEmpty {
                guard bundleIDs.insert(bundleID).inserted else { return false }
            }
            return true
        }
    }

    private static func defaultRoots(fileManager: FileManager) -> [URL] {
        var roots = [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            URL(fileURLWithPath: "/System/Applications", isDirectory: true),
            URL(fileURLWithPath: "/System/Library/CoreServices", isDirectory: true)
        ]
        if let home = fileManager.homeDirectoryForCurrentUser as URL? {
            roots.append(home.appendingPathComponent("Applications", isDirectory: true))
        }
        return roots
    }

    private static func discover(roots: [URL], fileManager: FileManager) -> [ApplicationRecord] {
        let keys: [URLResourceKey] = [.isDirectoryKey, .isPackageKey, .isHiddenKey, .nameKey]
        var records: [ApplicationRecord] = []
        for root in roots where fileManager.fileExists(atPath: root.path) {
            guard let enumerator = fileManager.enumerator(
                at: root,
                includingPropertiesForKeys: keys,
                options: [.skipsHiddenFiles, .skipsPackageDescendants],
                errorHandler: { _, _ in true }
            ) else { continue }
            for case let url as URL in enumerator where url.pathExtension.lowercased() == "app" {
                guard let record = record(for: url) else { continue }
                records.append(record)
            }
        }
        return deduplicated(records)
    }

    static func record(for url: URL) -> ApplicationRecord? {
        let lowerPath = url.path.lowercased()
        guard !lowerPath.contains("/contents/library/loginitems/"),
              !lowerPath.contains("/contents/helpers/") else { return nil }
        guard let bundle = Bundle(url: url), bundle.bundleURL.pathExtension == "app" else { return nil }
        let executable = bundle.executableURL
        guard executable.map({ FileManager.default.isExecutableFile(atPath: $0.path) }) == true else { return nil }
        let name = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? url.deletingPathExtension().lastPathComponent
        guard !name.isEmpty else { return nil }
        let bundleID = bundle.bundleIdentifier
        let stable = bundleID?.isEmpty == false ? "app:\(bundleID!)" : "app-path:\(url.standardizedFileURL.path)"
        let executableName = executable?.lastPathComponent
        let aliases = [url.deletingPathExtension().lastPathComponent, executableName].compactMap { $0 }
        return ApplicationRecord(id: stable, name: name, bundleIdentifier: bundleID, url: url, aliases: aliases)
    }
}
