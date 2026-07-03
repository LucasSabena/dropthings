import XCTest
import AppKit
import DropThingsPlatform

final class ThumbnailGeneratorTests: XCTestCase {

    func testReturnsResizedThumbnailForRealImage() throws {
        let url = try writePNG(size: 400, in: makeTempDir())
        let generator = ThumbnailGenerator()
        let thumb = generator.thumbnail(for: url, edge: 48)
        XCTAssertNotNil(thumb)
        // Longest edge should be ~48 within rounding.
        let longest = max(thumb!.size.width, thumb!.size.height)
        XCTAssertEqual(longest, 48, accuracy: 1)
    }

    func testReturnsNilForMissingFile() {
        let generator = ThumbnailGenerator()
        let url = URL(fileURLWithPath: "/tmp/dropthings-does-not-exist-\(UUID().uuidString).png")
        XCTAssertNil(generator.thumbnail(for: url))
    }

    func testCachesAcrossCalls() throws {
        let url = try writePNG(size: 100, in: makeTempDir())
        let generator = ThumbnailGenerator()
        let first = generator.thumbnail(for: url, edge: 32)
        let second = generator.thumbnail(for: url, edge: 32)
        XCTAssertNotNil(first)
        // Same identity means it came from the cache (not regenerated).
        XCTAssertTrue(first === second)
    }

    func testClearEmptiesCache() throws {
        let url = try writePNG(size: 100, in: makeTempDir())
        let generator = ThumbnailGenerator()
        let first = generator.thumbnail(for: url, edge: 32)
        generator.clear()
        let second = generator.thumbnail(for: url, edge: 32)
        XCTAssertNotNil(first)
        XCTAssertNotNil(second)
        // After clear, a fresh image is generated → different identity.
        XCTAssertFalse(first === second)
    }

    func testPDFThumbnailFromFirstPage() throws {
        let url = try writeMinimalPDF(in: makeTempDir())
        let generator = ThumbnailGenerator()
        let thumb = generator.thumbnail(for: url, edge: 48)
        XCTAssertNotNil(thumb)
        XCTAssertGreaterThan(thumb!.size.width, 0)
    }

    // MARK: - helpers

    private func makeTempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("dropthings-thumb-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    @discardableResult
    private func writePNG(size: CGFloat, in dir: URL) throws -> URL {
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()
        NSColor.systemBlue.setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: size, height: size)).fill()
        image.unlockFocus()
        let tiff = image.tiffRepresentation!
        let rep = NSBitmapImageRep(data: tiff)!
        let png = rep.representation(using: .png, properties: [:])!
        let url = dir.appendingPathComponent("img-\(UUID().uuidString).png")
        try png.write(to: url)
        return url
    }

    @discardableResult
    private func writeMinimalPDF(in dir: URL) throws -> URL {
        // Build a PDF the documented way: a CGContext PDF consumer.
        let url = dir.appendingPathComponent("doc-\(UUID().uuidString).pdf")
        var pageRect = CGRect(x: 0, y: 0, width: 200, height: 200)
        guard let ctx = CGContext(url as CFURL, mediaBox: &pageRect, nil) else {
            throw NSError(domain: "test", code: 1, userInfo: nil)
        }
        ctx.beginPDFPage(nil)
        ctx.setFillColor(red: 1, green: 0, blue: 0, alpha: 1)
        ctx.fill(pageRect)
        ctx.endPDFPage()
        ctx.closePDF()
        return url
    }
}
