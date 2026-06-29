import AppKit
import UniformTypeIdentifiers

/// Reads the public pasteboard and emits new items. Lives in Platform because
/// `NSPasteboard` is a system adapter; the module decides what to store.
@MainActor
public final class ClipboardMonitor {
    public struct Item: Sendable, Equatable {
        public let text: String?
        public let url: URL?
        public let fileURLs: [URL]
        public let isTransient: Bool
        public let isConcealed: Bool
        public let sourceBundleID: String?

        public init(text: String?, url: URL?, fileURLs: [URL], isTransient: Bool, isConcealed: Bool, sourceBundleID: String?) {
            self.text = text
            self.url = url
            self.fileURLs = fileURLs
            self.isTransient = isTransient
            self.isConcealed = isConcealed
            self.sourceBundleID = sourceBundleID
        }
    }

    public typealias Handler = @MainActor (Item) -> Void

    public var handler: Handler
    private var timer: Timer?
    private var lastChangeCount: Int
    private let pasteboard = NSPasteboard.general

    public init(handler: @escaping Handler = { _ in }) {
        self.handler = handler
        self.lastChangeCount = pasteboard.changeCount
    }

    public convenience init(_ handler: @escaping Handler) {
        self.init(handler: handler)
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
    }

    private func poll() {
        let current = pasteboard.changeCount
        guard current != lastChangeCount else { return }
        lastChangeCount = current
        guard let item = readCurrent() else { return }
        handler(item)
    }

    private func readCurrent() -> Item? {
        let types = pasteboard.types ?? []
        let isTransient = types.contains(.init(rawValue: "org.nspasteboard.TransientType"))
        let isConcealed = types.contains(.init(rawValue: "org.nspasteboard.ConcealedType"))

        var text: String?
        var url: URL?
        var fileURLs: [URL] = []

        if let string = pasteboard.string(forType: .string), !string.isEmpty {
            text = string
            if let candidate = URL(string: string), candidate.scheme != nil {
                url = candidate
            }
        }

        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
            fileURLs = urls
        }

        if text == nil && fileURLs.isEmpty && url == nil {
            return nil
        }

        return Item(
            text: text,
            url: url,
            fileURLs: fileURLs,
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
