import Foundation
import DropThingsTranscriptionKit

public struct TranscriptionQueueItem: Identifiable, Equatable, Sendable {
    public enum Status: Equatable, Sendable {
        case waiting
        case active(TranscriptionProgress)
        case completed(outputURLs: [URL])
        case failed(message: String)
        case cancelled
    }

    public let id: UUID
    public let sourceURL: URL
    public var status: Status

    public init(id: UUID = UUID(), sourceURL: URL, status: Status = .waiting) {
        self.id = id
        self.sourceURL = sourceURL
        self.status = status
    }
}
