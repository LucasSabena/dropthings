import SwiftUI
import DropThingsCore
import DropThingsDesignSystem
import DropThingsPlatform

struct ClipboardHistorySettingsView: View {
    @ObservedObject var module: ClipboardHistoryModule

    var body: some View {
        SettingsSection(
            title: "Clipboard History",
            caption: "A searchable history of copied text, files, images, and colors. Pinned items survive restarts."
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

                Toggle("Paste at cursor with Enter", isOn: Binding(
                    get: { module.settings.pasteOnEnter },
                    set: { module.setPasteOnEnter($0) }
                ))
                .disabled(false)

                if module.settings.pasteOnEnter {
                    accessibilityStatus
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

                excludedAppsSection

                if module.state.isStarted {
                    InlineAlert(style: .success, message: "Recording clipboard changes. Open the history panel with the hotkey.")
                }
            }
        }
    }

    /// Mirrors the Accessibility state live. Shows a grant button when missing
    /// because auto-paste cannot work without it; re-checked on each appearance.
    @ViewBuilder
    private var accessibilityStatus: some View {
        let granted = KeystrokeSynthesizer.isAccessibilityGranted()
        if granted {
            InlineAlert(style: .info, message: "Accessibility is granted. Enter pastes at the cursor.")
        } else {
            VStack(alignment: .leading, spacing: DTSpace.xs) {
                InlineAlert(
                    style: .warning,
                    message: "Grant Accessibility so Enter can paste into other apps. Without it, Enter copies to the clipboard instead."
                )
                Button("Open System Settings") {
                    PermissionCenter().openSystemSettings(for: .accessibility)
                }
                .controlSize(.small)
            }
        }
    }

    private var excludedAppsSection: some View {
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
    }
}
