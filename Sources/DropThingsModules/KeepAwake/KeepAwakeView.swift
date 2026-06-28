import SwiftUI
import DropThingsCore
import DropThingsDesignSystem
import DropThingsPlatform

struct KeepAwakeSettingsView: View {
    @ObservedObject var module: KeepAwakeModule

    var body: some View {
        SettingsSection(
            title: "Keep Awake",
            caption: "Prevent your Mac from sleeping while this module is on. Settings → Energy Saver still wins if the battery is critical."
        ) {
            VStack(alignment: .leading, spacing: DTSpace.md) {
                Toggle("Keep system awake", isOn: Binding(
                    get: { module.isKeepingAwake },
                    set: { module.setKeepingAwake($0) }
                ))

                Picker("Prevent", selection: Binding(
                    get: { module.keepAwakeSettings.preferredReason },
                    set: { module.setPreferredReason($0) }
                )) {
                    Text("System sleep").tag(KeepAwakeAssertion.Reason.systemSleep)
                    Text("Display sleep only").tag(KeepAwakeAssertion.Reason.displaySleep)
                }
                .pickerStyle(.segmented)

                Toggle("Restore on next launch", isOn: Binding(
                    get: { module.keepAwakeSettings.restoreOnLaunch },
                    set: { module.setRestoreOnLaunch($0) }
                ))

                InlineAlert(
                    style: .info,
                    message: "The Mac App Store rejects apps that abuse this API. We use it only while you keep this toggle on."
                )
            }
        }
    }
}

