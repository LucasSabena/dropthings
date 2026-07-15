import Foundation
import XCTest
@testable import DropThingsTranscriptionKit

final class WAVInspectorTests: XCTestCase {
    func testAcceptsWhisperReadyPCMAndMeasuresDuration() throws {
        let url = temporaryURL()
        try makeWAV(sampleRate: 16_000, channels: 1, bits: 16, sampleCount: 16_000).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let facts = try WAVInspector.inspect(url: url)

        XCTAssertTrue(facts.isWhisperReadyPCM)
        XCTAssertEqual(facts.durationMilliseconds, 1_000)
    }

    func testRejectsStereoPCM() throws {
        let url = temporaryURL()
        try makeWAV(sampleRate: 16_000, channels: 2, bits: 16, sampleCount: 16_000).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertThrowsError(try WAVInspector.inspect(url: url)) {
            XCTAssertEqual($0 as? WAVInspectionError, .unsupportedFormat)
        }
    }

    func testRejectsTruncatedContainer() throws {
        let url = temporaryURL()
        try Data("RIFF".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertThrowsError(try WAVInspector.inspect(url: url)) {
            XCTAssertEqual($0 as? WAVInspectionError, .invalidContainer)
        }
    }

    private func temporaryURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("wav")
    }

    private func makeWAV(sampleRate: UInt32, channels: UInt16, bits: UInt16, sampleCount: Int) -> Data {
        let dataSize = UInt32(sampleCount) * UInt32(channels) * UInt32(bits / 8)
        var data = Data()
        data.appendASCII("RIFF")
        data.appendLE(UInt32(36) + dataSize)
        data.appendASCII("WAVEfmt ")
        data.appendLE(UInt32(16))
        data.appendLE(UInt16(1))
        data.appendLE(channels)
        data.appendLE(sampleRate)
        data.appendLE(sampleRate * UInt32(channels) * UInt32(bits / 8))
        data.appendLE(channels * (bits / 8))
        data.appendLE(bits)
        data.appendASCII("data")
        data.appendLE(dataSize)
        data.append(Data(repeating: 0, count: Int(dataSize)))
        return data
    }
}

private extension Data {
    mutating func appendASCII(_ value: String) { append(contentsOf: value.utf8) }
    mutating func appendLE(_ value: UInt16) {
        append(UInt8(value & 0xff)); append(UInt8((value >> 8) & 0xff))
    }
    mutating func appendLE(_ value: UInt32) {
        append(UInt8(value & 0xff)); append(UInt8((value >> 8) & 0xff))
        append(UInt8((value >> 16) & 0xff)); append(UInt8((value >> 24) & 0xff))
    }
}
