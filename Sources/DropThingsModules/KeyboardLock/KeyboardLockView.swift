import SwiftUI
import DropThingsCore
import DropThingsDesignSystem

struct KeyboardLockMenuBarView: View {
    @ObservedObject var module: KeyboardLockModule

    var body: some View {
        VStack(alignment: .leading, spacing: DTSpace.md) {
            Label(module.isKeyboardLocked ? "Keyboard is locked" : "Keyboard is ready", systemImage: module.menuBarIconName)
                .font(DTTypography.sectionTitle)
                .foregroundStyle(module.isKeyboardLocked ? DTColor.warning : DTColor.textPrimary)
            Text(module.isKeyboardLocked
                ? "Use this menu-bar button with your mouse to unlock it."
                : "Lock it before cleaning. Mouse and trackpad continue working.")
                .font(DTTypography.body)
                .foregroundStyle(DTColor.textSecondary)
            Button(module.isKeyboardLocked ? "Unlock keyboard" : "Lock keyboard") {
                module.toggleLock()
            }
            .buttonStyle(.borderedProminent)
            .tint(module.isKeyboardLocked ? DTColor.warning : DTColor.accent)
            .accessibilityHint("This control remains available with the keyboard locked.")
        }
        .padding(DTSpace.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct KeyboardLockSettingsView: View {
    @ObservedObject var module: KeyboardLockModule

    var body: some View {
        VStack(alignment: .leading, spacing: DTSpace.lg) {
            SettingsSection(title: "Keyboard Lock") {
                Text("Temporarily disables keyboard input so you can clean it. It never locks automatically.")
                    .font(DTTypography.body)
                    .foregroundStyle(DTColor.textSecondary)
                Button(module.isKeyboardLocked ? "Unlock keyboard" : "Lock keyboard") {
                    module.toggleLock()
                }
                .disabled(!module.state.isStarted)
                if module.isKeyboardLocked {
                    InlineAlert(style: .warning, message: "Use the DropThings menu-bar icon with your mouse if you need to unlock it.")
                }
            }
        }
        .padding(DTSpace.xl)
    }
}
