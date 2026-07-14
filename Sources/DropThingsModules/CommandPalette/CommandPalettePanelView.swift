import AppKit
import SwiftUI
import DropThingsDesignSystem
import DropThingsPlatform

struct CommandPalettePanelView: View {
    @ObservedObject var coordinator: PaletteQueryCoordinator
    let onClose: () -> Void

    @State private var selection: String?
    @State private var eventMonitor: Any?
    @State private var actionsVisible = false
    @FocusState private var searchFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var selectedResult: PaletteResult? {
        coordinator.results.first(where: { $0.id == selection })?.result
    }

    var body: some View {
        VStack(spacing: 0) {
            searchField
            Divider()
            content
            Divider()
            footer
        }
        .background(DTColor.background)
        .overlay(alignment: .center) {
            if actionsVisible, let result = selectedResult {
                actionMenu(for: result)
            }
        }
        .onAppear {
            installEventMonitor()
            selection = coordinator.results.first?.id
            Task { @MainActor in searchFocused = true }
        }
        .onDisappear { removeEventMonitor() }
        .onChange(of: coordinator.results.map(\.id)) { _, ids in
            selection = PaletteSelection.preserving(currentID: selection, resultIDs: ids)
        }
        .onChange(of: coordinator.query) { _, _ in actionsVisible = false }
    }

    private var searchField: some View {
        HStack(spacing: DTSpace.md) {
            Image(systemName: "magnifyingglass")
                .font(DTTypography.windowTitle)
                .foregroundStyle(DTColor.textSecondary)
            TextField("Search apps, files, commands, or calculate…", text: $coordinator.query)
                .textFieldStyle(.plain)
                .font(DTTypography.windowTitle)
                .focused($searchFocused)
                .accessibilityLabel("Command Palette search")
            if coordinator.loadingProviders.contains(.files) {
                ProgressView().controlSize(.small).help("Searching Spotlight")
            }
            if !coordinator.query.isEmpty {
                Button {
                    coordinator.query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(DTColor.textSecondary)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, DTSpace.lg)
        .padding(.vertical, DTSpace.md)
    }

    @ViewBuilder
    private var content: some View {
        if coordinator.results.isEmpty {
            VStack(spacing: DTSpace.sm) {
                Spacer()
                Image(systemName: coordinator.loadingProviders.isEmpty ? "magnifyingglass" : "clock")
                    .font(DTTypography.emptyStateGlyph)
                    .foregroundStyle(DTColor.textTertiary)
                Text(emptyMessage)
                    .font(DTTypography.body)
                    .foregroundStyle(DTColor.textSecondary)
                Spacer()
            }
            .frame(maxWidth: .infinity)
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: DTSpace.xs) {
                        ForEach(Array(coordinator.results.enumerated()), id: \.element.id) { index, ranked in
                            CommandPaletteResultRow(
                                result: ranked.result,
                                index: index,
                                count: coordinator.results.count,
                                selected: ranked.id == selection
                            ) {
                                selection = ranked.id
                                executePrimary(ranked.result)
                            }
                            .id(ranked.id)
                        }
                    }
                    .padding(DTSpace.sm)
                }
                .onChange(of: selection) { _, id in
                    if let id {
                        if reduceMotion { proxy.scrollTo(id, anchor: .center) }
                        else { withAnimation(.easeOut(duration: 0.08)) { proxy.scrollTo(id, anchor: .center) } }
                    }
                }
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 0) {
            if let error = coordinator.actionError {
                HStack(spacing: DTSpace.sm) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text(error).lineLimit(1)
                    Spacer()
                }
                .font(DTTypography.caption)
                .foregroundStyle(DTColor.danger)
                .padding(.horizontal, DTSpace.md)
                .padding(.top, DTSpace.sm)
            }
            HStack(spacing: DTSpace.lg) {
                Text("\(coordinator.results.count) result\(coordinator.results.count == 1 ? "" : "s")")
                Spacer()
                Label("Navigate", systemImage: "arrow.up.arrow.down")
                Text("↩ Open")
                Text("⌘K Actions")
                Text("esc Close")
            }
            .font(DTTypography.caption)
            .foregroundStyle(DTColor.textSecondary)
            .padding(.horizontal, DTSpace.md)
            .padding(.vertical, DTSpace.sm)
        }
    }

    private func actionMenu(for result: PaletteResult) -> some View {
        VStack(alignment: .leading, spacing: DTSpace.xs) {
            Text("Actions for \(result.title)")
                .font(DTTypography.sectionTitle)
                .padding(.bottom, DTSpace.xs)
            ForEach(result.actions) { action in
                Button {
                    execute(action, for: result)
                } label: {
                    HStack {
                        Label(action.title, systemImage: action.symbolName)
                        Spacer()
                        if let hint = action.shortcutHint { Text(hint).foregroundStyle(DTColor.textSecondary) }
                    }
                }
                .buttonStyle(.plain)
                .padding(.vertical, DTSpace.xs)
            }
        }
        .padding(DTSpace.md)
        .frame(width: 300)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: DTRadius.lg, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: DTRadius.lg).strokeBorder(DTColor.border))
        .shadow(radius: DTRadius.lg)
        .accessibilityElement(children: .contain)
    }

    private var emptyMessage: String {
        if !coordinator.loadingProviders.isEmpty { return "Searching…" }
        if coordinator.query.isEmpty { return "Start typing to search your Mac." }
        return "No matching results."
    }

    private func installEventMonitor() {
        guard eventMonitor == nil else { return }
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let handled = handleKey(event)
            return handled ? nil : event
        }
    }

    private func removeEventMonitor() {
        if let eventMonitor { NSEvent.removeMonitor(eventMonitor); self.eventMonitor = nil }
    }

    private func handleKey(_ event: NSEvent) -> Bool {
        let command = event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.command)
        switch event.keyCode {
        case 53:
            if actionsVisible { actionsVisible = false } else { onClose() }
            return true
        case 125: moveSelection(by: 1); return true
        case 126: moveSelection(by: -1); return true
        case 40 where command:
            if selectedResult != nil { actionsVisible.toggle() }
            return true
        case 36, 76:
            guard let result = selectedResult else { return true }
            if command, let alternate = result.actions.first(where: { $0.id == "reveal" || $0.id == "containing-folder" }) {
                execute(alternate, for: result)
            } else {
                executePrimary(result)
            }
            return true
        default: return false
        }
    }

    private func moveSelection(by delta: Int) {
        selection = PaletteSelection.moved(currentID: selection, by: delta, resultIDs: coordinator.results.map(\.id))
    }

    private func executePrimary(_ result: PaletteResult) {
        guard let action = result.primaryAction else { return }
        execute(action, for: result)
    }

    private func execute(_ action: PaletteAction, for result: PaletteResult) {
        actionsVisible = false
        Task {
            if await coordinator.execute(action, for: result) { onClose() }
        }
    }
}

