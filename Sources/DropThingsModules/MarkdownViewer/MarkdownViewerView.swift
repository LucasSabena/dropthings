import SwiftUI
import AppKit
import DropThingsCore
import DropThingsDesignSystem
import DropThingsPlatform

struct MarkdownViewerSettingsView: View {
    @ObservedObject var module: MarkdownViewerModule

    var body: some View {
        SettingsSection(
            title: "Markdown Viewer",
            caption: "Read and edit Markdown files with a live, GitHub-Flavored preview. Open files with a global shortcut, drag-and-drop, or the Open button inside the viewer window."
        ) {
            VStack(alignment: .leading, spacing: DTSpace.md) {
                Button {
                    module.openViewer()
                } label: {
                    Label("Open Markdown Viewer", systemImage: "doc.richtext")
                }
                .controlSize(.regular)

                Toggle("Enable hotkey", isOn: Binding(
                    get: { module.viewerSettings.hotkeyEnabled },
                    set: { module.setHotkeyEnabled($0) }
                ))

                ShortcutRecorder(
                    title: "Open Markdown Viewer",
                    definition: Binding(
                        get: { module.viewerSettings.hotkey },
                        set: { module.setHotkey($0) }
                    )
                )

                HStack {
                    Text("Theme")
                        .font(DTTypography.body)
                    Spacer()
                    Picker("", selection: Binding(
                        get: { module.viewerSettings.theme },
                        set: { module.setTheme($0) }
                    )) {
                        ForEach(MarkdownTheme.allCases, id: \.self) { theme in
                            Text(theme.label).tag(theme)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(width: 160)
                }

                HStack {
                    Text("Font size")
                        .font(DTTypography.body)
                    Spacer()
                    Stepper(
                        "\(module.viewerSettings.fontSize) pt",
                        value: Binding(
                            get: { module.viewerSettings.fontSize },
                            set: { module.setFontSize($0) }
                        ),
                        in: MarkdownViewerSettings.fontSizeMin...MarkdownViewerSettings.fontSizeMax
                    )
                }

                Toggle("Show line numbers in editor", isOn: Binding(
                    get: { module.viewerSettings.showLineNumbers },
                    set: { module.setShowLineNumbers($0) }
                ))

                Toggle("Open the Finder selection with the shortcut", isOn: Binding(
                    get: { module.viewerSettings.openFinderSelectionWithHotkey },
                    set: { module.setOpenFinderSelectionWithHotkey($0) }
                ))
                Text("When you press the shortcut with Finder in front, DropThings opens the Markdown file you've selected. The first time, macOS asks for permission to control Finder (Automation). Without it, the shortcut opens the viewer with the last document instead.")
                    .font(DTTypography.caption)
                    .foregroundStyle(DTColor.textSecondary)
                if let issue = module.finderSelectionIssue {
                    InlineAlert(style: .warning, message: issue)
                }

                recentsSection
            }
        }
    }

    private var recentsSection: some View {
        VStack(alignment: .leading, spacing: DTSpace.xs) {
            HStack {
                Text("Recent files")
                    .font(DTTypography.body.weight(.semibold))
                Spacer()
                Button("Clear") { module.clearRecentFiles() }
                    .controlSize(.small)
                    .disabled(module.viewerSettings.recentFiles.isEmpty)
            }
            if module.viewerSettings.recentFiles.isEmpty {
                Text("Files you open will appear here.")
                    .font(DTTypography.caption)
                    .foregroundStyle(DTColor.textSecondary)
            } else {
                VStack(alignment: .leading, spacing: DTSpace.xxs) {
                    ForEach(module.viewerSettings.recentFiles) { file in
                        HStack(spacing: DTSpace.sm) {
                            Image(systemName: "doc.text")
                                .foregroundStyle(DTColor.textSecondary)
                            Button {
                                module.openRecent(file)
                            } label: {
                                Text(file.name)
                                    .font(DTTypography.body)
                                    .foregroundStyle(DTColor.textPrimary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            .buttonStyle(.plain)
                            Spacer()
                            Button(role: .destructive) {
                                module.removeRecent(file)
                            } label: {
                                Image(systemName: "xmark")
                                    .font(DTTypography.caption)
                                    .foregroundStyle(DTColor.textSecondary)
                            }
                            .buttonStyle(.plain)
                            .help("Remove from recent files")
                        }
                    }
                }
            }
        }
    }
}
