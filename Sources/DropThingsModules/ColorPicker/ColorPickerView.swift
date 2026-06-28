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
            caption: "Pick any color from your screen. The value lands on your clipboard in the format you choose; favorites stay pinned to the top of the history."
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

                HStack {
                    Text("Copy as")
                        .font(DTTypography.body)
                    Spacer()
                    Picker("", selection: Binding(
                        get: { module.colorPickerSettings.copyFormat },
                        set: { module.setCopyFormat($0) }
                    )) {
                        ForEach(ColorCopyFormat.allCases) { format in
                            Text(format.label).tag(format)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(width: 140)
                }

                historySection

                if let picked = module.colorPickerSettings.history.first {
                    derivedPaletteSection(for: picked)
                }

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
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), spacing: DTSpace.xs)], spacing: DTSpace.xxs) {
                    ForEach(module.colorPickerSettings.history) { picked in
                        ColorSwatch(
                            picked: picked,
                            copyFormat: module.colorPickerSettings.copyFormat,
                            onCopy: { copyToPasteboard(picked) },
                            onRemove: { module.removeHistoryEntry(id: picked.id) },
                            onToggleFavorite: { module.toggleFavorite(id: picked.id) }
                        )
                    }
                }
            }
        }
    }

    private func derivedPaletteSection(for picked: PickedColor) -> some View {
        VStack(alignment: .leading, spacing: DTSpace.xs) {
            HStack {
                Text("Derived palette")
                    .font(DTTypography.body.weight(.semibold))
                Spacer()
            }
            let variants: [(String, PickedColor)] = [
                ("Lighter", picked.lighter),
                ("Darker", picked.darker),
                ("Saturated", picked.saturated),
                ("Desaturated", picked.desaturated),
                ("Complement", picked.complement),
            ] + picked.analogues.enumerated().map { ("Analogue \($0 + 1)", $1) }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), spacing: DTSpace.xs)], spacing: DTSpace.xxs) {
                ForEach(variants, id: \.1.id) { label, variant in
                    ColorSwatch(
                        picked: variant,
                        copyFormat: module.colorPickerSettings.copyFormat,
                        onCopy: { module.copyToPasteboard(variant) },
                        onRemove: {},
                        onToggleFavorite: { module.toggleFavorite(id: variant.id) }
                    )
                    .help("\(label): \(module.colorPickerSettings.copyFormat.string(r: variant.r, g: variant.g, b: variant.b)) — click to copy")
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
    let copyFormat: ColorCopyFormat
    let onCopy: () -> Void
    let onRemove: () -> Void
    let onToggleFavorite: () -> Void

    private var previewString: String {
        copyFormat.string(r: picked.r, g: picked.g, b: picked.b)
    }

    var body: some View {
        Button {
            onCopy()
        } label: {
            VStack(spacing: DTSpace.xxs) {
                ZStack(alignment: .topTrailing) {
                    Rectangle()
                        .fill(Color(nsColor: picked.rgb.nsColor))
                        .frame(height: 32)
                        .overlay(
                            RoundedRectangle(cornerRadius: DTRadius.xs, style: .continuous)
                                .strokeBorder(DTColor.border, lineWidth: 1)
                        )
                    if picked.isFavorite {
                        Image(systemName: "star.fill")
                            .font(DTTypography.badgeLabel)
                            .foregroundStyle(DTColor.warning)
                            .padding(DTSpace.xxs)
                    }
                }
                Text(previewString)
                    .font(DTTypography.caption.monospaced())
                    .foregroundStyle(DTColor.textPrimary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
        .help("\(previewString) — click to copy")
        .contextMenu {
            Button("Copy \(previewString)") { onCopy() }
            Button(picked.isFavorite ? "Unfavorite" : "Favorite") { onToggleFavorite() }
            Button("Remove from history", role: .destructive) { onRemove() }
        }
    }
}
