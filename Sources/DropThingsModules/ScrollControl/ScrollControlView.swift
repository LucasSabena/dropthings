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
            Text("Applied only when a device is set to Inverted.")
                .font(DTTypography.caption)
                .foregroundStyle(DTColor.textSecondary)
        }
    }
}
