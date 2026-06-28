import Foundation

/// On-disk store for pinned shelf items. Non-sandboxed apps can persist
/// file URLs directly (no security-scoped bookmark dance). The file lives
/// in `~/Library/Application Support/app.dropthings/file-shelf-pinned.json`
/// so it is easy to find, copy, or wipe.
final class ShelfPersistence {
    static let shared = ShelfPersistence()

    private let fileURL: URL

    init(fileManager: FileManager = .default) {
        let baseURL = (try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        let dir = baseURL.appendingPathComponent("app.dropthings", isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        self.fileURL = dir.appendingPathComponent("file-shelf-pinned.json")
    }

    /// Reveal the on-disk path. Tests and the Settings diagnostics screen
    /// use it to show the user where data lives.
    var storageURL: URL { fileURL }

    func loadPinnedItems() -> [FileShelfItem] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        guard let container = try? JSONDecoder().decode(Container.self, from: data) else {
            return []
        }
        return container.items
    }

    func savePinnedItems(_ items: [FileShelfItem]) throws {
        let container = Container(items: items.filter(\.isPinned))
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(container)
        try data.write(to: fileURL, options: .atomic)
    }

    private struct Container: Codable {
        let items: [FileShelfItem]
    }
}
