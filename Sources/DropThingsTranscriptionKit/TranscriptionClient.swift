import Foundation

public enum TranscriptionPhase: String, Codable, CaseIterable, Sendable {
    case inspect
    case normalize
    case modelLoad
    case transcribe
    case finalize
}

public struct TranscriptionProgress: Equatable, Sendable {
    public let phase: TranscriptionPhase
    public let fraction: Double?

    public init(phase: TranscriptionPhase, fraction: Double? = nil) {
        self.phase = phase
        self.fraction = fraction.map { min(max($0, 0), 1) }
    }
}

public protocol LocalTranscriptionClient: Sendable {
    func availability() async -> TranscriptionClientAvailability
    func transcribe(
        _ request: TranscriptionRequest,
        progress: @escaping @Sendable (TranscriptionProgress) -> Void
    ) async throws -> TranscriptDocument
    func cancel(jobID: UUID) async
}

public enum TranscriptionClientAvailability: Equatable, Sendable {
    case available(version: String)
    case unavailable(reason: String)
}

public enum TranscriptionClientError: Error, Equatable, LocalizedError {
    case unavailable(String)
    case invalidRequest(String)
    case helperFailed(String)
    case malformedResult(String)
    case cancelled

    public var errorDescription: String? {
        switch self {
        case .unavailable(let reason): reason
        case .invalidRequest(let reason): reason
        case .helperFailed(let reason): "Local transcription failed: \(reason)"
        case .malformedResult(let reason): "The local engine returned an invalid result: \(reason)"
        case .cancelled: "Transcription was cancelled."
        }
    }
}
