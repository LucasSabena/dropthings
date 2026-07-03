import AppKit
import SwiftUI
import DropThingsCore
import DropThingsDesignSystem
import DropThingsPlatform

/// Right column: full, type-specific preview of the selected item, plus a
/// metadata panel (source app, timestamp, size, char/word count).
struct ClipboardItemPreviewView: View {
    let item: ClipboardItem?

    var body: some View {
        if let item {
            ScrollView {
                VStack(alignment: .leading, spacing: DTSpace.lg) {
                    preview(for: item)
                    metadata(for: item)
                    actions(for: item)
                }
                .padding(DTSpace.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        VStack(spacing: DTSpace.sm) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(DTTypography.emptyStateGlyph)
                .foregroundStyle(DTColor.textSecondary)
            Text("Select an item to preview it.")
                .font(DTTypography.body)
                .foregroundStyle(DTColor.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Type previews

    @ViewBuilder
    private func preview(for item: ClipboardItem) -> some View {
        switch item.type {
        case .plainText:
            Text(item.content)
                .font(DTTypography.monospacedBody)
                .foregroundStyle(DTColor.textPrimary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        case .url:
            previewURL(item)
        case .filePath:
            previewFile(item)
        case .image:
            previewImage(item)
        case .color:
            previewColor(item)
        }
    }

    private func previewURL(_ item: ClipboardItem) -> some View {
        VStack(alignment: .leading, spacing: DTSpace.sm) {
            HStack(spacing: DTSpace.sm) {
                Image(systemName: "link")
                    .foregroundStyle(DTColor.accent)
                Text(item.content)
                    .font(DTTypography.body)
                    .foregroundStyle(DTColor.accent)
                    .lineLimit(3)
            }
            if let url = URL(string: item.content) {
                Button("Open in browser") {
                    NSWorkspace.shared.open(url)
                }
                .controlSize(.small)
            }
        }
    }

    private func previewFile(_ item: ClipboardItem) -> some View {
        let url = URL(fileURLWithPath: item.content)
        return VStack(alignment: .leading, spacing: DTSpace.sm) {
            HStack(spacing: DTSpace.sm) {
                Image(systemName: "doc")
                    .foregroundStyle(DTColor.accent)
                Text(url.lastPathComponent)
                    .font(DTTypography.body)
                    .foregroundStyle(DTColor.textPrimary)
            }
            Text(url.path)
                .font(DTTypography.caption.monospaced())
                .foregroundStyle(DTColor.textSecondary)
                .lineLimit(3)
                .textSelection(.enabled)
            Button("Show in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([url])
            }
            .controlSize(.small)
        }
    }

    private func previewImage(_ item: ClipboardItem) -> some View {
        VStack(alignment: .leading, spacing: DTSpace.sm) {
            if let image = item.nsImage {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 240)
                    .clipShape(RoundedRectangle(cornerRadius: DTRadius.md, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: DTRadius.md, style: .continuous)
                            .stroke(DTColor.border, lineWidth: 0.5)
                    )
            } else {
                Text("Image unavailable.")
                    .font(DTTypography.caption)
                    .foregroundStyle(DTColor.textSecondary)
            }
        }
    }

    private func previewColor(_ item: ClipboardItem) -> some View {
        VStack(alignment: .leading, spacing: DTSpace.sm) {
            if let color = item.nsColor {
                RoundedRectangle(cornerRadius: DTRadius.md, style: .continuous)
                    .fill(Color(nsColor: color))
                    .frame(height: 120)
                    .overlay(
                        RoundedRectangle(cornerRadius: DTRadius.md, style: .continuous)
                            .stroke(DTColor.border, lineWidth: 0.5)
                    )
            }
            Text(item.content)
                .font(DTTypography.monospacedBody)
                .foregroundStyle(DTColor.textPrimary)
                .textSelection(.enabled)
        }
    }

    // MARK: - Metadata

    private func metadata(for item: ClipboardItem) -> some View {
        VStack(alignment: .leading, spacing: DTSpace.xs) {
            if let app = appName(for: item) {
                metaRow(label: "From", value: app)
            }
            metaRow(label: "Copied", value: relativeDate(item.timestamp))
            if item.type == .plainText {
                metaRow(label: "Characters", value: "\(item.content.count)")
                metaRow(label: "Words", value: "\(wordCount(item.content))")
            }
            if item.type == .image, let size = item.imagePixelSize() {
                metaRow(label: "Size", value: "\(Int(size.width)) × \(Int(size.height)) px")
            }
        }
        .padding(DTSpace.md)
        .background(
            RoundedRectangle(cornerRadius: DTRadius.md, style: .continuous)
                .fill(DTColor.surface)
        )
    }

    private func actions(for item: ClipboardItem) -> some View {
        VStack(alignment: .leading, spacing: DTSpace.xs) {
            if item.isPinned {
                Label("Pinned — survives restart", systemImage: "pin.fill")
                    .font(DTTypography.caption)
                    .foregroundStyle(DTColor.accent)
            } else {
                Label("Not pinned — memory only", systemImage: "circle.dashed")
                    .font(DTTypography.caption)
                    .foregroundStyle(DTColor.textSecondary)
            }
        }
    }

    private func metaRow(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(DTTypography.caption)
                .foregroundStyle(DTColor.textSecondary)
            Spacer(minLength: 0)
            Text(value)
                .font(DTTypography.caption)
                .foregroundStyle(DTColor.textPrimary)
        }
    }

    private func appName(for item: ClipboardItem) -> String? {
        guard let bundleID = item.sourceBundleID else { return nil }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            return bundleID
        }
        if let bundle = Bundle(url: url),
           let name = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String,
           !name.isEmpty {
            return name
        }
        return url.deletingPathExtension().lastPathComponent
    }

    private func relativeDate(_ date: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f.localizedString(for: date, relativeTo: Date())
    }

    private func wordCount(_ text: String) -> Int {
        var count = 0
        text.enumerateSubstrings(in: text.startIndex..<text.endIndex, options: [.byWords]) { _, _, _, _ in
            count += 1
        }
        return count
    }
}
