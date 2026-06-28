import SwiftUI
import AppKit
import DropThingsCore
import DropThingsDesignSystem
import DropThingsPlatform

struct ColorPickerSettingsView: View {
    @ObservedObject var module: ColorPickerModule

    var body: some View {
        SettingsSection(
            title: "Color Picker",
            caption: "Pick any color from your screen. The hex value lands on your clipboard; the recent list is kept across launches."
        ) {
            VStack(alignment: .leading, spacing: DTSpace.md) {
                Button {
                    module.startPicking()
                } label: {
                    Label("Pick color now", systemImage: "eyedropper")
                }
                .controlSize(.regular)

                Toggle("Enable hotkey", isOn: Binding(
                    get: { module.colorPickerSettings.hotkeyEnabled },
                    set: { module.setHotkeyEnabled($0) }
                ))

                ShortcutRecorder(
                    title: "Pick color",
                    definition: Binding(
                        get: { module.colorPickerSettings.hotkey },
                        set: { module.setHotkey($0) }
                    )
                )

                historySection

                HStack {
                    Text("History size: \(module.colorPickerSettings.historyLimit)")
                        .font(DTTypography.caption)
                        .foregroundStyle(DTColor.textSecondary)
                    Spacer()
                    Button("Clear history") { module.clearHistory() }
                        .controlSize(.small)
                        .disabled(module.colorPickerSettings.history.isEmpty)
                }
            }
        }
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: DTSpace.xs) {
            HStack {
                Text("Recent colors")
                    .font(DTTypography.body.weight(.semibold))
                Spacer()
                Stepper(
                    "Limit",
                    value: Binding(
                        get: { module.colorPickerSettings.historyLimit },
                        set: { module.setHistoryLimit($0) }
                    ),
                    in: 1...ColorPickerSettings.historyLimitMax
                )
                .labelsHidden()
            }
            if module.colorPickerSettings.history.isEmpty {
                Text("Pick a color to see it here.")
                    .font(DTTypography.caption)
                    .foregroundStyle(DTColor.textSecondary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), spacing: 4)], spacing: 4) {
                    ForEach(module.colorPickerSettings.history) { picked in
                        ColorSwatch(picked: picked, onCopy: { copyToPasteboard(picked) }, onRemove: { module.removeHistoryEntry(id: picked.id) })
                    }
                }
            }
        }
    }

    private func copyToPasteboard(_ picked: PickedColor) {
        module.copyToPasteboard(picked)
    }
}

private struct ColorSwatch: View {
    let picked: PickedColor
    let onCopy: () -> Void
    let onRemove: () -> Void

    var body: some View {
        Button {
            onCopy()
        } label: {
            VStack(spacing: 2) {
                Rectangle()
                    .fill(Color(nsColor: picked.rgb.nsColor))
                    .frame(height: 32)
                    .overlay(
                        RoundedRectangle(cornerRadius: 3)
                            .strokeBorder(DTColor.border, lineWidth: 1)
                    )
                Text(picked.hex)
                    .font(DTTypography.caption.monospaced())
                    .foregroundStyle(DTColor.textPrimary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
        .help("\(picked.hex) — click to copy")
        .contextMenu {
            Button("Copy \(picked.hex)") { onCopy() }
            Button("Remove from history", role: .destructive) { onRemove() }
        }
    }
}