private struct CommandPaletteResultRow: View {
    let result: PaletteResult
    let index: Int
    let count: Int
    let selected: Bool
    let execute: () -> Void

    var body: some View {
        Button(action: execute) {
            HStack(spacing: DTSpace.md) {
                PaletteResultIcon(icon: result.icon, fallback: fallbackSymbol)
                    .frame(width: DTSize.iconButton, height: DTSize.iconButton)
                VStack(alignment: .leading, spacing: DTSpace.xxs) {
                    Text(result.title).font(DTTypography.body).foregroundStyle(DTColor.textPrimary).lineLimit(1)
                    if let subtitle = result.subtitle, !subtitle.isEmpty {
                        Text(subtitle).font(DTTypography.caption).foregroundStyle(DTColor.textSecondary).lineLimit(1)
                    }
                }
                Spacer()
                Text(result.kind.displayName)
                    .font(DTTypography.caption)
                    .foregroundStyle(DTColor.textTertiary)
            }
            .padding(.horizontal, DTSpace.md)
            .padding(.vertical, DTSpace.sm)
            .background(selected ? DTColor.accent.opacity(0.14) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: DTRadius.md, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Primary action: \(result.primaryAction?.title ?? "Open")")
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    private var fallbackSymbol: String {
        switch result.kind {
        case .application: return "app"
        case .command: return "command"
        case .file: return "doc"
        case .folder: return "folder"
        case .calculation: return "equal.circle"
        case .systemAction: return "gearshape"
        case .webSearch: return "globe"
        }
    }

    private var accessibilityLabel: String {
        [result.kind.displayName, result.title, result.subtitle, "\(index + 1) of \(count)"].compactMap { $0 }.joined(separator: ", ")
    }
}

private struct PaletteResultIcon: View {
    let icon: PaletteIcon
    let fallback: String
    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image).resizable().scaledToFit()
            } else {
                Image(systemName: systemName).font(DTTypography.moduleIcon).foregroundStyle(DTColor.textSecondary)
            }
        }
        .task(id: icon) { await loadIcon() }
        .accessibilityHidden(true)
    }

    private var systemName: String {
        if case .system(let name) = icon { return name }
        return fallback
    }

    private func loadIcon() async {
        switch icon {
        case .system: image = nil; return
        case .application(let url):
            await loadWorkspaceIcon(for: url)
        case .file(let url, let isDirectory):
            if !isDirectory,
               let thumbnail = await ThumbnailGenerator.shared.thumbnailAsync(
                   for: url,
                   edge: DTSize.iconButton,
                   scale: NSScreen.main?.backingScaleFactor ?? 2
               ),
               !Task.isCancelled {
                image = thumbnail
                return
            }
            await loadWorkspaceIcon(for: url)
        }
    }

    private func loadWorkspaceIcon(for url: URL) async {
        if let cached = PaletteIconCache.shared.image(for: url) { image = cached; return }
        let path = url.path
        let loaded = await Task.detached(priority: .utility) { NSWorkspace.shared.icon(forFile: path) }.value
        guard !Task.isCancelled else { return }
        PaletteIconCache.shared.insert(loaded, for: url)
        image = loaded
    }
}

@MainActor
private final class PaletteIconCache {
    static let shared = PaletteIconCache()
    private let cache = NSCache<NSURL, NSImage>()

    private init() { cache.countLimit = 256 }
    func image(for url: URL) -> NSImage? { cache.object(forKey: url as NSURL) }
    func insert(_ image: NSImage, for url: URL) { cache.setObject(image, forKey: url as NSURL) }
}
