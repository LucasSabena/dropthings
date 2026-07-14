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
                HStack(spacing: DTSpace.sm) {
                    Image(systemName: module.isAssertionActive ? "sun.max.fill" : "moon.zzz")
                        .foregroundStyle(module.isAssertionActive ? DTColor.success : DTColor.textSecondary)
                    Text(module.isAssertionActive ? "Keep Awake is active" : "Enable this module to keep the Mac awake")
                        .font(DTTypography.body.weight(.semibold))
                }

                Toggle("Also keep the display awake", isOn: Binding(
                    get: { module.keepAwakeSettings.keepDisplayAwake },
                    set: { module.setKeepDisplayAwake($0) }
                ))

                Text("Leaving this off saves power: the Mac stays awake while the display may dim normally.")
                    .font(DTTypography.caption)
                    .foregroundStyle(DTColor.textSecondary)

                if module.state.isStarted {
                    if module.isAssertionActive {
                        HStack(spacing: DTSpace.xs) {
                            Image(systemName: "checkmark.circle")
                                .foregroundStyle(DTColor.success)
                            Text("Power assertion active")
                                .font(DTTypography.caption.weight(.semibold))
                                .foregroundStyle(DTColor.success)
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

}
