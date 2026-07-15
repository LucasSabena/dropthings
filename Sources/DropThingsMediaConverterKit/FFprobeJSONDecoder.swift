import Foundation

/// Decodes the small JSON contract emitted by the bundled `ffprobe` binary.
/// Kept in the pure kit so classification can be tested without launching XPC.
public enum FFprobeJSONDecoder {
    public static func decode(_ data: Data, sourceURL: URL) throws -> MediaProbeResult {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw MediaConverterError.probeFailed(reason: "Could not read media information.")
        }

        let streams = root["streams"] as? [[String: Any]] ?? []
        let format = root["format"] as? [String: Any]
        let video = streams.first { $0["codec_type"] as? String == "video" }
        let audio = streams.first { $0["codec_type"] as? String == "audio" }
        guard video != nil || audio != nil else {
            throw MediaConverterError.probeFailed(reason: "No audio or video stream was found.")
        }

        let dimensions: MediaDimensions? = video.flatMap {
            let value = MediaDimensions(width: integer($0["width"]), height: integer($0["height"]))
            return value.isNonEmpty ? value : nil
        }
        let pixelFormat = video?["pix_fmt"] as? String

        return MediaProbeResult(
            url: sourceURL,
            kind: video == nil ? .audio : .video,
            formatHint: nil,
            fileSize: int64(format?["size"]),
            dimensions: dimensions,
            durationSeconds: double(format?["duration"]),
            frameRate: rational(video?["avg_frame_rate"]),
            sampleRate: double(audio?["sample_rate"]),
            channelCount: audio.map { integer($0["channels"]) },
            hasAlpha: pixelFormat.map { $0.contains("rgba") || $0.contains("yuva") || $0.contains("ya") }
        )
    }

    private static func integer(_ value: Any?) -> Int {
        if let value = value as? Int { return value }
        if let value = value as? NSNumber { return value.intValue }
        if let value = value as? String { return Int(value) ?? 0 }
        return 0
    }

    private static func int64(_ value: Any?) -> Int64 {
        if let value = value as? Int64 { return value }
        if let value = value as? NSNumber { return value.int64Value }
        if let value = value as? String { return Int64(value) ?? 0 }
        return 0
    }

    private static func double(_ value: Any?) -> Double? {
        if let value = value as? Double { return value }
        if let value = value as? NSNumber { return value.doubleValue }
        if let value = value as? String { return Double(value) }
        return nil
    }

    private static func rational(_ value: Any?) -> Double? {
        guard let string = value as? String else { return double(value) }
        let parts = string.split(separator: "/", maxSplits: 1).compactMap { Double($0) }
        guard parts.count == 2, parts[1] != 0 else { return Double(string) }
        return parts[0] / parts[1]
    }
}
