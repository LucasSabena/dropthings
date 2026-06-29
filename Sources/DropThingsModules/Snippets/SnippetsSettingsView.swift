import SwiftUI
import DropThingsCore
import DropThingsDesignSystem
import DropThingsPlatform

struct SnippetsSettingsView: View {
    @ObservedObject var module: SnippetsModule
    @State private var newTitle: String = ""
    @State private var newContent: String = ""
    @State private var newKeyword: String = ""

    var body: some View {
        SettingsSection(
            title: "Snippets",
            caption: "Persistent text snippets copied to the clipboard on demand."
        ) {
            VStack(alignment: .leading, spacing: DTSpace.md) {
                Button {
                    module.showPanel()
                } label: {
                    Label("Open snippets", systemImage: "doc.text")
                }
                .controlSize(.regular)

                Toggle("Enable hotkey", isOn: Binding(
                    get: { module.settings.hotkeyEnabled },
                    set: { module.setHotkeyEnabled($0) }
                ))

                ShortcutRecorder(
                    title: "Open snippets",
                    definition: Binding(
                        get: { module.settings.hotkey },
                        set: { module.setHotkey($0) }
                    )
                )

                VStack(alignment: .leading, spacing: DTSpace.sm) {
                    Text("Add snippet")
                        .font(DTTypography.body.weight(.semibold))

                    TextField("Title", text: $newTitle)
                        .textFieldStyle(.roundedBorder)
                    TextField("Keyword (optional)", text: $newKeyword)
                        .textFieldStyle(.roundedBorder)
                    TextEditor(text: $newContent)
                        .font(DTTypography.body)
                        .frame(minHeight: 60)
                        .overlay(
                            RoundedRectangle(cornerRadius: DTRadius.sm, style: .continuous)
                                .strokeBorder(DTColor.border, lineWidth: 0.5)
                        )

                    Button {
                        module.addSnippet(title: newTitle, content: newContent, keyword: newKeyword)
                        newTitle = ""
                        newContent = ""
                        newKeyword = ""
                    } label: {
                        Label("Add snippet", systemImage: "plus")
                    }
                    .controlSize(.regular)
                    .disabled(newTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        && newContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                if module.settings.snippets.isEmpty {
                    InlineAlert(style: .info, message: "No snippets yet. Add one above or import settings.")
                } else {
                    VStack(alignment: .leading, spacing: DTSpace.sm) {
                        Text("\(module.settings.snippets.count) saved snippet\(module.settings.snippets.count == 1 ? "" : "s")")
                            .font(DTTypography.body.weight(.semibold))

                        ForEach(module.settings.snippets) { snippet in
                            SnippetEditorRow(module: module, snippet: snippet)
                        }
                    }
                }

                if module.state.isStarted {
                    InlineAlert(style: .success, message: "Snippets hotkey is active. Press it to open the picker.")
                }
            }
        }
    }
}

private struct SnippetEditorRow: View {
    @ObservedObject var module: SnippetsModule
    let snippet: Snippet

    @State private var title: String = ""
    @State private var content: String = ""
    @State private var keyword: String = ""
    @State private var isEditing: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: DTSpace.sm) {
            if isEditing {
                TextField("Title", text: $title)
                    .textFieldStyle(.roundedBorder)
                TextField("Keyword", text: $keyword)
                    .textFieldStyle(.roundedBorder)
                TextEditor(text: $content)
                    .font(DTTypography.body)
                    .frame(minHeight: 60)
                    .overlay(
                        RoundedRectangle(cornerRadius: DTRadius.sm, style: .continuous)
                            .strokeBorder(DTColor.border, lineWidth: 0.5)
                    )
                HStack {
                    Button("Save") {
                        module.updateSnippet(id: snippet.id, title: title, content: content, keyword: keyword)
                        isEditing = false
                    }
                    .controlSize(.small)
                    Button("Cancel", role: .cancel) {
                        resetFields()
                        isEditing = false
                    }
                    .controlSize(.small)
                    Spacer()
                }
            } else {
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
                    if let kw = snippet.keyword {
                        Text(kw)
                            .font(DTTypography.badgeLabel)
                            .foregroundStyle(DTColor.textSecondary)
                            .padding(.horizontal, DTSpace.xs)
                            .padding(.vertical, DTSpace.xxs)
                            .background(DTColor.surfaceRaised)
                            .clipShape(RoundedRectangle(cornerRadius: DTRadius.xs, style: .continuous))
                    }
                    Button {
                        module.copyToPasteboard(snippet)
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(DTTypography.badgeButton)
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                    Button {
                        resetFields()
                        isEditing = true
                    } label: {
                        Image(systemName: "pencil")
                            .font(DTTypography.badgeButton)
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                    Button {
                        module.deleteSnippet(id: snippet.id)
                    } label: {
                        Image(systemName: "trash")
                            .font(DTTypography.badgeButton)
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                }
            }
        }
        .onAppear {
            resetFields()
        }
    }

    private func resetFields() {
        title = snippet.title
        content = snippet.content
        keyword = snippet.keyword ?? ""
    }
}
