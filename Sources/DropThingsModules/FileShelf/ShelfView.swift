import SwiftUI
import AppKit
import DropThingsCore
import DropThingsDesignSystem

struct ShelfView: View {
    @ObservedObject var module: FileShelfModule

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            tabBar
            content
        }
        .background(DTColor.background)
        // Clicking empty space clears the selection, like Finder.
        .onTapGesture(count: 1) {
            let mods = NSEvent.modifierFlags
            if !mods.contains(.command) && !mods.contains(.shift) {
                module.clearSelection()
            }
        }
    }

    private var header: some View {
        HStack(spacing: DTSpace.sm) {
            Image(systemName: "tray.and.arrow.down")
                .foregroundStyle(DTColor.accent)
            Text(itemCountLabel)
                .font(DTTypography.body.weight(.semibold))
            Spacer()
            layoutToggle
            if !module.selectedItemIDs.isEmpty {
                selectionCountBadge
            } else {
                Button {
                    module.clearItems()
                } label: {
                    Text("Clear")
                        .font(DTTypography.body)
                }
                .disabled(module.items.isEmpty)
                .controlSize(.small)
            }
        }
        .padding(.horizontal, DTSpace.md)
        .padding(.vertical, DTSpace.sm)
    }

    private var itemCountLabel: String {
        let n = module.items.count
        return n == 1 ? "1 item" : "\(n) items"
    }

    /// Horizontal scrollable tab bar for switching/adding collections. Kept
    /// compact so it fits the small shelf panel; rename happens via the
    /// context menu on each tab.
    @ViewBuilder
    private var tabBar: some View {
        if module.collections.count > 1 || !module.items.isEmpty || module.collections.first?.name != ShelfCollection.defaultName {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DTSpace.xs) {
                    ForEach(module.collections) { collection in
                        tabChip(collection)
                    }
                    Button {
                        module.addCollection()
                    } label: {
                        Image(systemName: "plus")
                            .font(DTTypography.badgeButton)
                            .frame(width: DTSize.iconButton - 6, height: DTSize.iconButton - 6)
                    }
                    .buttonStyle(.borderless)
                    .help("New collection")
                }
                .padding(.horizontal, DTSpace.md)
                .padding(.vertical, DTSpace.xs)
            }
            Divider()
        }
    }

    @ViewBuilder
    private func tabChip(_ collection: ShelfCollection) -> some View {
        let isActive = collection.id == module.activeCollectionID
        let isRenaming = module.renamingID == collection.id
        Group {
            if isRenaming {
                // Inline rename field; commits on submit/Escape via focus loss.
                RenameField(initial: collection.name) { newName in
                    module.commitRename(newName)
                } onCancel: {
                    module.cancelRename()
                }
                .frame(width: 96)
            } else {
                Button {
                    module.selectCollection(id: collection.id)
                } label: {
                    HStack(spacing: DTSpace.xs) {
                        Text(collection.name)
                            .font(DTTypography.caption.weight(isActive ? .semibold : .regular))
                            .foregroundStyle(isActive ? DTColor.textPrimary : DTColor.textSecondary)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, DTSpace.sm)
                    .padding(.vertical, DTSpace.xxs + 1)
                    .background(
                        RoundedRectangle(cornerRadius: DTRadius.sm, style: .continuous)
                            .fill(isActive ? DTColor.surfaceRaised : Color.clear)
                    )
                }
                .buttonStyle(.borderless)
                .contextMenu {
                    Button("Rename…") { module.beginRename(id: collection.id) }
                    Button("Remove", role: .destructive) {
                        module.selectCollection(id: collection.id)
                        module.removeActiveCollection()
                    }
                }
            }
        }
    }

    /// Compact count of how many items are selected, with a quick action
    /// to clear just the selection (not the items).
    private var selectionCountBadge: some View {
        HStack(spacing: DTSpace.xs) {
            Text("\(module.selectedItemIDs.count) selected")
                .font(DTTypography.caption)
                .foregroundStyle(DTColor.accent)
            Button {
                module.clearSelection()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(DTTypography.badgeButton)
                    .foregroundStyle(DTColor.textSecondary)
            }
            .buttonStyle(.borderless)
            .help("Clear selection")
        }
    }

    @ViewBuilder
    private var layoutToggle: some View {
        // A small segmented control to switch between list and grid. Bound
        // directly to settings so the choice survives across launches.
        Picker("", selection: Binding(
            get: { module.layout },
            set: { module.setLayout($0) }
        )) {
            Image(systemName: "list.bullet").tag(ShelfLayout.list)
            Image(systemName: "square.grid.2x2").tag(ShelfLayout.grid)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .frame(width: 64)
        .help("Switch between list and grid layout")
    }

    @ViewBuilder
    private var content: some View {
        if module.items.isEmpty {
            emptyState
        } else {
            switch module.layout {
            case .list:
                ShelfListView(module: module, items: sortedItems)
            case .grid:
                ShelfGridView(module: module, items: sortedItems)
            }
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

    private var sortedItems: [FileShelfItem] {
        ShelfDisplayOrder.sort(module.items)
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

                layoutPicker

                Toggle("Show shelf when I shake the mouse", isOn: Binding(
                    get: { module.shakeToShow },
                    set: { module.updateShakeToShow($0) }
                ))
                shakeSensitivityPicker

                Toggle("Show shelf when I flick up to the notch", isOn: Binding(
                    get: { module.flickToShow },
                    set: { module.updateFlickToShow($0) }
                ))
                .help("Flick the mouse quickly to the top of the screen to drop the shelf from the menu bar.")

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

    private var layoutPicker: some View {
        Picker("Layout", selection: Binding(
            get: { module.layout },
            set: { module.setLayout($0) }
        )) {
            Text("List").tag(ShelfLayout.list)
            Text("Grid").tag(ShelfLayout.grid)
        }
        .pickerStyle(.segmented)
    }

    @ViewBuilder
    private var shakeSensitivityPicker: some View {
        if module.shakeToShow {
            Picker("Shake sensitivity", selection: Binding(
                get: { module.shakeSensitivity },
                set: { module.setShakeSensitivity($0) }
            )) {
                Text("Low").tag(ShakeSensitivity.low)
                Text("Medium").tag(ShakeSensitivity.medium)
                Text("High").tag(ShakeSensitivity.high)
            }
            .pickerStyle(.segmented)
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

/// Small inline text field used to rename a collection tab. Commits on
/// return, cancels on Escape. Kept private to the shelf surface.
private struct RenameField: View {
    let initial: String
    let onCommit: (String) -> Void
    let onCancel: () -> Void

    @State private var text: String = ""
    @FocusState private var focused: Bool

    var body: some View {
        TextField("Name", text: $text)
            .textFieldStyle(.roundedBorder)
            .font(DTTypography.caption)
            .focused($focused)
            .onSubmit { onCommit(text) }
            .onExitCommand { onCancel() }
            .onAppear {
                text = initial
                focused = true
            }
    }
}
