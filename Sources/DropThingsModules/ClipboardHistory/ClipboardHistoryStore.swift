import Foundation
import ImageIO
import UniformTypeIdentifiers

public struct ClipboardHistoryPersistenceResult: Sendable, Equatable {
    public let storedItemCount: Int
    public let omittedImageCount: Int
    public let storageBytes: Int64

    public init(storedItemCount: Int, omittedImageCount: Int, storageBytes: Int64) {
        self.storedItemCount = storedItemCount
        self.omittedImageCount = omittedImageCount
        self.storageBytes = storageBytes
    }
}

public protocol ClipboardHistoryPersisting: Sendable {
    func load() async throws -> [ClipboardItem]
    func save(_ items: [ClipboardItem], maxStorageBytes: Int64) async throws -> ClipboardHistoryPersistenceResult
    func storageBytes() async -> Int64
}

/// Clipboard-specific persistence. Metadata lives in one atomic JSON index and
/// raw clipboard images are normalized to PNG assets. Keeping this outside
/// UserDefaults makes normal app updates cheap and preserves history when the
/// `.app` bundle is replaced.
public actor ClipboardHistoryStore: ClipboardHistoryPersisting {
    private struct Archive: Codable {
        var schemaVersion: Int
        var items: [Record]
    }

    private struct Record: Codable {
        let id: UUID
        let timestamp: Date
        let type: ClipboardItemType
        let content: String
        let imageFilename: String?
        let sourceBundleID: String?
        let isPinned: Bool
        let isFavorite: Bool

        init(item: ClipboardItem, imageFilename: String?) {
            id = item.id
            timestamp = item.timestamp
            type = item.type
            content = item.content
            self.imageFilename = imageFilename
            sourceBundleID = item.sourceBundleID
            isPinned = item.isPinned
            isFavorite = item.isFavorite
        }
    }

    private static let schemaVersion = 1
    private let fileManager: FileManager
    private let directoryURL: URL
    private var indexURL: URL { directoryURL.appendingPathComponent("history.json") }
    private var assetsURL: URL { directoryURL.appendingPathComponent("Assets", isDirectory: true) }

    public init(directoryURL: URL, fileManager: FileManager = .default) {
        self.directoryURL = directoryURL
        self.fileManager = fileManager
    }

    public static func live(fileManager: FileManager = .default) -> ClipboardHistoryStore {
        let root = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return ClipboardHistoryStore(
            directoryURL: root
                .appendingPathComponent("app.dropthings", isDirectory: true)
                .appendingPathComponent("ClipboardHistory", isDirectory: true),
            fileManager: fileManager
        )
    }

    public func load() throws -> [ClipboardItem] {
        guard fileManager.fileExists(atPath: indexURL.path) else { return [] }
        let data = try Data(contentsOf: indexURL, options: .mappedIfSafe)
        let archive = try JSONDecoder().decode(Archive.self, from: data)
        guard archive.schemaVersion <= Self.schemaVersion else { return [] }

        return archive.items.compactMap { record in
            var imageData: Data?
            if let filename = record.imageFilename {
                imageData = try? Data(
                    contentsOf: assetsURL.appendingPathComponent(filename),
                    options: .mappedIfSafe
                )
                guard imageData != nil else { return nil }
            }
            return ClipboardItem(
                id: record.id,
                timestamp: record.timestamp,
                type: record.type,
                content: record.content,
                imageData: imageData,
                sourceBundleID: record.sourceBundleID,
                isPinned: record.isPinned,
                isFavorite: record.isFavorite
            )
        }
    }

    public func save(
        _ items: [ClipboardItem],
        maxStorageBytes: Int64
    ) throws -> ClipboardHistoryPersistenceResult {
        try ensureDirectories()

        let rawImages = items
            .filter { $0.type == .image && $0.fileURL == nil && $0.imageData != nil }
            .sorted(by: Self.persistencePriority)
        var selectedImages: [UUID: Data] = [:]
        var imageBytes: Int64 = 0

        for item in rawImages {
            guard let source = item.imageData,
                  let png = Self.normalizedPNG(source) else { continue }
            let candidateSize = Int64(png.count)
            guard candidateSize <= maxStorageBytes - imageBytes else { continue }
            selectedImages[item.id] = png
            imageBytes += candidateSize
        }

        var records: [Record] = []
        var referencedAssets = Set<String>()
        var omittedImages = 0
        for item in items {
            if item.type == .image, item.fileURL == nil {
                guard let png = selectedImages[item.id] else {
                    omittedImages += 1
                    continue
                }
                let filename = "\(item.id.uuidString).png"
                try writeIfChanged(png, to: assetsURL.appendingPathComponent(filename))
                referencedAssets.insert(filename)
                records.append(Record(item: item, imageFilename: filename))
            } else {
                records.append(Record(item: item, imageFilename: nil))
            }
        }

        try removeOrphanedAssets(keeping: referencedAssets)
        let archive = Archive(schemaVersion: Self.schemaVersion, items: records)
        let encoded = try JSONEncoder().encode(archive)
        try encoded.write(to: indexURL, options: .atomic)

        return ClipboardHistoryPersistenceResult(
            storedItemCount: records.count,
            omittedImageCount: omittedImages,
            storageBytes: directoryByteCount()
        )
    }

    public func storageBytes() -> Int64 {
        directoryByteCount()
    }

    private func ensureDirectories() throws {
        try fileManager.createDirectory(at: assetsURL, withIntermediateDirectories: true)
    }

    private func writeIfChanged(_ data: Data, to url: URL) throws {
        if let existing = try? Data(contentsOf: url, options: .mappedIfSafe), existing == data {
            return
        }
        try data.write(to: url, options: .atomic)
    }

    private func removeOrphanedAssets(keeping filenames: Set<String>) throws {
        let contents = try fileManager.contentsOfDirectory(
            at: assetsURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        for url in contents where !filenames.contains(url.lastPathComponent) {
            try fileManager.removeItem(at: url)
        }
    }

    private func directoryByteCount() -> Int64 {
        guard let enumerator = fileManager.enumerator(
            at: directoryURL,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }

        var total: Int64 = 0
        for case let url as URL in enumerator {
            total += Int64((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        }
        return total
    }

    private static func normalizedPNG(_ data: Data) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            output,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else { return nil }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }

    private static func persistencePriority(_ lhs: ClipboardItem, _ rhs: ClipboardItem) -> Bool {
        if lhs.isFavorite != rhs.isFavorite { return lhs.isFavorite }
        if lhs.isPinned != rhs.isPinned { return lhs.isPinned }
        return lhs.timestamp > rhs.timestamp
    }
}
