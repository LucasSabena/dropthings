import Foundation

public enum TranscriptionProtocol {
    public static let currentVersion = 1
}

public enum TranscriptionLanguage: String, Codable, CaseIterable, Sendable {
    case automatic
    case spanish = "es"
    case english = "en"

    public var displayName: String {
        switch self {
        case .automatic: "Automatic"
        case .spanish: "Spanish"
        case .english: "English"
        }
    }

    public var whisperArgument: String? {
        self == .automatic ? nil : rawValue
    }
}

public enum TranscriptionMode: String, Codable, CaseIterable, Sendable {
    case transcribe
    case translateToEnglish
}

public struct TranscriptionRequest: Codable, Equatable, Sendable {
    public let protocolVersion: Int
    public let jobID: UUID
    public let inputURL: URL
    public let modelURL: URL
    public let language: TranscriptionLanguage
    public let mode: TranscriptionMode
    public let initialPrompt: String?

    public init(
        protocolVersion: Int = TranscriptionProtocol.currentVersion,
        jobID: UUID = UUID(),
        inputURL: URL,
        modelURL: URL,
        language: TranscriptionLanguage = .automatic,
        mode: TranscriptionMode = .transcribe,
        initialPrompt: String? = nil
    ) {
        self.protocolVersion = protocolVersion
        self.jobID = jobID
        self.inputURL = inputURL
        self.modelURL = modelURL
        self.language = language
        self.mode = mode
        let trimmed = initialPrompt?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.initialPrompt = trimmed?.isEmpty == false ? trimmed : nil
    }
}

public struct TranscriptSegment: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let startMilliseconds: Int64
    public let endMilliseconds: Int64
    public var text: String

    public init(
        id: UUID = UUID(),
        startMilliseconds: Int64,
        endMilliseconds: Int64,
        text: String
    ) {
        self.id = id
        self.startMilliseconds = startMilliseconds
        self.endMilliseconds = endMilliseconds
        self.text = text
    }
}

public struct TranscriptDocument: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public let schemaVersion: Int
    public let jobID: UUID
    public let sourceFileName: String
    public let language: String?
    public let durationMilliseconds: Int64
    public let segments: [TranscriptSegment]

    public init(
        schemaVersion: Int = currentSchemaVersion,
        jobID: UUID,
        sourceFileName: String,
        language: String?,
        durationMilliseconds: Int64,
        segments: [TranscriptSegment]
    ) throws {
        guard schemaVersion == Self.currentSchemaVersion else {
            throw TranscriptionContractError.unsupportedSchema(schemaVersion)
        }
        guard durationMilliseconds >= 0 else {
            throw TranscriptionContractError.invalidDuration
        }
        var previousEnd: Int64 = 0
        for segment in segments {
            guard segment.startMilliseconds >= 0,
                  segment.endMilliseconds >= segment.startMilliseconds,
                  segment.startMilliseconds >= previousEnd else {
                throw TranscriptionContractError.invalidSegmentTiming
            }
            previousEnd = segment.endMilliseconds
        }
        self.schemaVersion = schemaVersion
        self.jobID = jobID
        self.sourceFileName = sourceFileName
        self.language = language
        self.durationMilliseconds = durationMilliseconds
        self.segments = segments
    }

    public var plainText: String {
        segments.map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, jobID, sourceFileName, language, durationMilliseconds, segments
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            schemaVersion: container.decode(Int.self, forKey: .schemaVersion),
            jobID: container.decode(UUID.self, forKey: .jobID),
            sourceFileName: container.decode(String.self, forKey: .sourceFileName),
            language: container.decodeIfPresent(String.self, forKey: .language),
            durationMilliseconds: container.decode(Int64.self, forKey: .durationMilliseconds),
            segments: container.decode([TranscriptSegment].self, forKey: .segments)
        )
    }
}

public enum TranscriptionContractError: Error, Equatable, LocalizedError {
    case unsupportedProtocol(Int)
    case unsupportedSchema(Int)
    case invalidDuration
    case invalidSegmentTiming

    public var errorDescription: String? {
        switch self {
        case .unsupportedProtocol(let version): "Unsupported transcription protocol version \(version)."
        case .unsupportedSchema(let version): "Unsupported transcript schema version \(version)."
        case .invalidDuration: "The transcript duration is invalid."
        case .invalidSegmentTiming: "Transcript segments overlap or contain invalid timestamps."
        }
    }
}
