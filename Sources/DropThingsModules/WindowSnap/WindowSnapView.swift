import SwiftUI
import DropThingsCore
import DropThingsDesignSystem
import DropThingsPlatform

struct WindowSnapSettingsView: View {
    @ObservedObject var module: WindowSnapModule

    var body: some View {
        SettingsSection(
            title: "WindowSnap",
            caption: "Snap the frontmost window to halves, quarters, or fullscreen. Each shortcut is global and works from anywhere."
        ) {
            VStack(alignment: .leading, spacing: DTSpace.md) {
                ShortcutRecorder(
                    title: WindowSnapAction.maximize.displayName,
                    definition: binding(for: .maximize)
                )

                Divider()

                halfRows

                Divider()

                cornerRows

                if let err = module.lastError {
                    InlineAlert(style: .error, message: err)
                }
            }
        }
    }

    private var halfRows: some View {
        VStack(alignment: .leading, spacing: DTSpace.md) {
            HStack(spacing: DTSpace.md) {
                ShortcutRecorder(
                    title: WindowSnapAction.leftHalf.displayName,
                    definition: binding(for: .leftHalf)
                )
                ShortcutRecorder(
                    title: WindowSnapAction.rightHalf.displayName,
                    definition: binding(for: .rightHalf)
                )
            }
            HStack(spacing: DTSpace.md) {
                ShortcutRecorder(
                    title: WindowSnapAction.topHalf.displayName,
                    definition: binding(for: .topHalf)
                )
                ShortcutRecorder(
                    title: WindowSnapAction.bottomHalf.displayName,
                    definition: binding(for: .bottomHalf)
                )
            }
        }
    }

    private var cornerRows: some View {
        VStack(alignment: .leading, spacing: DTSpace.md) {
            HStack(spacing: DTSpace.md) {
                ShortcutRecorder(
                    title: WindowSnapAction.topLeft.displayName,
                    definition: binding(for: .topLeft)
                )
                ShortcutRecorder(
                    title: WindowSnapAction.topRight.displayName,
                    definition: binding(for: .topRight)
                )
            }
            HStack(spacing: DTSpace.md) {
                ShortcutRecorder(
                    title: WindowSnapAction.bottomLeft.displayName,
                    definition: binding(for: .bottomLeft)
                )
                ShortcutRecorder(
                    title: WindowSnapAction.bottomRight.displayName,
                    definition: binding(for: .bottomRight)
                )
            }
        }
    }

    private func binding(for action: WindowSnapAction) -> Binding<GlobalHotkey.Definition?> {
        Binding(
            get: { module.windowSnapSettings.hotkey(for: action) },
            set: { module.setHotkey(action, $0) }
        )
    }
}
