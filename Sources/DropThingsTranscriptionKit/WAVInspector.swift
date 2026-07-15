import Foundation

public struct WAVFileFacts: Equatable, Sendable {
    public let audioFormat: UInt16
    public let channelCount: UInt16
    public let sampleRate: UInt32
    public let bitsPerSample: UInt16
    public let dataByteCount: UInt32

    public var durationMilliseconds: Int64 {
        guard channelCount > 0, bitsPerSample > 0, sampleRate > 0 else { return 0 }
        let bytesPerSecond = UInt64(sampleRate) * UInt64(channelCount) * UInt64(bitsPerSample / 8)
        guard bytesPerSecond > 0 else { return 0 }
        return Int64(UInt64(dataByteCount) * 1_000 / bytesPerSecond)
    }

    public var isWhisperReadyPCM: Bool {
        audioFormat == 1 && channelCount == 1 && sampleRate == 16_000 && bitsPerSample == 16
    }
}

public enum WAVInspectionError: Error, Equatable, LocalizedError {
    case unreadable
    case invalidContainer
    case missingFormat
    case missingAudioData
    case unsupportedFormat

    public var errorDescription: String? {
        switch self {
        case .unreadable: "The audio file could not be read."
        case .invalidContainer: "The file is not a valid RIFF/WAVE file."
        case .missingFormat: "The WAV file has no format block."
        case .missingAudioData: "The WAV file contains no audio data."
        case .unsupportedFormat: "Phase 1 accepts 16 kHz mono 16-bit PCM WAV files only."
        }
    }
}

public enum WAVInspector {
    public static func inspect(url: URL) throws -> WAVFileFacts {
        guard let handle = try? FileHandle(forReadingFrom: url) else {
            throw WAVInspectionError.unreadable
        }
        defer { try? handle.close() }
        let fileSize = try handle.seekToEnd()
        try handle.seek(toOffset: 0)
        let header = try read(handle, count: 12)
        guard header.count == 12,
              String(data: header[0..<4], encoding: .ascii) == "RIFF",
              String(data: header[8..<12], encoding: .ascii) == "WAVE" else {
            throw WAVInspectionError.invalidContainer
        }

        var format: (UInt16, UInt16, UInt32, UInt16)?
        var dataBytes: UInt32?
        while true {
            let chunkHeader = try read(handle, count: 8)
            if chunkHeader.isEmpty { break }
            guard chunkHeader.count == 8 else { throw WAVInspectionError.invalidContainer }
            let id = String(data: chunkHeader[0..<4], encoding: .ascii) ?? ""
            let size = littleEndianUInt32(chunkHeader, at: 4)
            let paddedSize = UInt64(size) + UInt64(size % 2)
            guard handle.offsetInFile <= fileSize,
                  paddedSize <= fileSize - handle.offsetInFile else {
                throw WAVInspectionError.invalidContainer
            }
            if id == "fmt " {
                guard size >= 16 else { throw WAVInspectionError.invalidContainer }
                let body = try read(handle, count: Int(size))
                guard body.count == size else { throw WAVInspectionError.invalidContainer }
                format = (
                    littleEndianUInt16(body, at: 0),
                    littleEndianUInt16(body, at: 2),
                    littleEndianUInt32(body, at: 4),
                    littleEndianUInt16(body, at: 14)
                )
            } else if id == "data" {
                dataBytes = size
                try handle.seek(toOffset: handle.offsetInFile + UInt64(size))
            } else {
                try handle.seek(toOffset: handle.offsetInFile + UInt64(size))
            }
            if size % 2 == 1 { try handle.seek(toOffset: handle.offsetInFile + 1) }
        }
        guard let format else { throw WAVInspectionError.missingFormat }
        guard let dataBytes, dataBytes > 0 else { throw WAVInspectionError.missingAudioData }
        let facts = WAVFileFacts(
            audioFormat: format.0,
            channelCount: format.1,
            sampleRate: format.2,
            bitsPerSample: format.3,
            dataByteCount: dataBytes
        )
        guard facts.isWhisperReadyPCM else { throw WAVInspectionError.unsupportedFormat }
        return facts
    }

    private static func read(_ handle: FileHandle, count: Int) throws -> Data {
        try handle.read(upToCount: count) ?? Data()
    }

    private static func littleEndianUInt16(_ data: Data, at offset: Int) -> UInt16 {
        UInt16(data[offset]) | UInt16(data[offset + 1]) << 8
    }

    private static func littleEndianUInt32(_ data: Data, at offset: Int) -> UInt32 {
        UInt32(data[offset]) |
            UInt32(data[offset + 1]) << 8 |
            UInt32(data[offset + 2]) << 16 |
            UInt32(data[offset + 3]) << 24
    }
}
