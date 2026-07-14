import AppKit
import PDFKit
import QuickLookThumbnailing
import UniformTypeIdentifiers

/// Generates small thumbnails for shelf items, hiding the brittle
/// image/PDF loading APIs behind a narrow interface. The shelf only ever
/// asks for a `thumbnail(for:)` and gets back a result type; the how
/// (NSImage, PDFKit, cache, fallback) stays in here.
///
/// Thumbnails are cached by `URL + content mtime` so editing a file on
/// disk invalidates the entry without a manual clear. The cache is an
/// `NSCache` so the system reclaims memory under pressure automatically.
public final class ThumbnailGenerator {
    public static let shared = ThumbnailGenerator()

    private let cache: NSCache<NSString, NSImage> = NSCache()
    private let fileManager: FileManager

    /// Default edge size for shelf thumbnails (points). Kept as a let so
    /// callers and tests share the same notion of "thumbnail size".
    public static let defaultEdge: CGFloat = 48

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        // Thumbnails are small; allow a generous count before eviction.
        cache.countLimit = 256
    }

    /// Synchronous thumbnail generation. Returns `nil` when no preview can
    /// be made (text files, missing files, unsupported formats) so the
    /// caller can render a type-symbol fallback.
    public func thumbnail(for url: URL, edge: CGFloat = ThumbnailGenerator.defaultEdge) -> NSImage? {
        let key = cacheKey(for: url, edge: edge)
        if let cached = cache.object(forKey: key) {
            return cached
        }
        guard let image = makeThumbnail(for: url, edge: edge) else { return nil }
        cache.setObject(image, forKey: key)
        return image
    }

    /// Native Quick Look thumbnail generation for formats NSImage cannot
    /// decode directly (notably movies, Office files, and many documents).
    /// Callers can await this without blocking the main actor. When Quick Look
    /// has no representation we retain the existing image/PDF fallback.
    public func thumbnailAsync(
        for url: URL,
        edge: CGFloat = ThumbnailGenerator.defaultEdge,
        scale: CGFloat = 2
    ) async -> NSImage? {
        let key = cacheKey(for: url, edge: edge)
        if let cached = cache.object(forKey: key) {
            return cached
        }

        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: CGSize(width: edge, height: edge),
            scale: scale,
            representationTypes: .all
        )
        let generated: NSImage? = await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { representation, _ in
                    continuation.resume(returning: representation?.nsImage)
                }
            }
        } onCancel: {
            QLThumbnailGenerator.shared.cancel(request)
        }
        guard !Task.isCancelled else { return nil }
        let image = generated ?? thumbnail(for: url, edge: edge)
        if let image {
            cache.setObject(image, forKey: key)
        }
        return image
    }

    /// Drop the whole cache. Used when the shelf is cleared.
    public func clear() {
        cache.removeAllObjects()
    }

    // MARK: - Private

    private func makeThumbnail(for url: URL, edge: CGFloat) -> NSImage? {
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        let ext = url.pathExtension.lowercased()
        if PDFPreview.supportedExtensions.contains(ext) {
            return pdfThumbnail(for: url, edge: edge)
        }
        // NSImage(byReferencing:) handles png/jpg/webp/avif/svg/tiff/gif/heic.
        guard let source = NSImage(byReferencing: url) as NSImage? else { return nil }
        return resized(source, edge: edge)
    }

    private func pdfThumbnail(for url: URL, edge: CGFloat) -> NSImage? {
        guard let document = PDFDocument(url: url),
              let page = document.page(at: 0) else { return nil }
        let bounds = page.bounds(for: .mediaBox)
        let scale = edge / max(bounds.width, bounds.height)
        let size = NSSize(width: bounds.width * scale, height: bounds.height * scale)
        let image = NSImage(size: size)
        image.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        page.draw(with: .mediaBox, to: NSGraphicsContext.current!.cgContext)
        image.unlockFocus()
        return image
    }

    private func resized(_ image: NSImage, edge: CGFloat) -> NSImage? {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return nil }
        let scale = edge / max(size.width, size.height)
        let target = NSSize(width: size.width * scale, height: size.height * scale)
        let out = NSImage(size: target)
        out.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(
            in: NSRect(origin: .zero, size: target),
            from: .zero,
            operation: .copy,
            fraction: 1
        )
        out.unlockFocus()
        return out
    }

    /// Cache key encodes path + mtime so an edited file busts the cache.
    private func cacheKey(for url: URL, edge: CGFloat) -> NSString {
        let mtime = (try? fileManager.attributesOfItem(atPath: url.path)[.modificationDate] as? Date)
            .map { "\($0.timeIntervalSince1970)" } ?? "0"
        return "\(url.standardizedFileURL.path)@\(mtime)#\(Int(edge.rounded()))" as NSString
    }

    private enum PDFPreview {
        static let supportedExtensions: Set<String> = ["pdf"]
    }
}
