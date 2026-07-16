import Foundation
import AppKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import DropThingsMediaConverterKit

/// Encodes an image to a target format with optional resize and metadata
/// policy. The protocol is the narrow adapter the pipeline depends on; tests
/// inject a fake and never touch ImageIO.
public protocol ImageEncoding: AnyObject, Sendable {
    func encode(_ request: MediaConversionRequest, source: MediaProbeResult) async -> Result<URL, MediaConverterError>
}

/// Native image encoder using ImageIO + CoreGraphics. Handles PNG/JPEG/HEIC/
/// TIFF, resize, and metadata policy. This is the backend that works
/// today without FFmpeg.
public final class NativeImageEncoder: ImageEncoding {
    public init() {}

    public func encode(_ request: MediaConversionRequest, source: MediaProbeResult) async -> Result<URL, MediaConverterError> {
        guard request.outputFormat.kind == .image else {
            return .failure(.unsupportedConversion(reason: "Native encoder handles images only."))
        }
        guard let sourceDims = source.dimensions else {
            return .failure(.probeFailed(reason: "Source dimensions are missing."))
        }
        guard let outputType = request.outputFormat.utType else {
            return .failure(.unsupportedConversion(reason: "Unknown output format."))
        }

        // Load the source CGImage.
        guard let src = CGImageSourceCreateWithURL(source.url as CFURL, nil),
              let cgImage = orientedImage(from: src, maximumPixelSize: sourceDims.longestEdge) else {
            return .failure(.probeFailed(reason: "Could not read the source image."))
        }

        // Apply resize if requested.
        let finalImage: CGImage
        if case .none = request.resize {
            finalImage = cgImage
        } else if let target = ResizeMath.targetDimensions(source: sourceDims, policy: request.resize, noUpscale: request.noUpscale),
                  let scaled = resize(cgImage, to: target) {
            finalImage = scaled
        } else {
            finalImage = cgImage
        }

        // Resolve the output URL with the conflict policy.
        let proposed = OutputNaming.proposedURL(for: source.url, format: request.outputFormat, in: request.outputDirectory)
        let resolved = OutputNaming.resolve(proposed, conflict: request.conflict, exists: { FileManager.default.fileExists(atPath: $0.path) })
        guard let resolved else {
            return .failure(.finalizationFailed(reason: "An output with this name already exists."))
        }

        // Create the destination and write.
        do {
            try FileManager.default.createDirectory(at: resolved.deletingLastPathComponent(), withIntermediateDirectories: true)
        } catch {
            return .failure(.finalizationFailed(reason: error.localizedDescription))
        }
        guard let dest = CGImageDestinationCreateWithURL(resolved as CFURL, outputType.identifier as CFString, 1, nil) else {
            return .failure(.unsupportedConversion(reason: "This image format isn't supported here."))
        }

        let sourceProperties = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any] ?? [:]
        var properties = applyMetadata(
            properties: sourceProperties,
            policy: request.metadata,
            format: request.outputFormat
        )
        // Pixel data has already been transformed to display orientation.
        // Persisting the source orientation would rotate it a second time.
        properties[kCGImagePropertyOrientation] = 1
        if isLossy(request.outputFormat) {
            properties[kCGImageDestinationLossyCompressionQuality] = Double(request.quality) / 100.0
        }
        CGImageDestinationAddImage(dest, finalImage, properties as CFDictionary)

        guard CGImageDestinationFinalize(dest) else {
            try? FileManager.default.removeItem(at: resolved)
            return .failure(.outputReprobeFailed(reason: "The encoder could not finalize the image."))
        }

        return .success(resolved)
    }

    // MARK: - Helpers

    private func isLossy(_ format: MediaFormatID) -> Bool {
        switch format {
        case .jpeg, .heic, .webp: return true
        default: return false
        }
    }

    private func applyMetadata(properties: [CFString: Any], policy: MetadataPolicy, format: MediaFormatID) -> [CFString: Any] {
        var props = properties
        switch policy {
        case .preserve:
            break
        case .removeLocationOnly:
            props.removeValue(forKey: kCGImagePropertyGPSDictionary)
        case .stripNonessential:
            // Keep image-description properties needed for correct rendering,
            // but remove camera, authoring and location dictionaries.
            props.removeValue(forKey: kCGImagePropertyExifDictionary)
            props.removeValue(forKey: kCGImagePropertyIPTCDictionary)
            props.removeValue(forKey: kCGImagePropertyGPSDictionary)
            props.removeValue(forKey: kCGImagePropertyTIFFDictionary)
        }
        return props
    }

    private func resize(_ image: CGImage, to dims: MediaDimensions) -> CGImage? {
        guard dims.isNonEmpty else { return nil }
        guard let cs = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        guard let ctx = CGContext(
            data: nil,
            width: dims.width,
            height: dims.height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: cs,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        ctx.interpolationQuality = .high
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: dims.width, height: dims.height))
        return ctx.makeImage()
    }

    private func orientedImage(from source: CGImageSource, maximumPixelSize: Int) -> CGImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: max(1, maximumPixelSize),
            kCGImageSourceShouldCacheImmediately: true
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }
}
