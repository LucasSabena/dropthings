import Foundation
import XCTest
@testable import DropThingsTranscriptionKit

final class TranscriptionEngineProtocolTests: XCTestCase {
    func testTypedFailureRoundTripsAcrossXPCWireCodec() throws {
        let original = TranscriptionEngineFailure(kind: .cancelled, message: "cancelled")

        let data = try TranscriptionEngineCodec.encode(original)
        let decoded = try TranscriptionEngineCodec.decode(TranscriptionEngineFailure.self, from: data)

        XCTAssertEqual(decoded, original)
    }

    func testPCMDecoderNormalizesSigned16BitSamples() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("wav")
        defer { try? FileManager.default.removeItem(at: url) }
        try makeWAV(samples: [Int16.min, 0, Int16.max]).write(to: url)

        let samples = try WAVPCMDecoder.decodeMonoPCM16(url: url)

        XCTAssertEqual(samples[0], -1, accuracy: 0.000_01)
        XCTAssertEqual(samples[1], 0, accuracy: 0.000_01)
        XCTAssertEqual(samples[2], Float(Int16.max) / 32_768, accuracy: 0.000_01)
    }

    private func makeWAV(samples: [Int16]) -> Data {
        let pcm = samples.reduce(into: Data()) { data, sample in
            append(UInt16(bitPattern: sample), to: &data)
        }
        var result = Data("RIFF".utf8)
        append(UInt32(36 + pcm.count), to: &result)
        result.append(Data("WAVEfmt ".utf8))
        append(UInt32(16), to: &result)
        append(UInt16(1), to: &result)
        append(UInt16(1), to: &result)
        append(UInt32(16_000), to: &result)
        append(UInt32(32_000), to: &result)
        append(UInt16(2), to: &result)
        append(UInt16(16), to: &result)
        result.append(Data("data".utf8))
        append(UInt32(pcm.count), to: &result)
        result.append(pcm)
        return result
    }

    private func append<T: FixedWidthInteger>(_ value: T, to data: inout Data) {
        var littleEndian = value.littleEndian
        withUnsafeBytes(of: &littleEndian) { data.append(contentsOf: $0) }
    }
}
