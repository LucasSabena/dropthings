import AppKit
import SwiftUI
import DropThingsCore
import DropThingsDesignSystem
import DropThingsPlatform

/// The three top-level sections of the clipboard panel.
enum ClipboardTab: Hashable, CaseIterable {
    case history
    case pinned
    case emoji

    var title: String {
        switch self {
        case .history: return "History"
        case .pinned: return "Pinned"
        case .emoji: return "Emojis"
        }
    }

    var systemImage: String {
        switch self {
        case .history: return "clock"
        case .pinned: return "pin"
        case .emoji: return "face.smiling"
        }
    }
}

enum ClipboardContentFilter: String, Hashable, CaseIterable {
    case all
    case text
    case images
    case colors
    case files
    case links

    var title: String {
        switch self {
        case .all: return "All"
        case .text: return "Text"
        case .images: return "Images"
        case .colors: return "Colors"
        case .files: return "Files"
        case .links: return "Links"
        }
    }

    var systemImage: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .text: return "text.quote"
        case .images: return "photo"
        case .colors: return "paintpalette"
        case .files: return "folder"
        case .links: return "link"
        }
    }

    func includes(_ item: ClipboardItem) -> Bool {
        switch self {
        case .all: return true
        case .text: return item.type == .plainText
        case .images: return item.type == .image || item.type == .video
        case .colors: return item.type == .color
        case .files: return [.filePath, .folder, .video, .audio].contains(item.type)
        case .links: return item.type == .url
        }
    }
}

/// Root panel: a tab bar on top, then a search field, then the 2-column body.
/// Keyboard navigation is installed globally so arrows/Enter/⌘1-3/Esc work even
/// while the search field has focus (mirrors the CommandPalette monitor pattern).
struct ClipboardHistoryPanelView: View {
    @ObservedObject var module: ClipboardHistoryModule
    let onClose: () -> Void

    @State private var selectedTab: ClipboardTab = .history
    @State private var searchText: String = ""
    @State private var selectedID: UUID?
    @State private var selectedEmoji: EmojiEntry?
    @State private var contentFilter: ClipboardContentFilter = .all
    @State private var pasteHint: PasteHint?
    @State private var eventMonitor: Any?
    @FocusState private var searchFocused: Bool

    private struct PasteHint: Equatable {
        let message: String
        let style: InlineAlertStyle
    }

    var body: some View {
        VStack(spacing: 0) {
            tabBar
            Divider()
            searchBar
            if selectedTab != .emoji {
                contentFilterBar
            }
            Divider()
            content
                .background(DTColor.background)
            if let hint = pasteHint {
                InlineAlert(style: hint.style, message: hint.message)
                    .padding(.horizontal, DTSpace.md)
                    .padding(.vertical, DTSpace.xs)
                Divider()
            }
            footer
        }
        .frame(minWidth: 540, minHeight: 320)
        .background(DTColor.background)
        .onAppear { installMonitor(); searchFocused = true }
        .onDisappear { removeMonitor() }
    }

    // MARK: - Tab bar

    private var tabBar: some View {
        HStack(spacing: DTSpace.xs) {
            ForEach(ClipboardTab.allCases, id: \.self) { tab in
                Button {
                    selectTab(tab)
                } label: {
                    HStack(spacing: DTSpace.xs) {
                        Image(systemName: tab.systemImage)
                            .font(DTTypography.badgeButton)
                        Text(tab.title)
                            .font(DTTypography.caption.weight(selectedTab == tab ? .semibold : .regular))
                    }
                    .foregroundStyle(selectedTab == tab ? DTColor.textPrimary : DTColor.textSecondary)
                    .padding(.horizontal, DTSpace.md)
                    .padding(.vertical, DTSpace.xs)
                    .background(
                        RoundedRectangle(cornerRadius: DTRadius.sm, style: .continuous)
                            .fill(selectedTab == tab ? DTColor.surfaceRaised : Color.clear)
                    )
                }
                .buttonStyle(.borderless)
            }
            Spacer()
        }
        .padding(.horizontal, DTSpace.md)
        .padding(.vertical, DTSpace.sm)
        .background(DTColor.background)
    }

