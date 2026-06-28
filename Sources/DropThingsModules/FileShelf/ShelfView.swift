import SwiftUI
import DropThingsCore
import DropThingsDesignSystem

struct ShelfView: View {
    @ObservedObject var module: FileShelfModule

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
        .background(DTColor.background)
    }

    private var header: some View {
        HStack(spacing: DTSpace.sm) {
            Image(systemName: "tray.and.arrow.down")
                .foregroundStyle(DTColor.accent)
            Text(itemCountLabel)
                .font(DTTypography.body.weight(.semibold))
            Spacer()
            Button {
                module.clearItems()
            } label: {
                Text("Clear")
                    .font(DTTypography.body)
            }
            .disabled(module.items.isEmpty)
            .controlSize(.small)
        }
        .padding(.horizontal, DTSpace.md)
        .padding(.vertical, DTSpace.sm)
    }

    private var itemCountLabel: String {
        let n = module.items.count
        return n == 1 ? "1 item" : "\(n) items"
    }

    @ViewBuilder
    private var content: some View {
        if module.items.isEmpty {
            emptyState
        } else {
            list
        }
    }

    private var emptyState: some View {
        VStack(spacing: DTSpace.sm) {
            Image(systemName: "tray")
                .font(DTTypography.emptyStateGlyph)
                .foregroundStyle(DTColor.textSecondary)
            Text("Drop files, text, or URLs here")
                .font(DTTypography.body)
                .foregroundStyle(DTColor.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(sortedItems) { item in
                    ShelfItemRow(
                        item: item,
                        onRemove: { module.removeItem(id: item.id) },
                        onReveal: { module.revealInFinder(item) },
                        onCopyPath: { module.copyPath(item) },
                        onTogglePin: { module.setPinned(item.id, pinned: !item.isPinned) }
                    )
                    .onDrag {
                        module.dragItemProvider(for: item)
                    }
                    if item.id != sortedItems.last?.id {
                        Divider()
                            .padding(.leading, DTSpace.xl + DTSpace.md)
                    }
                }
            }
        }
    }

    /// Pinned items first, then everything else by `addedAt`. Sorting on
    /// every render is fine for the small list sizes this module deals
    /// with (default cap is 50).
    private var sortedItems: [FileShelfItem] {
        module.items.sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned { return lhs.isPinned }
            return lhs.addedAt < rhs.addedAt
        }
    }
}

private struct ShelfItemRow: View {
    let item: FileShelfItem
    let onRemove: () -> Void
    let onReveal: () -> Void
    let onCopyPath: () -> Void
    let onTogglePin: () -> Void

    var body: some View {
        HStack(spacing: DTSpace.sm) {
            Image(systemName: item.iconName)
                .foregroundStyle(DTColor.accent)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: DTSpace.xs) {
                    Text(item.displayName)
                        .font(DTTypography.body)
                        .lineLimit(1)
                    if item.isPinned {
                        Image(systemName: "pin.fill")
                            .font(DTTypography.badgeLabel)
                            .foregroundStyle(DTColor.accent)
                            .help("Pinned — survives quit")
                    }
                }
                if let path = item.displayPath {
                    Text(path)
                        .font(DTTypography.caption)
                        .foregroundStyle(DTColor.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            Spacer()
            Button {
                onRemove()
            } label: {
                Image(systemName: "xmark")
                    .font(DTTypography.badgeButton)
            }
            .buttonStyle(.borderless)
            .controlSize(.small)
            .help("Remove from shelf")
        }
        .padding(.horizontal, DTSpace.md)
        .padding(.vertical, DTSpace.xs)
        .contentShape(Rectangle())
        .contextMenu {
            if item.fileURL != nil {
                Button("Reveal in Finder") { onReveal() }
                Button("Copy Path") { onCopyPath() }
                Divider()
            }
            Button(item.isPinned ? "Unpin" : "Pin") { onTogglePin() }
            Divider()
            Button("Remove from Shelf", role: .destructive) { onRemove() }
        }
    }
}

struct FileShelfSettingsView: View {
    @ObservedObject var module: FileShelfModule

    var body: some View {
        SettingsSection(
            title: "File Shelf",
            caption: "A floating shelf for files in transit. Drop something here, then pick it up in any app. Pin items to keep them across restarts."
        ) {
            VStack(alignment: .leading, spacing: DTSpace.md) {
                Button {
                    module.togglePanel()
                } label: {
                    Label("Show Shelf", systemImage: "rectangle.stack.badge.plus")
                }
                .controlSize(.regular)

                ShortcutRecorder(
                    title: "Toggle shelf",
                    definition: Binding(
                        get: { module.fileShelfSettings.hotkey },
                        set: { module.setHotkey($0) }
                    )
                )

                Toggle("Show shelf when I shake the mouse", isOn: Binding(
                    get: { module.shakeToShow },
                    set: { module.updateShakeToShow($0) }
                ))

                Stepper(
                    "Maximum items: \(module.itemsLimit)",
                    value: Binding(
                        get: { module.itemsLimit },
                        set: { module.updateItemsLimit($0) }
                    ),
                    in: 1...FileShelfSettings.maxItemsHardLimit
                )

                Toggle("Clear shelf when disabled", isOn: Binding(
                    get: { module.clearOnQuit },
                    set: { module.updateClearOnQuit($0) }
                ))

                if !module.items.isEmpty {
                    summaryRow
                }
            }
        }
    }

    private var summaryRow: some View {
        HStack(spacing: DTSpace.md) {
            Text("\(module.items.count) item(s) on the shelf")
                .font(DTTypography.caption)
                .foregroundStyle(DTColor.textSecondary)
            if module.pinnedCount > 0 {
                Text("· \(module.pinnedCount) pinned")
                    .font(DTTypography.caption)
                    .foregroundStyle(DTColor.accent)
            }
            Spacer()
            if module.pinnedCount > 0 && module.pinnedCount < module.items.count {
                Button("Clear unpinned") {
                    module.clearUnpinned()
                }
                .controlSize(.small)
            }
            Button("Clear all") {
                module.clearItems()
            }
            .controlSize(.small)
        }
    }
}
