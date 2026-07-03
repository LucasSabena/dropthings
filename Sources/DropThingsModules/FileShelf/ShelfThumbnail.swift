import SwiftUI
import AppKit
import DropThingsDesignSystem
import DropThingsPlatform

/// Thumbnail view for a shelf item. Renders the real preview for image/PDF
/// files, and falls back to a type-symbol tile for everything else (text,
/// folders, unknown formats, missing files). States use design tokens only.
struct ShelfThumbnail: View {
    let item: FileShelfItem
    let edge: CGFloat

    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                fallbackTile
            }
        }
        .frame(width: edge, height: edge)
        .clipShape(RoundedRectangle(cornerRadius: DTRadius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DTRadius.md, style: .continuous)
                .stroke(DTColor.border, lineWidth: 0.5)
        )
        .task(id: item.id) { await loadThumbnail() }
    }

    private var fallbackTile: some View {
        ZStack {
            DTColor.surfaceRaised
            Image(systemName: item.iconName)
                .font(.system(size: edge * 0.42))
                .foregroundStyle(DTColor.textSecondary)
        }
    }

    @MainActor
    private func loadThumbnail() async {
        guard let url = item.fileURL else {
            image = nil
            return
        }
        // ThumbnailGenerator is cheap and cached; hop off the main thread
        // for the decode, then hop back to assign.
        let edge = self.edge
        let result = await Task.detached(priority: .userInitiated) {
            ThumbnailGenerator.shared.thumbnail(for: url, edge: edge)
        }.value
        self.image = result
    }
}
