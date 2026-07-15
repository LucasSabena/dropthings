import Foundation

public enum TranscriptionModelID: String, Codable, CaseIterable, Sendable {
    case tiny
    case base
    case small
}

public struct TranscriptionModelDescriptor: Codable, Equatable, Identifiable, Sendable {
    public let id: TranscriptionModelID
    public let displayName: String
    public let downloadURL: URL
    public let byteCount: Int64
    public let sha256: String
    public let memoryGuidance: String

    public init(
        id: TranscriptionModelID,
        displayName: String,
        downloadURL: URL,
        byteCount: Int64,
        sha256: String,
        memoryGuidance: String
    ) {
        self.id = id
        self.displayName = displayName
        self.downloadURL = downloadURL
        self.byteCount = byteCount
        self.sha256 = sha256
        self.memoryGuidance = memoryGuidance
    }

    public var fileName: String { "ggml-\(id.rawValue).bin" }
}

public enum CuratedTranscriptionModels {
    /// Multilingual GGML models published by the whisper.cpp project. Digests
    /// are the SHA-256 LFS object identifiers observed in the pinned manifest.
    public static let all: [TranscriptionModelDescriptor] = [
        .init(
            id: .tiny,
            displayName: "Tiny",
            downloadURL: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.bin")!,
            byteCount: 77_691_713,
            sha256: "be07e048e1e599ad46341c8d2a135645097a538221678b7acdd1b1919c6e1b21",
            memoryGuidance: "About 78 MB on disk. Fastest, with the lowest accuracy."
        ),
        .init(
            id: .base,
            displayName: "Base",
            downloadURL: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin")!,
            byteCount: 147_951_465,
            sha256: "60ed5bc3dd14eea856493d334349b405782ddcaf0028d4b5df4088345fba2efe",
            memoryGuidance: "About 148 MB on disk. Balanced speed and accuracy."
        ),
        .init(
            id: .small,
            displayName: "Small",
            downloadURL: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.bin")!,
            byteCount: 487_601_967,
            sha256: "1be3a9b2063867b937e64e2ec7483364a79917e157fa98c5d94b5c1fffea987b",
            memoryGuidance: "About 488 MB on disk. Better accuracy, with higher memory use."
        )
    ]

    public static func descriptor(for id: TranscriptionModelID) -> TranscriptionModelDescriptor {
        all.first { $0.id == id }!
    }
}
