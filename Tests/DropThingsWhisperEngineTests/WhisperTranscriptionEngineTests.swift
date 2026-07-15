import Foundation
import XCTest
import DropThingsTranscriptionKit
@testable import DropThingsWhisperEngine

final class WhisperTranscriptionEngineTests: XCTestCase {
    func testCancellationRegisteredBeforeQueuedWorkStarts() {
        let engine = WhisperTranscriptionEngine()
        let request = TranscriptionRequest(
            inputURL: URL(fileURLWithPath: "/missing/audio.wav"),
            modelURL: URL(fileURLWithPath: "/missing/model.bin")
        )
        engine.prepare(jobID: request.jobID)
        engine.cancel(jobID: request.jobID)

        XCTAssertThrowsError(try engine.transcribe(request)) { error in
            XCTAssertEqual(error as? TranscriptionClientError, .cancelled)
        }
    }

    func testRealFixtureWhenExplicitlyProvided() throws {
        let environment = ProcessInfo.processInfo.environment
        guard let audioPath = environment["DROPTHINGS_WHISPER_TEST_AUDIO"],
              let modelPath = environment["DROPTHINGS_WHISPER_TEST_MODEL"] else {
            throw XCTSkip("Set DROPTHINGS_WHISPER_TEST_AUDIO and DROPTHINGS_WHISPER_TEST_MODEL for the real engine test.")
        }
        let engine = WhisperTranscriptionEngine()
        let request = TranscriptionRequest(
            inputURL: URL(fileURLWithPath: audioPath),
            modelURL: URL(fileURLWithPath: modelPath),
            language: .english
        )

        let document = try engine.transcribe(request)

        XCTAssertFalse(document.segments.isEmpty)
        XCTAssertGreaterThan(document.durationMilliseconds, 0)
        XCTAssertTrue(document.plainText.localizedCaseInsensitiveContains("ask"))
    }
}
