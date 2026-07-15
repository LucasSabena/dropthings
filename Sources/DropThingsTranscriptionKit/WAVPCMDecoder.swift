import Foundation

public enum WAVPCMDecoder {
    public static func decodeMonoPCM16(url: URL) throws -> [Float] {
        _ = try WAVInspector.inspect(url: url)
        let bytes: Data
        do {
            bytes = try Data(contentsOf: url, options: [.mappedIfSafe])
        } catch {
            throw WAVInspectionError.unreadable
        }

        var offset = 12
        while offset + 8 <= bytes.count {
            let id = String(data: bytes[offset..<(offset + 4)], encoding: .ascii) ?? ""
            let size = Int(littleEndianUInt32(bytes, at: offset + 4))
            let payload = offset + 8
            guard size >= 0, payload <= bytes.count, size <= bytes.count - payload else {
                throw WAVInspectionError.invalidContainer
            }
            if id == "data" {
                guard size.isMultiple(of: 2) else { throw WAVInspectionError.invalidContainer }
                var samples: [Float] = []
                samples.reserveCapacity(size / 2)
                var sampleOffset = payload
                while sampleOffset < payload + size {
                    let raw = UInt16(bytes[sampleOffset]) | UInt16(bytes[sampleOffset + 1]) << 8
                    let signed = Int16(bitPattern: raw)
                    samples.append(Float(signed) / 32_768)
                    sampleOffset += 2
                }
                return samples
            }
            offset = payload + size + (size % 2)
        }
        throw WAVInspectionError.missingAudioData
    }

    private static func littleEndianUInt32(_ data: Data, at offset: Int) -> UInt32 {
        UInt32(data[offset]) |
            UInt32(data[offset + 1]) << 8 |
            UInt32(data[offset + 2]) << 16 |
            UInt32(data[offset + 3]) << 24
    }
}