    // MARK: - Search

    private var searchBar: some View {
        HStack(spacing: DTSpace.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(DTColor.textSecondary)
            TextField(searchPlaceholder, text: $searchText)
                .textFieldStyle(.plain)
                .focused($searchFocused)
                .onChange(of: searchText) { _, _ in resetSelection() }
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                    resetSelection()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(DTColor.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(DTSpace.sm)
        .background(DTColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: DTRadius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DTRadius.md, style: .continuous)
                .strokeBorder(DTColor.border, lineWidth: 0.5)
        )
        .padding(.horizontal, DTSpace.md)
        .padding(.vertical, DTSpace.sm)
    }

    private var searchPlaceholder: String {
        switch selectedTab {
        case .history, .pinned: return "Search history"
        case .emoji: return "Search emojis"
        }
    }

    private var contentFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DTSpace.xs) {
                ForEach(ClipboardContentFilter.allCases, id: \.self) { filter in
                    Button {
                        contentFilter = filter
                        resetSelection()
                    } label: {
                        Label(filter.title, systemImage: filter.systemImage)
                            .font(DTTypography.caption)
                            .foregroundStyle(contentFilter == filter ? DTColor.textPrimary : DTColor.textSecondary)
                            .padding(.horizontal, DTSpace.sm)
                            .padding(.vertical, DTSpace.xs)
                            .background(
                                RoundedRectangle(cornerRadius: DTRadius.sm, style: .continuous)
                                    .fill(contentFilter == filter ? DTColor.surfaceRaised : Color.clear)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, DTSpace.md)
            .padding(.bottom, DTSpace.sm)
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch selectedTab {
        case .history, .pinned:
            twoColumnLayout(items: filteredItems)
        case .emoji:
            EmojiTabView(
                query: searchText,
                selection: $selectedEmoji,
                onPick: { emoji in handleEmojiPick(emoji) }
            )
        }
    }

    private func twoColumnLayout(items: [ClipboardItem]) -> some View {
        HStack(spacing: 0) {
            ClipboardItemListView(
                items: items,
                selectedID: $selectedID,
                onSelect: { id in selectedID = id },
                onCopy: { item in handleCopy(item) },
                onPaste: { item in handlePaste(item) },
                onTogglePin: { module.togglePin($0.id) },
                onToggleFavorite: { module.toggleFavorite($0.id) },
                onRemove: { module.remove($0.id) }
            )
            .frame(width: 310)
            Divider()
            ClipboardItemPreviewView(
                item: items.first(where: { $0.id == selectedID }) ?? items.first,
                onCopy: { handleCopy($0) },
                onPaste: { handlePaste($0) },
                onTogglePin: { module.togglePin($0.id) },
                onRemove: { module.remove($0.id) }
            )
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Text(footerLabel)
                .font(DTTypography.caption)
                .foregroundStyle(DTColor.textSecondary)
            Spacer()
            if selectedTab != .emoji {
                Button("Clear unpinned") { module.clearUnpinned() }
                    .controlSize(.small)
                    .disabled(module.items.filter { !$0.isPinned }.isEmpty)
            }
        }
        .padding(.horizontal, DTSpace.md)
        .padding(.vertical, DTSpace.sm)
    }

    private var footerLabel: String {
        switch selectedTab {
        case .history:
            let n = filteredItems.count
            return "\(n) item\(n == 1 ? "" : "s")"
        case .pinned:
            let n = filteredItems.count
            return "\(n) pinned"
        case .emoji:
            return "↑↓ navigate · ↩ copy/paste · ⌘1-3 tabs · ⎋ close"
        }
    }

    // MARK: - Derived data

    private var filteredItems: [ClipboardItem] {
        let base: [ClipboardItem]
        switch selectedTab {
        case .history: base = module.items
        case .pinned: base = module.items.filter { $0.isPinned }
        case .emoji: base = []
        }
        let typed = base.filter(contentFilter.includes)
        guard !searchText.isEmpty else { return typed }
        return typed.filter {
            $0.displayTitle.localizedCaseInsensitiveContains(searchText)
                || $0.displaySubtitle.localizedCaseInsensitiveContains(searchText)
        }
    }

    // MARK: - Actions

    private func selectTab(_ tab: ClipboardTab) {
        selectedTab = tab
        resetSelection()
    }

    private func resetSelection() {
        selectedID = filteredItems.first?.id
        selectedEmoji = nil
        pasteHint = nil
    }

    private func handleCopy(_ item: ClipboardItem) {
        module.copyItem(item)
        showHint("Copied to clipboard.", style: .info)
    }

    private func handlePaste(_ item: ClipboardItem) {
        let result = module.pasteOrCopy(item)
        switch result {
        case .pasted:
            onClose()
        case .copiedOnly:
            showHint("Copied. Press ⌘V to paste.", style: .info)
        case .needsAccessibility:
            showHint("Grant Accessibility in System Settings to paste with Enter.", style: .warning)
        }
    }

    private func handleEmojiPick(_ emoji: EmojiEntry) {
        let item = ClipboardItem(type: .plainText, content: emoji.glyph)
        if module.settings.pasteOnEnter {
            let result = module.pasteOrCopy(item)
            if result == .pasted { onClose() }
        } else {
            module.copyItem(item)
            showHint("Copied \(emoji.glyph).", style: .info)
        }
    }

    private func showHint(_ message: String, style: InlineAlertStyle) {
        pasteHint = PasteHint(message: message, style: style)
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_500_000_000)
            if pasteHint?.message == message { pasteHint = nil }
        }
    }

