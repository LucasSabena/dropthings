import Foundation
import AppKit
import CoreGraphics
import CoreMedia
import ImageIO
import UniformTypeIdentifiers
import AVFoundation
import DropThingsCore
import DropThingsMediaConverterKit

/// Probes a file and returns a `MediaProbeResult`. The protocol is the narrow
/// adapter the pipeline depends on; tests inject a fake that never touches
/// ImageIO or AVFoundation.
public protocol MediaProbing: AnyObject, Sendable {
    func probe(url: URL) async -> Result<MediaProbeResult, MediaConverterError>
}

/// Native probe using ImageIO for images and AVFoundation for audio/video.
/// Never infers capability from extension alone: it opens the file with the
/// real framework and reads back what it actually found.
public final class NativeMediaProbe: MediaProbing {
    private let logger = ModuleLogger(subsystem: "app.dropthings", category: "media-converter.probe")

    public init() {}

    public func probe(url: URL) async -> Result<MediaProbeResult, MediaConverterError> {
        let attrs = (try? FileManager.default.attributesOfItem(atPath: url.path)) ?? [:]
        let fileSize = (attrs[.size] as? Int64) ?? Int64((attrs[.size] as? Int) ?? 0)

        // Determine the concrete UTType from the file itself (not just the ext).
        let resolved: UTType
        if let probed = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType {
            resolved = probed
        } else if let ext = UTType(filenameExtension: url.pathExtension) {
            resolved = ext
        } else {
            resolved = .data
        }

        do {
            if resolved.conforms(to: .image) {
                return .success(try probeImage(url: url, fileSize: fileSize, type: resolved))
            }
            if resolved.conforms(to: .audio) || resolved.conforms(to: .movie) || resolved.conforms(to: .audiovisualContent) {
                return .success(try await probeAV(url: url, fileSize: fileSize, type: resolved, isVideo: resolved.conforms(to: .movie) || resolved.conforms(to: .audiovisualContent)))
            }
        } catch let error as MediaConverterError {
            return .failure(error)
        } catch {
            logger.warning("Probe failed for \(url.lastPathComponent): \(error.localizedDescription)")
            return .failure(.probeFailed(reason: error.localizedDescription))
        }

        return .failure(.unsupportedConversion(reason: "Unrecognized media type."))
    }

    // MARK: - Image (ImageIO)

    private func probeImage(url: URL, fileSize: Int64, type: UTType) throws -> MediaProbeResult {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            throw MediaConverterError.probeFailed(reason: "Could not open the image.")
        }
        let props = (CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any]) ?? [:]
        let width = (props[kCGImagePropertyPixelWidth] as? Int) ?? 0
        let height = (props[kCGImagePropertyPixelHeight] as? Int) ?? 0
        let hasAlpha = (props[kCGImagePropertyHasAlpha] as? Bool) ?? false
        let orientationRaw = props[kCGImagePropertyOrientation] as? Int
        let colorProfile = props[kCGImagePropertyColorModel] as? String

        return MediaProbeResult(
            url: url,
            kind: .image,
            formatHint: formatID(for: type),
            fileSize: fileSize,
            dimensions: MediaDimensions(width: width, height: height),
            hasAlpha: hasAlpha,
            orientation: orientationRaw.map { MediaOrientation(rawValue: $0) },
            colorProfileName: colorProfile
        )
    }

    // MARK: - Audio / Video (AVFoundation)

    private func probeAV(url: URL, fileSize: Int64, type: UTType, isVideo: Bool) async throws -> MediaProbeResult {
        let asset = AVURLAsset(url: url)
        let loadedDuration = try? await asset.load(.duration)
        let durationSeconds: Double? = loadedDuration.flatMap {
            let seconds = CMTimeGetSeconds($0)
            return seconds.isFinite && seconds > 0 ? seconds : nil
        }

        let tracks = (try? await asset.loadTracks(withMediaType: isVideo ? .video : .audio)) ?? []
        var dimensions: MediaDimensions?
        var frameRate: Double?
        var sampleRate: Double?
        var channelCount: Int?

        for track in tracks {
            if track.mediaType == .video {
                let natural = try? await track.load(.naturalSize)
                let rate = try? await track.load(.nominalFrameRate)
                if let natural {
                    dimensions = MediaDimensions(width: Int(natural.width), height: Int(natural.height))
                }
                if let rate, rate > 0, frameRate == nil { frameRate = Double(rate) }
            } else if track.mediaType == .audio {
                // Read the stream basic description from the first audio format
                // description. This is the macOS-14-safe async path.
                let descriptions = (try? await track.load(.formatDescriptions)) ?? []
                for desc in descriptions {
                    if let asbdPtr = CMAudioFormatDescriptionGetStreamBasicDescription(desc) {
                        let asbd = asbdPtr.pointee
                        if sampleRate == nil, asbd.mSampleRate > 0 {
                            sampleRate = Double(asbd.mSampleRate)
                        }
                        if channelCount == nil, asbd.mChannelsPerFrame > 0 {
                            channelCount = Int(asbd.mChannelsPerFrame)
                        }
                    }
                }
            }
        }

        return MediaProbeResult(
            url: url,
            kind: isVideo ? .video : .audio,
            formatHint: formatID(for: type),
            fileSize: fileSize,
            dimensions: dimensions,
            durationSeconds: durationSeconds,
            frameRate: frameRate,
            sampleRate: sampleRate,
            channelCount: channelCount
        )
    }

    private func formatID(for type: UTType) -> MediaFormatID? {
        if type.conforms(to: .png) { return .png }
        if type.conforms(to: .jpeg) { return .jpeg }
        if type.conforms(to: .heic) { return .heic }
        if type.conforms(to: .tiff) { return .tiff }
        if type.conforms(to: .mp3) { return .mp3 }
        if type.conforms(to: .mpeg4Movie) { return .mp4H264 }
        if type.conforms(to: .quickTimeMovie) { return .movH264 }
        return nil
    }
}
