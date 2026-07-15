import CryptoKit
import Foundation
import DropThingsTranscriptionKit

public enum TranscriptionModelError: Error, Equatable, LocalizedError {
    case invalidFileSize(expected: Int64, actual: Int64)
    case checksumMismatch
    case modelInUse
    case missingModel
    case downloadFailed

    public var errorDescription: String? {
        switch self {
        case .invalidFileSize: "The model download has an unexpected size."
        case .checksumMismatch: "The model checksum did not match the pinned manifest."
        case .modelInUse: "This model is currently in use by a transcription."
        case .missingModel: "The selected model is not installed."
        case .downloadFailed: "The model download could not be completed."
        }
    }
}

public actor TranscriptionModelManager {
    public let modelsDirectory: URL
    private let fileManager: FileManager
    private let session: URLSession
    private var leasedModels: Set<TranscriptionModelID> = []

    public init(
        modelsDirectory: URL? = nil,
        fileManager: FileManager = .default,
        session: URLSession = .shared
    ) {
        self.fileManager = fileManager
        self.session = session
        if let modelsDirectory {
            self.modelsDirectory = modelsDirectory
        } else {
            let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            self.modelsDirectory = support
                .appendingPathComponent("DropThings", isDirectory: true)
                .appendingPathComponent("Transcription", isDirectory: true)
                .appendingPathComponent("Models", isDirectory: true)
        }
    }

    public func installedModelIDs() -> Set<TranscriptionModelID> {
        Set(CuratedTranscriptionModels.all.compactMap { descriptor in
            let url = modelsDirectory.appendingPathComponent(descriptor.fileName)
            guard fileManager.fileExists(atPath: url.path),
                  (try? verify(url, against: descriptor)) != nil else {
                return nil
            }
            return descriptor.id
        })
    }

    public func download(_ id: TranscriptionModelID) async throws {
        let descriptor = CuratedTranscriptionModels.descriptor(for: id)
        try fileManager.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)
        let partial = modelsDirectory.appendingPathComponent(".\(descriptor.fileName).partial")
        try? fileManager.removeItem(at: partial)
        do {
            let (temporary, response) = try await session.download(from: descriptor.downloadURL)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                throw TranscriptionModelError.downloadFailed
            }
            try fileManager.moveItem(at: temporary, to: partial)
            try verify(partial, against: descriptor)
            let destination = modelsDirectory.appendingPathComponent(descriptor.fileName)
            if fileManager.fileExists(atPath: destination.path) {
                _ = try fileManager.replaceItemAt(destination, withItemAt: partial)
            } else {
                try fileManager.moveItem(at: partial, to: destination)
            }
        } catch {
            try? fileManager.removeItem(at: partial)
            throw error
        }
    }

    public func importModel(from source: URL, as id: TranscriptionModelID) throws {
        let descriptor = CuratedTranscriptionModels.descriptor(for: id)
        try fileManager.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)
        let partial = modelsDirectory.appendingPathComponent(".\(descriptor.fileName).partial")
        try? fileManager.removeItem(at: partial)
        do {
            try fileManager.copyItem(at: source, to: partial)
            try verify(partial, against: descriptor)
            let destination = modelsDirectory.appendingPathComponent(descriptor.fileName)
            if fileManager.fileExists(atPath: destination.path) {
                _ = try fileManager.replaceItemAt(destination, withItemAt: partial)
            } else {
                try fileManager.moveItem(at: partial, to: destination)
            }
        } catch {
            try? fileManager.removeItem(at: partial)
            throw error
        }
    }

    public func delete(_ id: TranscriptionModelID) throws {
        guard !leasedModels.contains(id) else { throw TranscriptionModelError.modelInUse }
        let descriptor = CuratedTranscriptionModels.descriptor(for: id)
        let url = modelsDirectory.appendingPathComponent(descriptor.fileName)
        guard fileManager.fileExists(atPath: url.path) else { return }
        try fileManager.removeItem(at: url)
    }

    public func acquire(_ id: TranscriptionModelID) throws -> URL {
        let descriptor = CuratedTranscriptionModels.descriptor(for: id)
        let url = modelsDirectory.appendingPathComponent(descriptor.fileName)
        guard fileManager.fileExists(atPath: url.path) else { throw TranscriptionModelError.missingModel }
        try verify(url, against: descriptor)
        leasedModels.insert(id)
        return url
    }

    public func release(_ id: TranscriptionModelID) {
        leasedModels.remove(id)
    }

    private func verify(_ url: URL, against descriptor: TranscriptionModelDescriptor) throws {
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        let size = (attributes[.size] as? NSNumber)?.int64Value ?? -1
        guard size == descriptor.byteCount else {
            throw TranscriptionModelError.invalidFileSize(expected: descriptor.byteCount, actual: size)
        }
        guard try sha256(of: url) == descriptor.sha256 else {
            throw TranscriptionModelError.checksumMismatch
        }
    }

    private func sha256(of url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var digest = SHA256()
        while let chunk = try handle.read(upToCount: 1_048_576), !chunk.isEmpty {
            digest.update(data: chunk)
        }
        return digest.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
