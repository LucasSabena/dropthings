import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import XCTest
import DropThingsMediaConverterKit
import DropThingsPlatform

final class NativeImageMetadataTests: XCTestCase {
    func testPreserveKeepsGPSAndStripRemovesIt() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let source = root.appendingPathComponent("source.jpg")
        let preservedDirectory = root.appendingPathComponent("preserved")
        let strippedDirectory = root.appendingPathComponent("stripped")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try writeJPEGWithGPS(to: source)

        let probe = try await NativeMediaProbe().probe(url: source).get()
        let encoder = NativeImageEncoder()
        let preserved = try await encoder.encode(
            MediaConversionRequest(
                source: source, outputDirectory: preservedDirectory,
                outputFormat: .jpeg, metadata: .preserve
            ),
            source: probe
        ).get()
        let stripped = try await encoder.encode(
            MediaConversionRequest(
                source: source, outputDirectory: strippedDirectory,
                outputFormat: .jpeg, metadata: .stripNonessential
            ),
            source: probe
        ).get()

        XCTAssertNotNil(properties(of: preserved)[kCGImagePropertyGPSDictionary])
        XCTAssertNil(properties(of: stripped)[kCGImagePropertyGPSDictionary])
    }

    func testConversionAppliesEXIFOrientationToPixels() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let source = root.appendingPathComponent("rotated.jpg")
        let outputDirectory = root.appendingPathComponent("output")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try writeJPEG(to: source, width: 2, height: 3, orientation: 6)

        let probe = try await NativeMediaProbe().probe(url: source).get()
        XCTAssertEqual(probe.dimensions, MediaDimensions(width: 3, height: 2))

        let output = try await NativeImageEncoder().encode(
            MediaConversionRequest(
                source: source,
                outputDirectory: outputDirectory,
                outputFormat: .png
            ),
            source: probe
        ).get()
        let outputProbe = try await NativeMediaProbe().probe(url: output).get()

        XCTAssertEqual(outputProbe.dimensions, MediaDimensions(width: 3, height: 2))
        XCTAssertTrue(outputProbe.orientation == nil || outputProbe.orientation == .up)
    }

    private func writeJPEGWithGPS(to url: URL) throws {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(
            data: nil, width: 8, height: 8, bitsPerComponent: 8,
            bytesPerRow: 0, space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.setFillColor(CGColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        let image = context.makeImage()!
        let destination = CGImageDestinationCreateWithURL(
            url as CFURL,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        )!
        let gps: [CFString: Any] = [
            kCGImagePropertyGPSLatitude: 34.6,
            kCGImagePropertyGPSLatitudeRef: "S",
            kCGImagePropertyGPSLongitude: 58.4,
            kCGImagePropertyGPSLongitudeRef: "W"
        ]
        CGImageDestinationAddImage(destination, image, [kCGImagePropertyGPSDictionary: gps] as CFDictionary)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
    }

    private func writeJPEG(to url: URL, width: Int, height: Int, orientation: Int) throws {
        let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.setFillColor(CGColor(red: 0.9, green: 0.2, blue: 0.1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let destination = CGImageDestinationCreateWithURL(
            url as CFURL,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        )!
        CGImageDestinationAddImage(
            destination,
            context.makeImage()!,
            [kCGImagePropertyOrientation: orientation] as CFDictionary
        )
        XCTAssertTrue(CGImageDestinationFinalize(destination))
    }

    private func properties(of url: URL) -> [CFString: Any] {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return [:] }
        return CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] ?? [:]
    }
}
