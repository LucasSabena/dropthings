import SwiftUI
import DropThingsCore
import DropThingsDesignSystem
import DropThingsPlatform

struct ClipboardHistorySettingsView: View {
    @ObservedObject var module: ClipboardHistoryModule

    var body: some View {
        SettingsSection(
            title: "Clipboard History",
            caption: "A private, searchable history stored only on this Mac. It survives restarts and normal app updates."
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

                Toggle("Auto-paste with Enter when Accessibility is already granted", isOn: Binding(
                    get: { module.settings.pasteOnEnter },
                    set: { module.setPasteOnEnter($0) }
                ))

                if module.settings.pasteOnEnter {
                    InlineAlert(
                        style: KeystrokeSynthesizer.isAccessibilityGranted() ? .info : .warning,
                        message: KeystrokeSynthesizer.isAccessibilityGranted()
                            ? "Enter pastes at the cursor. Clipboard History did not request this permission."
                            : "Enter will copy only. DropThings will not request Accessibility for Clipboard History; enable Scroll Control first if you also want auto-paste."
                    )
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

                HStack {
                    Text("Keep unpinned history")
                        .font(DTTypography.body)
                    Spacer()
                    Picker("", selection: Binding(
                        get: { module.settings.retentionDays },
                        set: { module.setRetentionDays($0) }
                    )) {
                        Text("1 day").tag(1)
                        Text("7 days").tag(7)
                        Text("30 days").tag(30)
                        Text("90 days").tag(90)
                        Text("1 year").tag(365)
                    }
                    .labelsHidden()
                    .fixedSize()
                }

                HStack {
                    Text("Image storage limit")
                        .font(DTTypography.body)
                    Spacer()
                    Picker("", selection: Binding(
                        get: { module.settings.maxStorageMB },
                        set: { module.setMaxStorageMB($0) }
                    )) {
                        Text("50 MB").tag(50)
                        Text("250 MB").tag(250)
                        Text("500 MB").tag(500)
                        Text("1 GB").tag(1_024)
                    }
                    .labelsHidden()
                    .fixedSize()
                }

                Text(storageSummary)
                    .font(DTTypography.caption)
                    .foregroundStyle(DTColor.textSecondary)

                if let error = module.persistenceError {
                    InlineAlert(style: .error, message: error)
                } else if module.omittedImageCount > 0 {
                    InlineAlert(
                        style: .warning,
                        message: "\(module.omittedImageCount) older image(s) remain available this session but exceed the disk limit."
                    )
                }

                excludedAppsSection

                if case .running = module.state {
                    InlineAlert(style: .success, message: "Recording clipboard changes. Open the history panel with the hotkey.")
                }
            }
        }
    }

    private var storageSummary: String {
        let used = ByteCountFormatter.string(fromByteCount: module.storageBytes, countStyle: .file)
        return "Using \(used) for \(module.items.count) item(s). Pinned items do not expire."
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
