import Foundation
import XCTest
@testable import DropThingsTranscriptionKit

final class TranscriptExporterTests: XCTestCase {
    func testTextAndVersionedJSONExports() throws {
        let document = try fixture()
        XCTAssertEqual(String(decoding: try TranscriptExporter.data(for: document, format: .text), as: UTF8.self), "Hello\nworld")

        let decoded = try JSONDecoder().decode(
            TranscriptDocument.self,
            from: TranscriptExporter.data(for: document, format: .json)
        )
        XCTAssertEqual(decoded, document)
        XCTAssertEqual(decoded.schemaVersion, TranscriptDocument.currentSchemaVersion)
    }

    func testRejectsOverlappingSegments() {
        XCTAssertThrowsError(try TranscriptDocument(
            jobID: UUID(),
            sourceFileName: "audio.wav",
            language: "en",
            durationMilliseconds: 2_000,
            segments: [
                .init(startMilliseconds: 0, endMilliseconds: 1_200, text: "one"),
                .init(startMilliseconds: 1_000, endMilliseconds: 2_000, text: "two")
            ]
        )) {
            XCTAssertEqual($0 as? TranscriptionContractError, .invalidSegmentTiming)
        }
    }

    func testDecoderRejectsUnknownFutureSchema() throws {
        let data = try TranscriptExporter.data(for: fixture(), format: .json)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object["schemaVersion"] = TranscriptDocument.currentSchemaVersion + 1
        let futureData = try JSONSerialization.data(withJSONObject: object)

        XCTAssertThrowsError(try JSONDecoder().decode(TranscriptDocument.self, from: futureData)) {
            XCTAssertEqual($0 as? TranscriptionContractError, .unsupportedSchema(2))
        }
    }

    func testOutputConflictDoesNotOverwrite() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let existing = directory.appendingPathComponent("Audio Transcript.txt")
        try Data("keep".utf8).write(to: existing)

        XCTAssertThrowsError(try TranscriptExporter.write(
            fixture(), formats: [.text, .json], directory: directory, baseName: "Audio Transcript"
        ))
        XCTAssertEqual(try String(contentsOf: existing, encoding: .utf8), "keep")
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent("Audio Transcript.json").path))
    }

    private func fixture() throws -> TranscriptDocument {
        try TranscriptDocument(
            jobID: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            sourceFileName: "audio.wav",
            language: "en",
            durationMilliseconds: 2_000,
            segments: [
                .init(startMilliseconds: 0, endMilliseconds: 1_000, text: " Hello "),
                .init(startMilliseconds: 1_000, endMilliseconds: 2_000, text: "world")
            ]
        )
    }
}
