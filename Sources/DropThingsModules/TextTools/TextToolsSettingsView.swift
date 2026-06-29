import SwiftUI
import AppKit
import DropThingsCore
import DropThingsDesignSystem
import DropThingsPlatform

struct TextToolsSettingsView: View {
    @ObservedObject var module: TextToolsModule

    var body: some View {
        SettingsSection(
            title: "Text Tools",
            caption: "A floating scratchpad for case conversion, URL/JSON/Base64 transforms, line cleanup, and live character/word/line counts."
        ) {
            VStack(alignment: .leading, spacing: DTSpace.md) {
                Button {
                    module.showPanel()
                } label: {
                    Label("Open Text Tools", systemImage: "textformat")
                }
                .controlSize(.regular)

                Toggle("Enable hotkey", isOn: Binding(
                    get: { module.textToolsSettings.hotkeyEnabled },
                    set: { module.setHotkeyEnabled($0) }
                ))

                ShortcutRecorder(
                    title: "Open Text Tools",
                    definition: Binding(
                        get: { module.textToolsSettings.hotkey },
                        set: { module.setHotkey($0) }
                    )
                )

                VStack(alignment: .leading, spacing: DTSpace.xs) {
                    Text("Available transforms")
                        .font(DTTypography.body.weight(.semibold))
                    let transforms: [[TextToolsEngine.Transform]] = [
                        [.uppercase, .lowercase, .titleCase, .camelCase, .snakeCase],
                        [.urlEncode, .urlDecode, .jsonPretty, .jsonMinify, .base64Encode, .base64Decode],
                        [.sortLines, .removeDuplicateLines]
                    ]
                    ForEach(transforms, id: \.self) { group in
                        HStack(spacing: DTSpace.sm) {
                            ForEach(group) { transform in
                                Label(transform.label, systemImage: transform.systemImage)
                                    .font(DTTypography.caption)
                            }
                        }
                    }
                }

                if module.state.isStarted {
                    InlineAlert(style: .success, message: "Text Tools is running. Press the hotkey or use the button to open the floating window.")
                }
            }
        }
    }
}
