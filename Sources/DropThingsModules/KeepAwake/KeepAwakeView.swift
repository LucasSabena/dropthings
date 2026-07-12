import SwiftUI
import AppKit
import DropThingsCore
import DropThingsDesignSystem
import DropThingsPlatform

struct KeepAwakeSettingsView: View {
    @ObservedObject var module: KeepAwakeModule

    var body: some View {
        SettingsSection(
            title: "Keep Awake",
            caption: "Prevent idle sleep indefinitely or for a fixed time. No system permission is required."
        ) {
            VStack(alignment: .leading, spacing: DTSpace.md) {
                Toggle(isOn: Binding(
                    get: { module.keepAwakeSettings.enabled },
                    set: { module.setKeepingAwake($0) }
                )) {
                    HStack(spacing: DTSpace.sm) {
                        Text("Keep Mac awake")
                            .font(DTTypography.body.weight(.semibold))
                        if module.keepAwakeSettings.enabled {
                            Text("·")
                                .foregroundStyle(DTColor.textSecondary)
                            Text("Active")
                                .font(DTTypography.caption.weight(.semibold))
                                .foregroundStyle(DTColor.success)
                        }
                    }
                }

                HStack {
                    Text("Duration")
                        .font(DTTypography.body)
                    Spacer()
                    Picker("", selection: Binding(
                        get: { module.keepAwakeSettings.durationMinutes },
                        set: { module.setDurationMinutes($0) }
                    )) {
                        Text("Until turned off").tag(Int?.none)
                        Text("15 minutes").tag(Int?.some(15))
                        Text("30 minutes").tag(Int?.some(30))
                        Text("1 hour").tag(Int?.some(60))
                        Text("2 hours").tag(Int?.some(120))
                        Text("4 hours").tag(Int?.some(240))
                        Text("8 hours").tag(Int?.some(480))
                    }
                    .labelsHidden()
                    .fixedSize()
                }

                Toggle("Also keep the display awake", isOn: Binding(
                    get: { module.keepAwakeSettings.keepDisplayAwake },
                    set: { module.setKeepDisplayAwake($0) }
                ))

                Text("Leaving this off saves power: the Mac stays awake while the display may dim normally.")
                    .font(DTTypography.caption)
                    .foregroundStyle(DTColor.textSecondary)

                if module.keepAwakeSettings.enabled {
                    if module.isAssertionActive {
                        HStack(spacing: DTSpace.xs) {
                            Image(systemName: "checkmark.circle")
                                .foregroundStyle(DTColor.success)
                            Text("Power assertion active")
                                .font(DTTypography.caption.weight(.semibold))
                                .foregroundStyle(DTColor.success)
                            if let remaining = module.remainingSeconds {
                                Text("· \(remainingText(remaining)) remaining")
                                    .font(DTTypography.caption.monospacedDigit())
                                    .foregroundStyle(DTColor.textSecondary)
                            }
                        }
                    } else {
                        InlineAlert(
                            style: .warning,
                            message: module.lastError ?? "DropThings is enabled, but macOS has not confirmed an active power assertion."
                        )
                    }
                }
            }
        }
    }

    private func remainingText(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded(.up)))
        let hours = total / 3_600
        let minutes = (total % 3_600) / 60
        let secs = total % 60
        if hours > 0 { return String(format: "%d:%02d:%02d", hours, minutes, secs) }
        return String(format: "%d:%02d", minutes, secs)
    }
}
