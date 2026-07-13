import Foundation
import UniformTypeIdentifiers

/// One source of truth for the Markdown file types accepted by open panels,
/// drag-and-drop, Finder selection, and Save As.
enum MarkdownFileType {
    static let extensions: Set<String> = ["md", "markdown", "mdown", "mkd"]

    static let contentTypes: [UTType] = extensions
        .sorted()
        .compactMap { UTType(filenameExtension: $0) }

    static func accepts(_ url: URL) -> Bool {
        extensions.contains(url.pathExtension.lowercased())
    }
}
