import SwiftUI
import AppKit
import DropThingsCore
import DropThingsDesignSystem
import DropThingsPlatform

/// List layout: one row per item, dense and scannable. Shares the same
/// selection + drag contract as the grid layout so the two are
/// interchangeable from the header toggle.
struct ShelfListView: View {
    @ObservedObject var module: FileShelfModule
    let items: [FileShelfItem]

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(items) { item in
                    ShelfListRow(item: item, module: module)
                    if item.id != items.last?.id {
                        Divider().padding(.leading, DTSpace.xl + DTSpace.md)
                    }
                }
            }
        }
    }
}

/// Grid layout: cards with a large thumbnail on top, name + badge below.
/// Better when the shelf holds mostly images.
struct ShelfGridView: View {
    @ObservedObject var module: FileShelfModule
    let items: [FileShelfItem]

    private let columns = [GridItem(.adaptive(minimum: 96), spacing: DTSpace.md)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: DTSpace.md) {
                ForEach(items) { item in
                    ShelfGridCard(item: item, module: module)
                }
            }
            .padding(DTSpace.md)
        }
    }
}

// MARK: - List row

private struct ShelfListRow: View {
    let item: FileShelfItem
    @ObservedObject var module: FileShelfModule

    private var isSelected: Bool { module.selectedItemIDs.contains(item.id) }

    var body: some View {
        HStack(spacing: DTSpace.sm) {
            ShelfThumbnail(item: item, edge: 32)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: DTSpace.xs) {
                    Text(item.displayName)
                        .font(DTTypography.body)
                        .lineLimit(1)
                    ShelfFileTypeBadge(label: item.fileTypeLabel)
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
            Spacer(minLength: 0)
            removeButton
        }
        .padding(.horizontal, DTSpace.md)
        .padding(.vertical, DTSpace.xs)
        .background(selectionBackground)
        .overlay(alignment: .leading) { selectionBar }
        .contentShape(Rectangle())
        .onTapGesture {
            let mods = NSEvent.modifierFlags
            module.handleSelect(id: item.id, command: mods.contains(.command), shift: mods.contains(.shift))
        }
        .onDrag { module.dragItemProviderForDrag(from: item) }
        .contextMenu { contextMenu }
    }

    private var removeButton: some View {
        Button {
            module.removeItem(id: item.id)
        } label: {
            Image(systemName: "xmark").font(DTTypography.badgeButton)
        }
        .buttonStyle(.borderless)
        .controlSize(.small)
        .help("Remove from shelf")
    }

    @ViewBuilder
    private var selectionBackground: some View {
        if isSelected { DTColor.accent.opacity(0.15) } else { Color.clear }
    }

    @ViewBuilder
    private var selectionBar: some View {
        if isSelected { Rectangle().fill(DTColor.accent).frame(width: 3) }
    }

    @ViewBuilder
    private var contextMenu: some View {
        if item.fileURL != nil {
            Button("Reveal in Finder") { module.revealInFinder(item) }
            Button("Copy Path") { module.copyPath(item) }
            Divider()
        }
        Button(item.isPinned ? "Unpin" : "Pin") { module.setPinned(item.id, pinned: !item.isPinned) }
        Divider()
        Button("Remove from Shelf", role: .destructive) { module.removeItem(id: item.id) }
    }
}

// MARK: - Grid card

private struct ShelfGridCard: View {
    let item: FileShelfItem
    @ObservedObject var module: FileShelfModule

    private var isSelected: Bool { module.selectedItemIDs.contains(item.id) }

    var body: some View {
        VStack(spacing: DTSpace.xs) {
            ShelfThumbnail(item: item, edge: 64)
            HStack(spacing: DTSpace.xxs) {
                Text(item.displayName)
                    .font(DTTypography.caption)
                    .lineLimit(1)
            }
            ShelfFileTypeBadge(label: item.fileTypeLabel)
        }
        .frame(width: 96)
        .padding(DTSpace.xs)
        .background(isSelected ? DTColor.accent.opacity(0.15) : DTColor.surfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: DTRadius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DTRadius.lg, style: .continuous)
                .stroke(isSelected ? DTColor.accent : DTColor.border, lineWidth: isSelected ? 2 : 0.5)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            let mods = NSEvent.modifierFlags
            module.handleSelect(id: item.id, command: mods.contains(.command), shift: mods.contains(.shift))
        }
        .onDrag { module.dragItemProviderForDrag(from: item) }
        .contextMenu {
            if item.fileURL != nil {
                Button("Reveal in Finder") { module.revealInFinder(item) }
                Button("Copy Path") { module.copyPath(item) }
                Divider()
            }
            Button(item.isPinned ? "Unpin" : "Pin") { module.setPinned(item.id, pinned: !item.isPinned) }
            Divider()
            Button("Remove from Shelf", role: .destructive) { module.removeItem(id: item.id) }
        }
    }
}
