import QuickLookUI
import SwiftUI

/// SwiftUI bridge for macOS Quick Look. It gives Clipboard History and File
/// Shelf the same native preview engine Finder uses for images, videos, PDFs,
/// source files, documents, and many third-party formats.
public struct QuickLookPreview: NSViewRepresentable {
    public let url: URL

    public init(url: URL) {
        self.url = url
    }

    public func makeNSView(context: Context) -> QLPreviewView {
        let view = QLPreviewView(frame: .zero, style: .compact)!
        view.autostarts = true
        view.shouldCloseWithWindow = false
        return view
    }

    public func updateNSView(_ view: QLPreviewView, context: Context) {
        view.previewItem = url as NSURL
    }
}
