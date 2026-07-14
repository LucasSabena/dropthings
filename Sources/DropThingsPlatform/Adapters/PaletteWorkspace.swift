import AppKit
import Foundation
import QuickLookUI

public enum PaletteWorkspaceError: LocalizedError, Sendable {
    case missingItem
    case couldNotOpen

    public var errorDescription: String? {
        switch self {
        case .missingItem: return "That item no longer exists."
        case .couldNotOpen: return "macOS could not open that item."
        }
    }
}

@MainActor
public final class PaletteWorkspace {
    private let workspace: NSWorkspace
    private let pasteboard: NSPasteboard
    private let previewDataSource = PreviewDataSource()

    public init(workspace: NSWorkspace = .shared, pasteboard: NSPasteboard = .general) {
        self.workspace = workspace
        self.pasteboard = pasteboard
    }

    public func launchApplication(at url: URL) async throws {
        guard FileManager.default.fileExists(atPath: url.path) else { throw PaletteWorkspaceError.missingItem }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        _ = try await workspace.openApplication(at: url, configuration: configuration)
    }

    public func open(_ url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else { throw PaletteWorkspaceError.missingItem }
        guard workspace.open(url) else { throw PaletteWorkspaceError.couldNotOpen }
    }

    public func openExternal(_ url: URL) throws {
        guard workspace.open(url) else { throw PaletteWorkspaceError.couldNotOpen }
    }

    /// Opens Finder's native Spotlight results for the query. This keeps
    /// system search distinct from the palette's inline file suggestions.
    public func searchSystem(for query: String) throws {
        guard workspace.showSearchResults(forQueryString: query) else {
            throw PaletteWorkspaceError.couldNotOpen
        }
    }

    /// Sends the URL to a specific installed browser through Launch Services.
    /// A running browser receives an open-URL event in that process and applies
    /// its own tab/window policy; if it is not running, macOS launches it.
    public func openWebURL(_ url: URL, browserBundleIdentifier: String?) async throws {
        guard let browserBundleIdentifier, !browserBundleIdentifier.isEmpty else {
            try openExternal(url)
            return
        }
        guard let applicationURL = workspace.urlForApplication(withBundleIdentifier: browserBundleIdentifier) else {
            throw PaletteWorkspaceError.missingItem
        }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            workspace.open([url], withApplicationAt: applicationURL, configuration: configuration) { _, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: ()) }
            }
        }
    }

    public func reveal(_ url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else { throw PaletteWorkspaceError.missingItem }
        workspace.activateFileViewerSelecting([url])
    }

    public func openContainingFolder(of url: URL) throws {
        let folder = url.hasDirectoryPath ? url : url.deletingLastPathComponent()
        try open(folder)
    }

    public func copyPath(_ url: URL) {
        pasteboard.clearContents()
        pasteboard.setString(url.path, forType: .string)
    }

    public func copyText(_ text: String) {
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    public func quickLook(_ url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else { throw PaletteWorkspaceError.missingItem }
        previewDataSource.url = url
        guard let panel = QLPreviewPanel.shared() else { throw PaletteWorkspaceError.couldNotOpen }
        panel.dataSource = previewDataSource
        panel.reloadData()
        panel.makeKeyAndOrderFront(nil)
    }
}

@MainActor
private final class PreviewDataSource: NSObject, @preconcurrency QLPreviewPanelDataSource {
    var url: URL?

    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int { url == nil ? 0 : 1 }

    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> (any QLPreviewItem)! {
        url as NSURL?
    }
}
