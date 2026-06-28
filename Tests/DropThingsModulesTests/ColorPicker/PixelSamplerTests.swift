import XCTest
@testable import DropThingsModules
@testable import DropThingsCore
import DropThingsPlatform
import AppKit
import CoreGraphics

@MainActor
final class PixelSamplerTests: XCTestCase {
    func testSampleReturnsExpectedRGB() throws {
        let width = 4
        let height = 4
        let bytesPerRow = width * 4
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        // Fill with a known gradient: each row is constant red,
        // each column varies green.
        for y in 0..<height {
            for x in 0..<width {
                let i = y * bytesPerRow + x * 4
                pixels[i + 0] = UInt8(y * 60)   // red
                pixels[i + 1] = UInt8(x * 60)   // green
                pixels[i + 2] = 128               // blue
                pixels[i + 3] = 255               // alpha
            }
        }
        let provider = CGDataProvider(data: Data(pixels) as CFData)!
        let image = CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )!

        let atOrigin = PixelSampler.sample(at: CGPoint(x: 0, y: 0), in: image)
        XCTAssertEqual(atOrigin?.r, 0)
        XCTAssertEqual(atOrigin?.g, 0)
        XCTAssertEqual(atOrigin?.b, 128)

        let atCenter = PixelSampler.sample(at: CGPoint(x: 2, y: 2), in: image)
        XCTAssertEqual(atCenter?.r, 120)
        XCTAssertEqual(atCenter?.g, 120)
        XCTAssertEqual(atCenter?.b, 128)
    }

    func testSampleOutOfBoundsReturnsNil() throws {
        let width = 2
        let height = 2
        let bytesPerRow = width * 4
        let pixels = [UInt8](repeating: 0, count: width * height * 4)
        let provider = CGDataProvider(data: Data(pixels) as CFData)!
        let image = CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )!
        XCTAssertNil(PixelSampler.sample(at: CGPoint(x: -1, y: 0), in: image))
        XCTAssertNil(PixelSampler.sample(at: CGPoint(x: 0, y: 5), in: image))
    }

    func testRGBHexFormat() {
        XCTAssertEqual(PixelSampler.RGB(r: 0, g: 0, b: 0).hex, "#000000")
        XCTAssertEqual(PixelSampler.RGB(r: 255, g: 255, b: 255).hex, "#FFFFFF")
        XCTAssertEqual(PixelSampler.RGB(r: 0xAB, g: 0xCD, b: 0xEF).hex, "#ABCDEF")
    }
}
