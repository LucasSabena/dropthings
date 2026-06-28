import AppKit
import DropThingsCore
import DropThingsDesignSystem
import DropThingsPlatform
import os

/// Saves a `CGImage` to disk as PNG and copies it to the general
/// pasteboard. v0 only writes PNG; future versions can offer JPEG.
@MainActor
public final class ScreenshotWriter {
    public enum WriteError: Error, Equatable {
        case encodingFailed
        case writeFailed
        case noAccessToDestination
    }

    public init() {}

    /// Save `image` as a PNG at `url`. Overwrites an existing file.
    @discardableResult
    public func savePNG(_ image: CGImage, to url: URL) throws -> URL {
        let bitmap = NSBitmapImageRep(cgImage: image)
        guard let data = bitmap.representation(using: .png, properties: [:]) else {
            throw WriteError.encodingFailed
        }
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            throw WriteError.writeFailed
        }
        return url
    }

    /// Copy `image` to the general pasteboard as a PNG.
    public func copyToPasteboard(_ image: CGImage) {
        let bitmap = NSBitmapImageRep(cgImage: image)
        guard let data = bitmap.representation(using: .png, properties: [:]) else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setData(data, forType: .png)
    }

    /// Resolve the destination folder, falling back to `~/Downloads/Screenshots`
    /// when the user has not picked one.
    public func resolveFolder() -> URL {
        let fm = FileManager.default
        let defaultDir = (try? fm.url(
            for: .downloadsDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Downloads")
        let dir = defaultDir.appendingPathComponent("Screenshots", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }
}
