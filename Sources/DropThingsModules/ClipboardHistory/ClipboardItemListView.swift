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

/// A single row. The type icon is replaced by a thumbnail for image items.
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
            onPaste()
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
            case .image:
                if let thumbnail {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: "photo")
                        .foregroundStyle(DTColor.accent)
                }
            case .color:
                if let color = item.nsColor {
                    Color(nsColor: color)
                } else {
                    Color.clear
                }
            default:
                Image(systemName: iconName)
                    .foregroundStyle(DTColor.accent)
            }
        }
        .frame(width: 22, height: 22)
        .clipShape(RoundedRectangle(cornerRadius: DTRadius.xs, style: .continuous))
    }

    private var iconName: String {
        switch item.type {
        case .plainText: return "text.quote"
        case .url: return "link"
        case .filePath: return "doc"
        case .image: return "photo"
        case .color: return "paintpalette"
        }
    }

    @MainActor
    private func loadThumbnail() async {
        guard item.type == .image, let image = item.nsImage else {
            thumbnail = nil
            return
        }
        let edge: CGFloat = 44
        let result = await Task.detached(priority: .userInitiated) {
            resized(image, edge: edge)
        }.value
        thumbnail = result
    }

    private func resized(_ image: NSImage, edge: CGFloat) -> NSImage? {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return nil }
        let scale = edge / max(size.width, size.height)
        let target = NSSize(width: size.width * scale, height: size.height * scale)
        let out = NSImage(size: target)
        out.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: target), from: .zero, operation: .copy, fraction: 1)
        out.unlockFocus()
        return out
    }
}
