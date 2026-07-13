import CoreGraphics
import Vision

public struct RecognizedText: Sendable, Equatable, Identifiable {
    public let id: UUID
    public let string: String
    public let confidence: Float
    /// Normalized Vision coordinates (origin at lower left).
    public let boundingBox: CGRect
    public init(id: UUID = UUID(), string: String, confidence: Float, boundingBox: CGRect) { self.id = id; self.string = string; self.confidence = confidence; self.boundingBox = boundingBox }
}

public enum OCRRecognitionLevel: Sendable { case fast, accurate }
public protocol OCRService: Sendable { func recognize(in image: CGImage, level: OCRRecognitionLevel, languages: [String]) async throws -> [RecognizedText] }
public protocol QRRecognitionService: Sendable { func recognize(in image: CGImage) async throws -> [String] }

public struct VisionImageRecognitionService: OCRService, QRRecognitionService {
    public init() {}
    public func recognize(in image: CGImage, level: OCRRecognitionLevel, languages: [String]) async throws -> [RecognizedText] {
        try await Task.detached(priority: .userInitiated) {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = level == .fast ? .fast : .accurate
            request.recognitionLanguages = languages
            request.usesLanguageCorrection = true
            let handler = VNImageRequestHandler(cgImage: image)
            try handler.perform([request])
            return (request.results ?? []).compactMap { observation in
                guard let candidate = observation.topCandidates(1).first else { return nil }
                return RecognizedText(string: candidate.string, confidence: candidate.confidence, boundingBox: observation.boundingBox)
            }
        }.value
    }
    public func recognize(in image: CGImage) async throws -> [String] {
        try await Task.detached(priority: .userInitiated) {
            let request = VNDetectBarcodesRequest()
            let handler = VNImageRequestHandler(cgImage: image)
            try handler.perform([request])
            return (request.results ?? []).compactMap(\.payloadStringValue)
        }.value
    }
}
