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
                try data(for: document, format: format).write(to: destination, options: [.atomic, .withoutOverwriting])
                written.append(destination)
            }
            return written
        } catch {
            written.forEach { try? fileManager.removeItem(at: $0) }
            throw error
        }
    }

    static func sanitizedBaseName(_ input: String) -> String {
        let forbidden = CharacterSet(charactersIn: "/:\0").union(.newlines)
        let components = input.components(separatedBy: forbidden).filter { !$0.isEmpty }
        let candidate = components.joined(separator: "-").trimmingCharacters(in: .whitespacesAndNewlines)
        return candidate.isEmpty ? "Transcript" : candidate
    }
}
