import AppKit
import SwiftUI
import DropThingsDesignSystem
import DropThingsPlatform

/// Integrated inspector for the current shelf selection. Quick Look keeps the
/// preview native and format-agnostic; text items use a selectable monospaced
/// surface. The shelf remains open and accepts drops while this pane is shown.
struct ShelfDetailView: View {
    let item: FileShelfItem
    @ObservedObject var module: FileShelfModule

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DTSpace.md) {
                header
                preview
                metadata
                actions
            }
            .padding(DTSpace.md)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(DTColor.surface.opacity(0.45))
    }

    private var header: some View {
        HStack(alignment: .top, spacing: DTSpace.sm) {
            Image(systemName: item.contentInfo?.kind.systemImageName ?? item.iconName)
                .font(DTTypography.moduleIcon)
                .foregroundStyle(DTColor.accent)
            VStack(alignment: .leading, spacing: DTSpace.xxs) {
                Text(item.displayName)
                    .font(DTTypography.body.weight(.semibold))
                    .lineLimit(2)
                Text(item.metadataSummary)
                    .font(DTTypography.caption)
                    .foregroundStyle(DTColor.textSecondary)
            }
        }
    }

    @ViewBuilder
    private var preview: some View {
        if let url = item.fileURL {
            QuickLookPreview(url: url)
                .frame(minHeight: DTSize.previewLarge * 2)
                .clipShape(RoundedRectangle(cornerRadius: DTRadius.md, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: DTRadius.md, style: .continuous)
                        .strokeBorder(DTColor.border, lineWidth: 0.5)
                )
        } else if case .text(let text) = item.kind {
            Text(text)
                .font(DTTypography.monospacedBody)
                .foregroundStyle(DTColor.textPrimary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, minHeight: DTSize.previewLarge, alignment: .topLeading)
                .padding(DTSpace.sm)
                .background(
                    RoundedRectangle(cornerRadius: DTRadius.md, style: .continuous)
                        .fill(DTColor.surface)
                )
        }
    }

    private var metadata: some View {
        VStack(spacing: DTSpace.xs) {
            if let path = item.displayPath {
                metadataRow(label: "Path", value: path)
            }
            metadataRow(label: "Added", value: relativeDate(item.addedAt))
            metadataRow(label: "Type", value: item.fileTypeLabel)
        }
        .padding(DTSpace.sm)
        .background(
            RoundedRectangle(cornerRadius: DTRadius.md, style: .continuous)
                .fill(DTColor.surface)
        )
    }

    private var actions: some View {
        VStack(alignment: .leading, spacing: DTSpace.sm) {
            if item.fileURL != nil {
                if module.isImage(item) {
                    Button { module.copyImage(item) } label: {
                        Label("Copy image", systemImage: "doc.on.doc")
                    }
                }
                Button { module.revealInFinder(item) } label: {
                    Label("Reveal in Finder", systemImage: "folder")
                }
                Button { module.copyPath(item) } label: {
                    Label("Copy path", systemImage: "doc.on.doc")
                }
            }
            Button { module.setPinned(item.id, pinned: !item.isPinned) } label: {
                Label(item.isPinned ? "Unpin" : "Pin", systemImage: item.isPinned ? "pin.slash" : "pin")
            }
            Button(role: .destructive) { module.removeItem(id: item.id) } label: {
                Label("Remove from shelf", systemImage: "trash")
            }
        }
        .buttonStyle(.borderless)
        .controlSize(.small)
    }

    private func metadataRow(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(DTTypography.caption)
                .foregroundStyle(DTColor.textSecondary)
            Spacer(minLength: DTSpace.sm)
            Text(value)
                .font(DTTypography.caption)
                .foregroundStyle(DTColor.textPrimary)
                .lineLimit(2)
                .truncationMode(.middle)
                .textSelection(.enabled)
        }
    }

    private func relativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
