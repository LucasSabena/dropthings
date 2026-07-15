import AppKit
import UniformTypeIdentifiers
import DropThingsCore

/// Reads the public pasteboard and emits new items. Lives in Platform because
/// `NSPasteboard` is a system adapter; the module decides what to store.
///
/// Conforms to `PasteboardBackend` so the shared `PasteboardHub` can drive one
/// observer for every interested module. The legacy `handler` property is kept
/// for existing direct callers (File Shelf) until they migrate to the hub.
@MainActor
public final class ClipboardMonitor: PasteboardBackend {
    public struct Item: Sendable, Equatable {
        public let text: String?
        public let url: URL?
        public let fileURLs: [URL]
        /// TIFF data when the pasteboard holds an image (copied screenshot,
        /// image from Preview, etc.). `nil` otherwise.
        public let imageData: Data?
        /// sRGB hex `#RRGGBB` when the pasteboard holds an `NSColor` (Xcode,
        /// Finder, design tools). `nil` otherwise.
        public let colorHex: String?
        public let isTransient: Bool
        public let isConcealed: Bool
        public let sourceBundleID: String?

        public init(text: String?, url: URL?, fileURLs: [URL], imageData: Data? = nil, colorHex: String? = nil, isTransient: Bool, isConcealed: Bool, sourceBundleID: String?) {
            self.text = text
            self.url = url
            self.fileURLs = fileURLs
            self.imageData = imageData
            self.colorHex = colorHex
            self.isTransient = isTransient
            self.isConcealed = isConcealed
            self.sourceBundleID = sourceBundleID
        }

        /// Bridge to the hub's Foundation-only snapshot. Loses `changeCount`,
        /// which the hub fills in itself.
        public func snapshot(changeCount: Int) -> PasteboardHub.Snapshot {
            PasteboardHub.Snapshot(
                changeCount: changeCount,
                text: text,
                url: url,
                fileURLs: fileURLs,
                imageData: imageData,
                colorHex: colorHex,
                isTransient: isTransient,
                isConcealed: isConcealed,
                sourceBundleID: sourceBundleID
            )
        }
    }

    public typealias Handler = @MainActor (Item) -> Void

    /// Legacy handler for direct callers not yet on `PasteboardHub`.
    public var handler: Handler
    private var timer: Timer?
    private var lastChangeCount: Int
    private let pasteboard = NSPasteboard.general
    private var hubHandler: (@MainActor @Sendable (PasteboardHub.Snapshot) -> Void)?

    public init(handler: @escaping Handler = { _ in }) {
        self.handler = handler
        self.lastChangeCount = pasteboard.changeCount
    }

    public convenience init(_ handler: @escaping Handler) {
        self.init(handler: handler)
    }

    // MARK: - PasteboardBackend

    public var isRunning: Bool { timer != nil }

    public func start(interval: TimeInterval, handler: @escaping @MainActor @Sendable (PasteboardHub.Snapshot) -> Void) {
        hubHandler = handler
        start(interval: interval)
    }

    public func start(interval: TimeInterval = 0.5) {
        timer?.invalidate()
        lastChangeCount = pasteboard.changeCount
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.poll()
            }
        }
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
        hubHandler = nil
    }

    private func poll() {
        let current = pasteboard.changeCount
        guard current != lastChangeCount else { return }
        lastChangeCount = current
        guard let item = readCurrent() else { return }
        handler(item)
        if let hubHandler {
            hubHandler(item.snapshot(changeCount: current))
        }
    }

    private func readCurrent() -> Item? {
        Self.read(pasteboard)
    }

    /// Read a pasteboard once and return a typed item. Exposed so modules
    /// that need a one-shot read (Smart Clipboard's panel refresh) can share
    /// the exact same parsing logic as the poller instead of duplicating it.
    public static func read(_ pasteboard: NSPasteboard) -> Item? {
        let types = pasteboard.types ?? []
        let isTransient = types.contains(.init(rawValue: "org.nspasteboard.TransientType"))
        let isConcealed = types.contains(.init(rawValue: "org.nspasteboard.ConcealedType"))

        var text: String?
        var url: URL?
        var fileURLs: [URL] = []
        var imageData: Data?
        var colorHex: String?

        // Capture image data, but prefer real file URLs below. Finder often
        // publishes both a file URL and an icon/preview TIFF; retaining the URL
        // preserves video playback, folders, Quick Look, and drag-out.
        if let tiff = pasteboard.data(forType: .tiff) ?? pasteboard.data(forType: .png) {
            imageData = tiff
        }

        if let string = pasteboard.string(forType: .string), !string.isEmpty {
            text = string
            if let candidate = URL(string: string), candidate.scheme != nil {
                url = candidate
            }
        }

        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
            fileURLs = urls.filter(\.isFileURL)
            if !fileURLs.isEmpty {
                imageData = nil
            }
        }

        // Color: read as NSColor and normalize to a hex string. Xcode/Finder
        // and design tools put a color object on the pasteboard via NSColor's
        // NSPasteboardWriting conformance.
        if let nsColor = pasteboard.readObjects(forClasses: [NSColor.self], options: nil)?.first as? NSColor {
            colorHex = ClipboardColorHex.hex(from: nsColor)
        }

        if text == nil && fileURLs.isEmpty && url == nil && imageData == nil && colorHex == nil {
            return nil
        }

        return Item(
            text: text,
            url: url,
            fileURLs: fileURLs,
            imageData: imageData,
            colorHex: colorHex,
            isTransient: isTransient,
            isConcealed: isConcealed,
            sourceBundleID: NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        )
    }
}

public extension NSPasteboard.PasteboardType {
    static let transientType = NSPasteboard.PasteboardType("org.nspasteboard.TransientType")
    static let concealedType = NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")
}
