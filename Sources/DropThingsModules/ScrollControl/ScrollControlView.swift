import SwiftUI
import DropThingsCore
import DropThingsDesignSystem
import DropThingsPlatform

struct ScrollControlSettingsView: View {
    @ObservedObject var module: ScrollControlModule

    var body: some View {
        SettingsSection(
            title: "Scroll Control",
            caption: "Set scroll direction per input device. Trackpads feel best on Natural; mouse wheels on Inverted."
        ) {
            VStack(alignment: .leading, spacing: DTSpace.md) {
                ShortcutRecorder(
                    title: "Pause / resume",
                    definition: Binding(
                        get: { module.scrollSettings.hotkey },
                        set: { module.setHotkey($0) }
                    )
                )

                if module.isPaused {
                    InlineAlert(
                        style: .warning,
                        message: "Paused. Scroll events pass through unchanged until you press the shortcut again or click Resume."
                    )
                    Button("Resume now") {
                        module.togglePause()
                    }
                    .controlSize(.regular)
                }

                directionPicker(
                    title: "Trackpad",
                    icon: "trackpad",
                    selection: Binding(
                        get: { module.scrollSettings.trackpadDirection },
                        set: { module.updateTrackpadDirection($0) }
                    )
                )
                directionPicker(
                    title: "Mouse wheel",
                    icon: "scroll",
                    selection: Binding(
                        get: { module.scrollSettings.mouseWheelDirection },
                        set: { module.updateMouseWheelDirection($0) }
                    )
                )
                directionPicker(
                    title: "Magic Mouse",
                    icon: "magicmouse",
                    selection: Binding(
                        get: { module.scrollSettings.magicMouseDirection },
                        set: { module.updateMagicMouseDirection($0) }
                    )
                )

                Toggle("Allow horizontal scroll", isOn: Binding(
                    get: { module.scrollSettings.horizontalScrollEnabled },
                    set: { module.updateHorizontalScrollEnabled($0) }
                ))

                multiplierSlider

                appOverridesSection

                if let err = module.lastError {
                    InlineAlert(style: .error, message: err)
                }
            }
        }
    }

    private func directionPicker(
        title: String,
        icon: String,
        selection: Binding<ScrollDirection>
    ) -> some View {
        HStack(spacing: DTSpace.sm) {
            Image(systemName: icon)
                .foregroundStyle(DTColor.accent)
                .frame(width: 18)
            Text(title)
                .font(DTTypography.body)
            Spacer()
            Picker("", selection: selection) {
                Text("Natural").tag(ScrollDirection.natural)
                Text("Inverted").tag(ScrollDirection.inverted)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
        }
    }

    private var appOverridesSection: some View {
        VStack(alignment: .leading, spacing: DTSpace.xs) {
            HStack {
                Text("Per-app overrides")
                    .font(DTTypography.body.weight(.semibold))
                Spacer()
            }
            Text("Override scroll direction and speed for specific apps. Add the frontmost app or type a bundle ID manually.")
                .font(DTTypography.caption)
                .foregroundStyle(DTColor.textSecondary)

            ForEach(module.scrollSettings.appOverrides) { override in
                AppOverrideRow(
                    override: override,
                    onUpdate: { module.updateAppOverride(bundleID: $0, direction: $1, multiplier: $2) },
                    onRemove: { module.removeAppOverride(bundleID: override.bundleID) }
                )
            }

            HStack {
                TextField("Bundle ID", text: Binding(
                    get: { "" },
                    set: { newBundleID in
                        guard !newBundleID.isEmpty else { return }
                        module.updateAppOverride(bundleID: newBundleID, direction: .inverted, multiplier: module.scrollSettings.scrollMultiplier)
                    }
                ))
                .textFieldStyle(.roundedBorder)
                Button("Add frontmost") {
                    if let bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier {
                        module.updateAppOverride(bundleID: bundleID, direction: .inverted, multiplier: module.scrollSettings.scrollMultiplier)
                    }
                }
                .controlSize(.small)
                .disabled(NSWorkspace.shared.frontmostApplication?.bundleIdentifier == nil)
            }
        }
    }

    private var multiplierSlider: some View {
        VStack(alignment: .leading, spacing: DTSpace.xs) {
            HStack {
                Text("Scroll multiplier")
                    .font(DTTypography.body)
                Spacer()
                Text(String(format: "%.2fx", module.scrollSettings.scrollMultiplier))
                    .font(DTTypography.caption.monospacedDigit())
                    .foregroundStyle(DTColor.textSecondary)
            }
            Slider(
                value: Binding(
                    get: { module.scrollSettings.scrollMultiplier },
                    set: { module.updateScrollMultiplier($0) }
                ),
                in: ScrollSettings.multiplierMin...ScrollSettings.multiplierMax
            )
            Text("Applied when a device is set to Inverted or overridden for the active app.")
                .font(DTTypography.caption)
                .foregroundStyle(DTColor.textSecondary)
        }
    }
}

private struct AppOverrideRow: View {
    let override: ScrollAppOverride
    let onUpdate: (String, ScrollDirection, Double) -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: DTSpace.sm) {
            Text(override.bundleID)
                .font(DTTypography.caption.monospaced())
                .lineLimit(1)
            Spacer()
            Picker("", selection: Binding(
                get: { override.direction },
                set: { onUpdate(override.bundleID, $0, override.multiplier) }
            )) {
                Text("Natural").tag(ScrollDirection.natural)
                Text("Inverted").tag(ScrollDirection.inverted)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
            Text(String(format: "%.2fx", override.multiplier))
                .font(DTTypography.caption.monospacedDigit())
            Slider(
                value: Binding(
                    get: { override.multiplier },
                    set: { onUpdate(override.bundleID, override.direction, $0) }
                ),
                in: ScrollSettings.multiplierMin...ScrollSettings.multiplierMax
            )
            .frame(width: 80)
            Button {
                onRemove()
            } label: {
                Image(systemName: "xmark")
                    .font(DTTypography.badgeButton)
            }
            .buttonStyle(.borderless)
            .controlSize(.small)
        }
        .padding(DTSpace.sm)
        .background(DTColor.surfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: DTRadius.sm, style: .continuous))
    }
}
