import AppKit
import SwiftUI
import DropThingsCore
import DropThingsDesignSystem
import DropThingsPlatform

/// Floating panel for the Clipboard History module. Shows a searchable list
/// of recent clipboard items and lets the user copy one back to the pasteboard.
final class ClipboardHistoryPanelController {
    private var panel: NSPanel?
    private weak var module: ClipboardHistoryModule?

    init(module: ClipboardHistoryModule) {
        self.module = module
    }

    func show() {
        if panel == nil {
            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 420, height: 360),
                styleMask: [.titled, .closable, .nonactivatingPanel, .resizable],
                backing: .buffered,
                defer: false
            )
            panel.title = "Clipboard History"
            panel.level = .floating
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            panel.isReleasedWhenClosed = false
            panel.minSize = NSSize(width: 320, height: 240)
            panel.contentView = NSHostingView(rootView: AnyView(EmptyView()))
            self.panel = panel
        }
        refreshContent()
        panel?.center()
        panel?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func hide() {
        panel?.orderOut(nil)
    }

    func refreshContent() {
        guard let module, let panel else { return }
        let root = AnyView(
            ClipboardHistoryPanelView(module: module)
                .frame(minWidth: 320, minHeight: 240)
        )
        (panel.contentView as? NSHostingView<AnyView>)?.rootView = root
    }
}

struct ClipboardHistoryPanelView: View {
    @ObservedObject var module: ClipboardHistoryModule
    @State private var searchText: String = ""

    private var filteredItems: [ClipboardItem] {
        if searchText.isEmpty { return module.items }
        return module.items.filter {
            $0.displayTitle.localizedCaseInsensitiveContains(searchText)
                || $0.displaySubtitle.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: DTSpace.sm) {
            TextField("Search history", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, DTSpace.md)
                .padding(.top, DTSpace.sm)

            if filteredItems.isEmpty {
                Spacer()
                Text("No clipboard history yet.")
                    .font(DTTypography.caption)
                    .foregroundStyle(DTColor.textSecondary)
                Spacer()
            } else {
                List(filteredItems) { item in
                    ClipboardItemRow(item: item, onCopy: {
                        module.copyToPasteboard(item)
                    }, onTogglePin: {
                        module.togglePin(item.id)
                    }, onToggleFavorite: {
                        module.toggleFavorite(item.id)
                    }, onRemove: {
                        module.remove(item.id)
                    })
                }
                .listStyle(.plain)
            }

            HStack {
                Text("\(module.items.count) item\(module.items.count == 1 ? "" : "s")")
                    .font(DTTypography.caption)
                    .foregroundStyle(DTColor.textSecondary)
                Spacer()
                Button("Clear unpinned") { module.clearUnpinned() }
                    .controlSize(.small)
                    .disabled(module.items.filter { !$0.isPinned }.isEmpty)
            }
            .padding(.horizontal, DTSpace.md)
            .padding(.bottom, DTSpace.sm)
        }
        .background(DTColor.background)
    }
}

private struct ClipboardItemRow: View {
    let item: ClipboardItem
    let onCopy: () -> Void
    let onTogglePin: () -> Void
    let onToggleFavorite: () -> Void
    let onRemove: () -> Void

    var body: some View {
        Button {
            onCopy()
        } label: {
            HStack(spacing: DTSpace.sm) {
                Image(systemName: iconName)
                    .foregroundStyle(DTColor.accent)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: DTSpace.xxs) {
                    Text(item.displayTitle)
                        .font(DTTypography.body)
                        .lineLimit(1)
                    Text(item.displaySubtitle)
                        .font(DTTypography.caption)
                        .foregroundStyle(DTColor.textSecondary)
                        .lineLimit(1)
                }
                Spacer()
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
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Copy to clipboard") { onCopy() }
            Button(item.isPinned ? "Unpin" : "Pin") { onTogglePin() }
            Button(item.isFavorite ? "Unfavorite" : "Favorite") { onToggleFavorite() }
            Button("Remove", role: .destructive) { onRemove() }
        }
    }

    private var iconName: String {
        switch item.type {
        case .plainText: return "text.quote"
        case .url: return "link"
        case .filePath: return "doc"
        }
    }
}
