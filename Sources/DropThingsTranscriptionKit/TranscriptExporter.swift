import Foundation

public enum TranscriptOutputFormat: String, Codable, CaseIterable, Sendable {
    case text
    case json

    public var fileExtension: String {
        switch self {
        case .text: "txt"
        case .json: "json"
        }
    }
}

public enum TranscriptExportError: Error, LocalizedError {
    case outputExists(URL)
    case encodingFailed

    public var errorDescription: String? {
        switch self {
        case .outputExists(let url): "An output already exists at \(url.lastPathComponent)."
        case .encodingFailed: "The transcript could not be encoded."
        }
    }
}

public enum TranscriptExporter {
    public static func data(for document: TranscriptDocument, format: TranscriptOutputFormat) throws -> Data {
        switch format {
        case .text:
            guard let data = document.plainText.data(using: .utf8) else {
                throw TranscriptExportError.encodingFailed
            }
            return data
        case .json:
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            return try encoder.encode(document)
        }
    }

    public static func write(
        _ document: TranscriptDocument,
        formats: Set<TranscriptOutputFormat>,
        directory: URL,
        baseName: String,
        fileManager: FileManager = .default
    ) throws -> [URL] {
        let safeBaseName = sanitizedBaseName(baseName)
        let destinations = formats.sorted { $0.rawValue < $1.rawValue }.map {
            directory.appendingPathComponent(safeBaseName).appendingPathExtension($0.fileExtension)
        }
        if let existing = destinations.first(where: { fileManager.fileExists(atPath: $0.path) }) {
            throw TranscriptExportError.outputExists(existing)
        }
        var written: [URL] = []
        do {
            for (format, destination) in zip(formats.sorted(by: { $0.rawValue < $1.rawValue }), destinations) {
                // Foundation traps (rather than throwing) when `.atomic` and
                // `.withoutOverwriting` are combined. Reserve the destination
                // with the supported no-overwrite write and roll back the set
                // below if a later format fails.
                try data(for: document, format: format).write(to: destination, options: .withoutOverwriting)
                written.append(destination)
            }
            return written
        } catch {
            written.forEach { try? fileManager.removeItem(at: $0) }
            throw error
        }
    }

    /// Writes without overwriting an earlier transcript. Repeated runs use a
    /// deterministic numeric suffix instead of failing the completed inference.
    public static func writeUnique(
        _ document: TranscriptDocument,
        formats: Set<TranscriptOutputFormat>,
        directory: URL,
        baseName: String,
        fileManager: FileManager = .default
    ) throws -> [URL] {
        for attempt in 1...1_000 {
            let candidate = attempt == 1 ? baseName : "\(baseName) \(attempt)"
            do {
                return try write(
                    document,
                    formats: formats,
                    directory: directory,
                    baseName: candidate,
                    fileManager: fileManager
                )
            } catch TranscriptExportError.outputExists {
                continue
            }
        }
        return try write(
            document,
            formats: formats,
            directory: directory,
            baseName: "\(baseName) \(UUID().uuidString.prefix(8))",
            fileManager: fileManager
        )
    }

    static func sanitizedBaseName(_ input: String) -> String {
        let forbidden = CharacterSet(charactersIn: "/:\0").union(.newlines)
        let components = input.components(separatedBy: forbidden).filter { !$0.isEmpty }
        let candidate = components.joined(separator: "-").trimmingCharacters(in: .whitespacesAndNewlines)
        return candidate.isEmpty ? "Transcript" : candidate
    }
}
