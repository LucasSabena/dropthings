import AppKit
import SwiftUI
import DropThingsCore
import DropThingsDesignSystem
import DropThingsPlatform

/// Right column: full, type-specific preview of the selected item, plus a
/// metadata panel (source app, timestamp, size, char/word count).
struct ClipboardItemPreviewView: View {
    let item: ClipboardItem?
    let onCopy: (ClipboardItem) -> Void
    let onPaste: (ClipboardItem) -> Void
    let onTogglePin: (ClipboardItem) -> Void
    let onRemove: (ClipboardItem) -> Void

    var body: some View {
        if let item {
            ScrollView {
                VStack(alignment: .leading, spacing: DTSpace.lg) {
                    actionBar(for: item)
                    preview(for: item)
                    metadata(for: item)
                    persistenceStatus(for: item)
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
            previewFileBacked(item)
        case .folder:
            previewFileBacked(item)
        case .image:
            previewImage(item)
        case .video, .audio:
            previewFileBacked(item)
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

    @ViewBuilder
    private func previewFileBacked(_ item: ClipboardItem) -> some View {
        if let url = item.fileURL {
            let info = FileContentInfo.inspect(url)
            VStack(alignment: .leading, spacing: DTSpace.sm) {
                HStack(spacing: DTSpace.sm) {
                    Image(systemName: info.kind.systemImageName)
                        .foregroundStyle(DTColor.accent)
                    VStack(alignment: .leading, spacing: DTSpace.xxs) {
                        Text(url.lastPathComponent)
                            .font(DTTypography.body.weight(.semibold))
                        Text(info.kind.displayName)
                            .font(DTTypography.caption)
                            .foregroundStyle(DTColor.textSecondary)
                    }
                }
                QuickLookPreview(url: url)
                    .frame(minHeight: DTSize.previewLarge * 2)
                    .clipShape(RoundedRectangle(cornerRadius: DTRadius.md, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: DTRadius.md, style: .continuous)
                            .strokeBorder(DTColor.border, lineWidth: 0.5)
                    )
                Text(url.path)
                    .font(DTTypography.caption.monospaced())
                    .foregroundStyle(DTColor.textSecondary)
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
            }
        } else {
            unavailablePreview("File is no longer available.")
        }
    }

    private func unavailablePreview(_ message: String) -> some View {
        VStack(spacing: DTSpace.sm) {
            Image(systemName: "questionmark.folder")
                .font(DTTypography.emptyStateGlyph)
                .foregroundStyle(DTColor.textSecondary)
            Text(message)
                .font(DTTypography.caption)
                .foregroundStyle(DTColor.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: DTSize.previewLarge)
    }

    @ViewBuilder
    private func previewImage(_ item: ClipboardItem) -> some View {
        if let url = item.fileURL {
            QuickLookPreview(url: url)
                .frame(minHeight: DTSize.previewLarge * 2)
                .clipShape(RoundedRectangle(cornerRadius: DTRadius.md, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: DTRadius.md, style: .continuous)
                        .strokeBorder(DTColor.border, lineWidth: 0.5)
                )
        } else {
            VStack(alignment: .leading, spacing: DTSpace.sm) {
                if let image = item.nsImage {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: DTSize.previewLarge * 2)
                        .clipShape(RoundedRectangle(cornerRadius: DTRadius.md, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: DTRadius.md, style: .continuous)
                                .stroke(DTColor.border, lineWidth: 0.5)
                        )
                } else {
                    unavailablePreview("Image unavailable.")
                }
            }
        }
    }

    private func previewColor(_ item: ClipboardItem) -> some View {
        VStack(alignment: .leading, spacing: DTSpace.md) {
            if let color = item.nsColor {
                RoundedRectangle(cornerRadius: DTRadius.lg, style: .continuous)
                    .fill(Color(nsColor: color))
                    .frame(height: DTSize.previewLarge)
                    .overlay(
                        RoundedRectangle(cornerRadius: DTRadius.lg, style: .continuous)
                            .stroke(DTColor.border, lineWidth: 0.5)
                    )
                colorValues(color: color, fallbackHex: item.content)
            } else {
                unavailablePreview("Color unavailable.")
            }
        }
    }

    private func colorValues(color: NSColor, fallbackHex: String) -> some View {
        let rgb = color.usingColorSpace(.sRGB)
        let r = Int(((rgb?.redComponent ?? 0) * 255).rounded())
        let g = Int(((rgb?.greenComponent ?? 0) * 255).rounded())
        let b = Int(((rgb?.blueComponent ?? 0) * 255).rounded())
        return VStack(spacing: DTSpace.xs) {
            colorValueRow(label: "HEX", value: fallbackHex)
            colorValueRow(label: "RGB", value: ColorCopyFormat.rgb.string(r: r, g: g, b: b))
            colorValueRow(label: "HSL", value: ColorCopyFormat.hsl.string(r: r, g: g, b: b))
        }
        .padding(DTSpace.md)
        .background(
            RoundedRectangle(cornerRadius: DTRadius.md, style: .continuous)
                .fill(DTColor.surface)
        )
    }

    private func colorValueRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(DTTypography.caption.weight(.semibold))
                .foregroundStyle(DTColor.textSecondary)
            Spacer()
            Text(value)
                .font(DTTypography.caption.monospaced())
                .foregroundStyle(DTColor.textPrimary)
                .textSelection(.enabled)
        }
    }

    // MARK: - Actions

    private func actionBar(for item: ClipboardItem) -> some View {
        HStack(spacing: DTSpace.sm) {
            Button { onPaste(item) } label: {
                Label("Paste", systemImage: "arrow.turn.down.left")
            }
            .keyboardShortcut(.return, modifiers: [])
            Button { onCopy(item) } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }
            Button { onTogglePin(item) } label: {
                Label(item.isPinned ? "Unpin" : "Pin", systemImage: item.isPinned ? "pin.slash" : "pin")
            }
            if let url = item.fileURL {
                Button { NSWorkspace.shared.activateFileViewerSelecting([url]) } label: {
                    Label("Reveal", systemImage: "folder")
                }
            }
            Spacer(minLength: 0)
            Button(role: .destructive) { onRemove(item) } label: {
                Image(systemName: "trash")
            }
            .help("Remove from history")
        }
        .controlSize(.small)
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
                metaRow(label: "Dimensions", value: "\(Int(size.width)) × \(Int(size.height)) px")
            }
            if let info = item.fileInfo {
                metaRow(label: "Kind", value: info.kind.displayName)
                if let bytes = info.byteCount {
                    metaRow(label: "Size", value: ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file))
                }
                if let modified = info.modifiedAt {
                    metaRow(label: "Modified", value: relativeDate(modified))
                }
            }
        }
        .padding(DTSpace.md)
        .background(
            RoundedRectangle(cornerRadius: DTRadius.md, style: .continuous)
                .fill(DTColor.surface)
        )
    }

    private func persistenceStatus(for item: ClipboardItem) -> some View {
        VStack(alignment: .leading, spacing: DTSpace.xs) {
            if item.isPinned {
                Label("Pinned", systemImage: "pin.fill")
                    .font(DTTypography.caption)
                    .foregroundStyle(DTColor.accent)
            } else {
                Label("Temporary history item", systemImage: "clock")
                    .font(DTTypography.caption)
                    .foregroundStyle(DTColor.textPrimary)
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
