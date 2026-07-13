import SwiftUI
import AppKit
import UniformTypeIdentifiers
import DropThingsCore
import DropThingsDesignSystem

/// Top-level SwiftUI view hosted inside the viewer window. Owns the tab bar,
/// the toolbar (open / save / new / layout switch), and the editor + preview
/// split for the active document.
struct MarkdownViewerRootView: View {
    @ObservedObject var document: MarkdownDocument
    let settings: MarkdownViewerSettings
    @ObservedObject var module: MarkdownViewerModule

    var body: some View {
        VStack(spacing: 0) {
            tabBar
            Divider()
            toolbar
            Divider()
            if let error = document.loadError {
                InlineAlert(style: .warning, message: error)
                    .padding(DTSpace.sm)
            }
            if let issue = module.finderSelectionIssue {
                InlineAlert(style: .warning, message: issue)
                    .padding(DTSpace.sm)
            }
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(DTColor.background)
        .onDrop(of: [.fileURL, .utf8PlainText], isTargeted: nil) { providers in
            handleDrop(providers)
            return true
        }
        .frame(minWidth: 480, minHeight: 360)
        .background(
            // Hidden buttons give the window standard tab shortcuts.
            Group {
                Button("") { module.openNewDocument() }
                    .keyboardShortcut("t", modifiers: .command)
                    .hidden()
                Button("") { module.openFilePanel() }
                    .keyboardShortcut("o", modifiers: .command)
                    .hidden()
                Button("") { module.saveCurrentDocument() }
                    .keyboardShortcut("s", modifiers: .command)
                    .hidden()
                Button("") { module.saveCurrentDocumentAs() }
                    .keyboardShortcut("s", modifiers: [.command, .shift])
                    .hidden()
                Button("") { module.closeCurrentDocument() }
                    .keyboardShortcut("w", modifiers: .command)
                    .hidden()
                Button("") { module.closeViewerWindow() }
                    .keyboardShortcut("w", modifiers: [.command, .shift])
                    .hidden()
                ForEach(0..<min(module.openDocuments.count, 9), id: \.self) { index in
                    Button("") { module.selectDocument(at: index) }
                        .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: .command)
                        .hidden()
                }
            }
        )
    }

    // MARK: - Tab bar

    private var tabBar: some View {
        HStack(spacing: DTSpace.xxs) {
            ForEach(Array(module.openDocuments.enumerated()), id: \.element.id) { index, doc in
                tabButton(for: doc, index: index, isActive: index == module.activeDocumentIndex)
            }
            Button {
                module.openNewDocument()
            } label: {
                Image(systemName: "plus")
                    .font(DTTypography.caption.weight(.semibold))
                    .foregroundStyle(DTColor.textSecondary)
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            .help("New tab (⌘T)")
            Spacer()
        }
        .padding(.horizontal, DTSpace.sm)
        .padding(.vertical, DTSpace.xs)
        .background(DTColor.background.opacity(0.6))
    }

    private func tabButton(for doc: MarkdownDocument, index: Int, isActive: Bool) -> some View {
        HStack(spacing: DTSpace.xxs) {
            Button {
                module.selectDocument(at: index)
            } label: {
                HStack(spacing: DTSpace.xxs) {
                    Text(doc.displayName)
                        .font(DTTypography.body.weight(isActive ? .semibold : .regular))
                        .foregroundStyle(isActive ? DTColor.textPrimary : DTColor.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    if doc.isDirty {
                        Circle()
                            .fill(DTColor.warning)
                            .frame(width: 5, height: 5)
                    }
                }
                .padding(.horizontal, DTSpace.sm)
                .padding(.vertical, DTSpace.xxs)
                .frame(minWidth: 80)
                .background(isActive ? DTColor.surface : DTColor.surface.opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: DTRadius.sm, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: DTRadius.sm, style: .continuous)
                        .strokeBorder(isActive ? DTColor.border : .clear, lineWidth: 0.5)
                )
            }
            .buttonStyle(.plain)

            Button {
                module.closeDocument(at: index)
            } label: {
                Image(systemName: "xmark")
                    .font(DTTypography.badgeButton)
                    .foregroundStyle(DTColor.textSecondary)
                    .frame(width: 14, height: 14)
            }
            .buttonStyle(.plain)
            .help("Close tab")
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: DTSpace.sm) {
            Button { module.openFilePanel() } label: {
                Label("Open…", systemImage: "folder")
            }
            .help("Open Markdown files")
            Button { module.saveCurrentDocument() } label: {
                Label("Save", systemImage: "square.and.arrow.down")
            }
            .disabled(document.url == nil && document.text.isEmpty)
            .help(document.url == nil ? "Save as…" : "Save")
            Spacer()
            layoutPicker
        }
        .padding(.horizontal, DTSpace.md)
        .padding(.vertical, DTSpace.sm)
    }

    private var layoutPicker: some View {
        Picker("", selection: Binding(
            get: { settings.layout },
            set: { module.setLayout($0) }
        )) {
            ForEach(MarkdownLayout.allCases, id: \.self) { item in
                Text(item.label).tag(item)
            }
        }
        .pickerStyle(.segmented)
        .frame(width: 180)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch settings.layout {
        case .editor:
            editorPane
        case .preview:
            previewPane
        case .split:
            HSplitView {
                editorPane
                previewPane
            }
        }
    }

    private var editorPane: some View {
        MarkdownEditorView(
            text: Binding(
                get: { document.text },
                set: { document.text = $0 }
            ),
            fontSize: settings.fontSize,
            showLineNumbers: settings.showLineNumbers,
            onChange: { module.markDocumentDirty() }
        )
        .background(Color(nsColor: .textBackgroundColor))
    }

    private var previewPane: some View {
        MarkdownPreviewView(
            markdown: document.text,
            theme: effectiveTheme,
            fontSize: settings.fontSize
        )
        .background(DTColor.surface)
    }

    private var effectiveTheme: MarkdownTheme {
        switch settings.theme {
        case .auto:
            let dark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .vibrantDark])
            return dark != nil ? .dark : .light
        case .light: return .light
        case .dark: return .dark
        }
    }

    // MARK: - Drop (multiple files or text)

    private func handleDrop(_ providers: [NSItemProvider]) {
        var urls: [URL] = []
        var textFallback: String?
        let group = DispatchGroup()
        let lock = NSLock()

        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                group.enter()
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    defer { group.leave() }
                    if let data = item as? Data,
                       let url = URL(dataRepresentation: data, relativeTo: nil) {
                        if MarkdownFileType.accepts(url) {
                            lock.lock(); urls.append(url); lock.unlock()
                        }
                    }
                }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.utf8PlainText.identifier) {
                group.enter()
                provider.loadItem(forTypeIdentifier: UTType.utf8PlainText.identifier, options: nil) { item, _ in
                    defer { group.leave() }
                    if let s = item as? String {
                        lock.lock(); textFallback = s; lock.unlock()
                    }
                }
            }
        }
        group.notify(queue: .main) {
            if !urls.isEmpty {
                module.openURLs(urls)
            } else if let text = textFallback {
                module.openPlainText(text)
            }
        }
    }
}
