import SwiftUI
import AppKit
import DropThingsCore
import DropThingsDesignSystem
import DropThingsPlatform

struct CommandPaletteSettingsView: View {
    @ObservedObject var module: CommandPaletteModule

    var body: some View {
        SettingsSection(
            title: "Command Palette",
            caption: "Summon a searchable list of commands from every module with a global hotkey."
        ) {
            VStack(alignment: .leading, spacing: DTSpace.md) {
                Button {
                    module.show()
                } label: {
                    Label("Open Command Palette", systemImage: "command")
                }
                .controlSize(.regular)

                Toggle("Enable hotkey", isOn: Binding(
                    get: { module.settings.hotkeyEnabled },
                    set: { module.setHotkeyEnabled($0) }
                ))

                ShortcutRecorder(
                    title: "Open Command Palette",
                    definition: Binding(
                        get: { module.settings.hotkey },
                        set: { module.setHotkey($0) }
                    )
                )

                Text("The palette aggregates commands from every enabled module. Select one to run it instantly.")
                    .font(DTTypography.caption)
                    .foregroundStyle(DTColor.textSecondary)
            }
        }
    }
}
