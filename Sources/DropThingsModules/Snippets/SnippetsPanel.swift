import AppKit
import SwiftUI
import DropThingsCore
import DropThingsDesignSystem
import DropThingsPlatform

/// Floating searchable picker for snippets. Selecting a snippet copies its
/// content to the pasteboard and closes the panel.
final class SnippetsPanelController {
    private var panel: NSPanel?
    private weak var module: SnippetsModule?

    var isVisible: Bool {
        panel?.isVisible ?? false
    }

    init(module: SnippetsModule) {
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
            panel.title = "Snippets"
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
            SnippetsPanelView(module: module)
                .frame(minWidth: 320, minHeight: 240)
        )
        (panel.contentView as? NSHostingView<AnyView>)?.rootView = root
    }
}

struct SnippetsPanelView: View {
    @ObservedObject var module: SnippetsModule
    @State private var searchText: String = ""

    private var filteredSnippets: [Snippet] {
        if searchText.isEmpty { return module.settings.snippets }
        let query = searchText.localizedLowercase
        return module.settings.snippets.filter {
            $0.title.localizedLowercase.contains(query)
                || $0.content.localizedLowercase.contains(query)
                || ($0.keyword?.localizedLowercase.contains(query) ?? false)
        }
    }

    var body: some View {
        VStack(spacing: DTSpace.sm) {
            TextField("Search snippets", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, DTSpace.md)
                .padding(.top, DTSpace.sm)

            if filteredSnippets.isEmpty {
                Spacer()
                Text(module.settings.snippets.isEmpty ? "No snippets yet." : "No matches.")
                    .font(DTTypography.caption)
                    .foregroundStyle(DTColor.textSecondary)
                Spacer()
            } else {
                List(filteredSnippets) { snippet in
                    SnippetRow(snippet: snippet) {
                        module.copyToPasteboard(snippet)
                        module.hidePanel()
                    }
                }
                .listStyle(.plain)
            }

            HStack {
                Text("\(module.settings.snippets.count) snippet\(module.settings.snippets.count == 1 ? "" : "s")")
                    .font(DTTypography.caption)
                    .foregroundStyle(DTColor.textSecondary)
                Spacer()
            }
            .padding(.horizontal, DTSpace.md)
            .padding(.bottom, DTSpace.sm)
        }
        .background(DTColor.background)
    }
}

private struct SnippetRow: View {
    let snippet: Snippet
    let onSelect: () -> Void

    var body: some View {
        Button {
            onSelect()
        } label: {
            HStack(spacing: DTSpace.sm) {
                Image(systemName: "doc.text")
                    .foregroundStyle(DTColor.accent)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: DTSpace.xxs) {
                    Text(snippet.title)
                        .font(DTTypography.body)
                        .lineLimit(1)
                    Text(snippet.contentPreview)
                        .font(DTTypography.caption)
                        .foregroundStyle(DTColor.textSecondary)
                        .lineLimit(1)
                }
                Spacer()
                if let keyword = snippet.keyword {
                    Text(keyword)
                        .font(DTTypography.badgeLabel)
                        .foregroundStyle(DTColor.textSecondary)
                        .padding(.horizontal, DTSpace.xs)
                        .padding(.vertical, DTSpace.xxs)
                        .background(DTColor.surfaceRaised)
                        .clipShape(RoundedRectangle(cornerRadius: DTRadius.xs, style: .continuous))
                }
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Copy to clipboard") { onSelect() }
        }
    }
}
