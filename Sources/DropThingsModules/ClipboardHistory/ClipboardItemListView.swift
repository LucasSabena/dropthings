import AppKit
import SwiftUI
import DropThingsDesignSystem
import DropThingsPlatform

/// Left column: a scrollable list of clipboard rows with a selection
/// highlight, a leading type icon or thumbnail, and pin/favorite badges.
struct ClipboardItemListView: View {
    let items: [ClipboardItem]
    @Binding var selectedID: UUID?
    let onSelect: (UUID) -> Void
    let onCopy: (ClipboardItem) -> Void
    let onPaste: (ClipboardItem) -> Void
    let onTogglePin: (ClipboardItem) -> Void
    let onToggleFavorite: (ClipboardItem) -> Void
    let onRemove: (ClipboardItem) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(spacing: DTSpace.xxs) {
                if items.isEmpty {
                    emptyState
                        .padding(.top, DTSpace.xxl)
                } else {
                    ForEach(items) { item in
                        ClipboardItemRow(
                            item: item,
                            isSelected: selectedID == item.id,
                            onSelect: { onSelect(item.id) },
                            onCopy: { onCopy(item) },
                            onPaste: { onPaste(item) },
                            onTogglePin: { onTogglePin(item) },
                            onToggleFavorite: { onToggleFavorite(item) },
                            onRemove: { onRemove(item) }
                        )
                    }
                }
            }
            .padding(DTSpace.sm)
        }
    }

    private var emptyState: some View {
        VStack(spacing: DTSpace.sm) {
            Image(systemName: "tray")
                .font(DTTypography.emptyStateGlyph)
                .foregroundStyle(DTColor.textSecondary)
            Text("Nothing here yet.")
                .font(DTTypography.body)
                .foregroundStyle(DTColor.textSecondary)
        }
    }
}

/// A single row. Clicking selects and updates the detail preview; execution is
/// explicit via Return, double-click/context actions, or the detail buttons.
/// This avoids the old surprising behavior where merely inspecting a row
/// immediately pasted it into another application.
private struct ClipboardItemRow: View {
    let item: ClipboardItem
    let isSelected: Bool
    let onSelect: () -> Void
    let onCopy: () -> Void
    let onPaste: () -> Void
    let onTogglePin: () -> Void
    let onToggleFavorite: () -> Void
    let onRemove: () -> Void

    @State private var thumbnail: NSImage?

    var body: some View {
        Button {
            onSelect()
        } label: {
            HStack(spacing: DTSpace.sm) {
                leading
                VStack(alignment: .leading, spacing: DTSpace.xxs) {
                    Text(item.displayTitle)
                        .font(DTTypography.body)
                        .foregroundStyle(DTColor.textPrimary)
                        .lineLimit(1)
                    Text(item.displaySubtitle)
                        .font(DTTypography.caption)
                        .foregroundStyle(DTColor.textSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                if item.isPinned {
                    Image(systemName: "pin.fill")
                        .font(DTTypography.badgeLabel)
                        .foregroundStyle(DTColor.accent)
                }
                if item.isFavorite {
                    Image(systemName: "star.fill")
                        .font(DTTypography.badgeLabel)
                        .foregroundStyle(DTColor.warning)
                }
            }
            .padding(.vertical, DTSpace.xs)
            .padding(.horizontal, DTSpace.sm)
            .background(
                RoundedRectangle(cornerRadius: DTRadius.sm, style: .continuous)
                    .fill(isSelected ? DTColor.accent.opacity(0.12) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onDrag { itemProvider }
        .contextMenu {
            Button("Paste") { onPaste() }
            Button("Copy") { onCopy() }
            Divider()
            Button(item.isPinned ? "Unpin" : "Pin") { onTogglePin() }
            Button(item.isFavorite ? "Unfavorite" : "Favorite") { onToggleFavorite() }
            Button("Remove", role: .destructive) { onRemove() }
        }
        .task(id: item.id) { await loadThumbnail() }
    }

    @ViewBuilder
    private var leading: some View {
        Group {
            switch item.type {
            case .image, .video:
                if let thumbnail {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: item.systemImageName)
                        .foregroundStyle(DTColor.accent)
                }
            case .color:
                if let color = item.nsColor {
                    Color(nsColor: color)
                } else {
                    Color.clear
                }
            default:
                Image(systemName: item.systemImageName)
                    .foregroundStyle(DTColor.accent)
            }
        }
        .frame(width: DTSize.previewSmall, height: DTSize.previewSmall)
        .clipShape(RoundedRectangle(cornerRadius: DTRadius.xs, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DTRadius.xs, style: .continuous)
                .strokeBorder(DTColor.border, lineWidth: 0.5)
        )
    }

    @MainActor
    private func loadThumbnail() async {
        if let url = item.fileURL,
           item.type == .image || item.type == .video || item.type == .filePath {
            thumbnail = await ThumbnailGenerator.shared.thumbnailAsync(
                for: url,
                edge: DTSize.previewSmall
            )
            return
        }
        guard item.type == .image else {
            thumbnail = nil
            return
        }
        thumbnail = item.nsImage
    }

    private var itemProvider: NSItemProvider {
        if let url = item.fileURL, let provider = NSItemProvider(contentsOf: url) {
            return provider
        }
        if let image = item.nsImage {
            return NSItemProvider(object: image)
        }
        return NSItemProvider(object: item.content as NSString)
    }
}
