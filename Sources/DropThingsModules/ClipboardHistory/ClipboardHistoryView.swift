import SwiftUI
import DropThingsCore
import DropThingsDesignSystem
import DropThingsPlatform

struct ClipboardHistorySettingsView: View {
    @ObservedObject var module: ClipboardHistoryModule

    var body: some View {
        SettingsSection(
            title: "Clipboard History",
            caption: "Keep a searchable history of copied text and files. Pinned items survive restarts."
        ) {
            VStack(alignment: .leading, spacing: DTSpace.md) {
                HStack {
                    Button {
                        module.showHistoryPanel()
                    } label: {
                        Label("Open history", systemImage: "doc.on.clipboard")
                    }
                    .controlSize(.regular)

                    Button {
                        module.toggleIncognito()
                    } label: {
                        Label(module.settings.incognito ? "Incognito on" : "Incognito off",
                              systemImage: module.settings.incognito ? "eye.slash" : "eye")
                    }
                    .controlSize(.regular)
                }

                Toggle("Enable hotkey", isOn: Binding(
                    get: { module.settings.hotkeyEnabled },
                    set: { module.setHotkeyEnabled($0) }
                ))

                ShortcutRecorder(
                    title: "Open history",
                    definition: Binding(
                        get: { module.settings.hotkey },
                        set: { module.setHotkey($0) }
                    )
                )

                HStack {
                    Text("Max history")
                        .font(DTTypography.body)
                    Spacer()
                    Stepper(
                        "\(module.settings.maxHistory)",
                        value: Binding(
                            get: { module.settings.maxHistory },
                            set: { module.setMaxHistory($0) }
                        ),
                        in: ClipboardHistorySettings.maxHistoryMin...ClipboardHistorySettings.maxHistoryMax
                    )
                    .labelsHidden()
                }

                VStack(alignment: .leading, spacing: DTSpace.xs) {
                    HStack {
                        Text("Excluded apps")
                            .font(DTTypography.body.weight(.semibold))
                        Spacer()
                    }
                    Text("Clipboard changes from these bundle IDs are ignored.")
                        .font(DTTypography.caption)
                        .foregroundStyle(DTColor.textSecondary)
                    ForEach(module.settings.excludedBundleIDs, id: \.self) { bundleID in
                        HStack {
                            Text(bundleID)
                                .font(DTTypography.caption.monospaced())
                            Spacer()
                            Button {
                                module.removeExcludedBundleID(bundleID)
                            } label: {
                                Image(systemName: "xmark")
                                    .font(DTTypography.badgeButton)
                            }
                            .buttonStyle(.borderless)
                            .controlSize(.small)
                        }
                    }
                }

                if module.state.isStarted {
                    InlineAlert(style: .success, message: "Recording clipboard changes. Open the history panel with the hotkey.")
                }
            }
        }
    }
}
