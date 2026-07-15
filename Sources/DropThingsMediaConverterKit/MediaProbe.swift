import Foundation

/// Dimensions of a raster image or video frame, in whole pixels.
public struct MediaDimensions: Hashable, Sendable, Codable {
    public let width: Int
    public let height: Int

    public init(width: Int, height: Int) {
        self.width = max(0, width)
        self.height = max(0, height)
    }

    public var pixelCount: Int { width * height }
    public var longestEdge: Int { max(width, height) }
    public var shortestEdge: Int { min(width, height) }
    /// `0` when either dimension is zero (avoids divide-by-zero in resize math).
    public var aspectRatio: Double {
        guard height > 0 else { return 0 }
        return Double(width) / Double(height)
    }
    public var isNonEmpty: Bool { width > 0 && height > 0 }
}

/// EXIF orientation as a plain int (1...8), matching TIFF/EXIF conventions.
/// `1` means "up". `nil` means the source did not report orientation.
public struct MediaOrientation: Hashable, Sendable, Codable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    public static let up = MediaOrientation(rawValue: 1)
    public var isUp: Bool { rawValue == 1 }
}

/// Result of probing a source file. All fields optional except `kind`, `format`,
/// `fileSize` and `url`: an audio file has no dimensions, a still image has no
/// duration, and a corrupt file may report very little.
public struct MediaProbeResult: Hashable, Sendable, Codable {
    public let url: URL
    public let kind: MediaKind
    /// Best-effort detected format identifier. May differ from the output
    /// target; probing never infers capability from extension alone at the
    /// backend layer, but the DTO carries the observed format for display.
    public let formatHint: MediaFormatID?
    public let fileSize: Int64
    public let dimensions: MediaDimensions?
    public let durationSeconds: Double?
    public let frameRate: Double?
    public let sampleRate: Double?
    public let channelCount: Int?
    public let hasAlpha: Bool?
    public let orientation: MediaOrientation?
    public let colorProfileName: String?

    public init(
        url: URL,
        kind: MediaKind,
        formatHint: MediaFormatID?,
        fileSize: Int64,
        dimensions: MediaDimensions? = nil,
        durationSeconds: Double? = nil,
        frameRate: Double? = nil,
        sampleRate: Double? = nil,
        channelCount: Int? = nil,
        hasAlpha: Bool? = nil,
        orientation: MediaOrientation? = nil,
        colorProfileName: String? = nil
    ) {
        self.url = url
        self.kind = kind
        self.formatHint = formatHint
        self.fileSize = max(0, fileSize)
        self.dimensions = dimensions
        self.durationSeconds = durationSeconds
        self.frameRate = frameRate
        self.sampleRate = sampleRate
        self.channelCount = channelCount
        self.hasAlpha = hasAlpha
        self.orientation = orientation
        self.colorProfileName = colorProfileName
    }
}
