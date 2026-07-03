import Foundation

/// On-disk store for shelf collections. Non-sandboxed apps can persist
/// file URLs directly (no security-scoped bookmark dance). The file lives
/// in `~/Library/Application Support/app.dropthings/file-shelf.json` so it
/// is easy to find, copy, or wipe.
///
/// Backward compatibility: the v1 layout stored a flat `{ "items": [...] }`
/// of pinned items. On load, if the new `collections` array is absent but
/// a legacy `items` array is present, those items are migrated into a
/// single default collection named "Shelf" so no pinned data is lost.
final class ShelfPersistence {
    static let shared = ShelfPersistence()

    private let fileURL: URL
    private let legacyFileURL: URL

    /// Production init: resolves the standard app-support directory.
    convenience init(fileManager: FileManager = .default) {
        self.init(directory: ShelfPersistence.defaultDirectory(fileManager: fileManager), fileManager: fileManager)
    }

    /// Test/init override: write into an explicit directory so the store
    /// can be exercised in isolation without touching real app support.
    init(directory: URL, fileManager: FileManager = .default) {
        if !fileManager.fileExists(atPath: directory.path) {
            try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        self.fileURL = directory.appendingPathComponent("file-shelf.json")
        // Pre-collections path. Read during migration, never written again.
        self.legacyFileURL = directory.appendingPathComponent("file-shelf-pinned.json")
    }

    private static func defaultDirectory(fileManager: FileManager) -> URL {
        let baseURL = (try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return baseURL.appendingPathComponent("app.dropthings", isDirectory: true)
    }

    /// Reveal the on-disk path. Tests and the Settings diagnostics screen
    /// use it to show the user where data lives.
    var storageURL: URL { fileURL }

    func loadCollections() -> [ShelfCollection] {
        // New layout first.
        if let data = try? Data(contentsOf: fileURL),
           let container = try? JSONDecoder().decode(CollectionsContainer.self, from: data) {
            return container.collections
        }
        // Migrate the legacy flat-items layout into a single default
        // collection. This runs once for existing installs and never again
        // once the new file is written.
        if let migrated = migrateLegacy() {
            return migrated
        }
        return []
    }

    func saveCollections(_ collections: [ShelfCollection]) throws {
        let container = CollectionsContainer(collections: collections)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(container)
        try data.write(to: fileURL, options: .atomic)
    }

    /// Read the v1 `file-shelf-pinned.json` (a flat `{ "items": [...] }`)
    /// and fold its pinned items into a single default collection. Returns
    /// `nil` when there is nothing to migrate.
    private func migrateLegacy() -> [ShelfCollection]? {
        guard let data = try? Data(contentsOf: legacyFileURL),
              let legacy = try? JSONDecoder().decode(LegacyContainer.self, from: data),
              !legacy.items.isEmpty else {
            return nil
        }
        return [ShelfCollection(name: ShelfCollection.defaultName, items: legacy.items)]
    }

    private struct CollectionsContainer: Codable {
        let collections: [ShelfCollection]
    }

    private struct LegacyContainer: Codable {
        let items: [FileShelfItem]
    }
}