    // MARK: - Keyboard monitor

    private func installMonitor() {
        selectedID = filteredItems.first?.id
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard event.window?.isKeyWindow == true else { return event }
            if handleKeyEvent(event) { return nil }
            return event
        }
    }

    private func removeMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    /// Returns `true` when the event was consumed.
    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        // ⌘1 / ⌘2 / ⌘3 switch tabs.
        if event.modifierFlags.contains(.command) {
            switch event.keyCode {
            case 18: selectTab(.history); return true   // 1
            case 19: selectTab(.pinned); return true    // 2
            case 20: selectTab(.emoji); return true     // 3
            default: return false
            }
        }

        switch event.keyCode {
        case 53:        // Escape
            onClose()
            return true
        case 125:       // Down
            moveSelection(by: 1)
            return true
        case 126:       // Up
            moveSelection(by: -1)
            return true
        case 36, 76:    // Return / Enter
            activateSelected()
            return true
        default:
            // Bare "c" copies the selected history item.
            if selectedTab != .emoji,
               let chars = event.characters,
               chars.lowercased() == "c",
               !event.modifierFlags.contains(.command) {
                if let id = selectedID, let item = filteredItems.first(where: { $0.id == id }) {
                    handleCopy(item)
                    return true
                }
            }
            return false
        }
    }

    private func moveSelection(by delta: Int) {
        switch selectedTab {
        case .history, .pinned:
            moveItemSelection(by: delta)
        case .emoji:
            moveEmojiSelection(by: delta)
        }
    }

    private func moveItemSelection(by delta: Int) {
        let items = filteredItems
        guard !items.isEmpty else { return }
        let current = items.firstIndex(where: { $0.id == selectedID }) ?? -1
        let next = (current + delta + items.count) % items.count
        selectedID = items[next].id
    }

    private func moveEmojiSelection(by delta: Int) {
        let all = EmojiCatalog.search(searchText)
        guard !all.isEmpty else { return }
        let current: Int
        if let sel = selectedEmoji {
            current = all.firstIndex(of: sel) ?? -1
        } else {
            current = -1
        }
        let next = (current + delta + all.count) % all.count
        selectedEmoji = all[next]
    }

    private func activateSelected() {
        switch selectedTab {
        case .history, .pinned:
            if let id = selectedID, let item = filteredItems.first(where: { $0.id == id }) {
                handlePaste(item)
            }
        case .emoji:
            if let emoji = selectedEmoji {
                handleEmojiPick(emoji)
            }
        }
    }
}
