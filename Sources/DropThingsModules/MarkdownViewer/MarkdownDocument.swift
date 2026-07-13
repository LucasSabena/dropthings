import Foundation
import AppKit
import Combine
import DropThingsCore

/// In-memory Markdown document loaded into the viewer. Not persisted: only
/// `MarkdownViewerSettings.recentFiles` survives a relaunch, and that stores
/// a path string, not the contents.
///
/// `text` is the source the user edits. `isDirty` flips to true on the first
/// edit after a load or save and back to false when the file is written.
@MainActor
public final class MarkdownDocument: ObservableObject, Identifiable {
    public let id: UUID
    @Published public private(set) var url: URL?
    @Published public var text: String
    @Published public private(set) var isDirty: Bool = false
    @Published public private(set) var isLoading: Bool = false
    @Published public private(set) var loadError: String?

    private var editObserver: AnyCancellable?

    public init(id: UUID = UUID(), url: URL? = nil, text: String = "") {
        self.id = id
        self.url = url
        self.text = text
        observeEdits()
    }

    /// Replace the whole document from disk. Clears `isDirty` and any prior
    /// error. Throws are captured into `loadError` instead of propagating so
    /// the UI always has a stable state to render.
    public func load(from url: URL) {
        isLoading = true
        loadError = nil
        do {
            let data = try Data(contentsOf: url)
            let decoded = String(data: data, encoding: .utf8)
                ?? String(decoding: data, as: UTF8.self)
            self.url = url
            self.text = decoded
            self.isDirty = false
        } catch {
            self.loadError = "Could not open \(url.lastPathComponent): \(error.localizedDescription)"
            self.url = nil
        }
        isLoading = false
    }

    /// Write the current text back to `url`. Returns true on success so the
    /// caller can update recents and clear the dirty flag.
    @discardableResult
    public func save() -> Bool {
        guard let url else { return false }
        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
            isDirty = false
            return true
        } catch {
            loadError = "Could not save \(url.lastPathComponent): \(error.localizedDescription)"
            return false
        }
    }

    /// Open the system Save panel so the user can pick a new path. On OK,
    /// writes the file, adopts the URL, and clears the dirty flag.
    @discardableResult
    public func saveAs() -> Bool {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = url?.lastPathComponent ?? "Untitled.md"
        guard panel.runModal() == .OK, let target = panel.url else { return false }
        do {
            try text.write(to: target, atomically: true, encoding: .utf8)
            self.url = target
            self.isDirty = false
            return true
        } catch {
            loadError = "Could not save \(target.lastPathComponent): \(error.localizedDescription)"
            return false
        }
    }

    /// Reset to an untitled empty document. Used by "New" and by a failed
    /// recent-file open so the window never stays bound to a dead URL.
    public func resetToUntitled() {
        url = nil
        text = ""
        isDirty = false
        loadError = nil
    }

    public var displayName: String {
        url?.lastPathComponent ?? "Untitled.md"
    }

    private func observeEdits() {
        editObserver = $text
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] _ in self?.isDirty = true }
    }
}
