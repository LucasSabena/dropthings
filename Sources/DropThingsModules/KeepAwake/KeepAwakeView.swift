import SwiftUI
import AppKit
import DropThingsCore
import DropThingsDesignSystem
import DropThingsPlatform

struct KeepAwakeSettingsView: View {
    @ObservedObject var module: KeepAwakeModule
    @State private var didCopyCheckCommand = false

    var body: some View {
        SettingsSection(
            title: "Keep Awake",
            caption: "While on, your Mac stays awake as if you were using it. macOS resumes its normal sleep schedule when you turn it off."
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

                if module.keepAwakeSettings.enabled {
                    verifyRow
                }
            }
        }
    }

    private var verifyRow: some View {
        VStack(alignment: .leading, spacing: DTSpace.xs) {
            Text("Verify the system registered the assertion:")
                .font(DTTypography.caption)
                .foregroundStyle(DTColor.textSecondary)
            HStack(spacing: DTSpace.sm) {
                Button {
                    let pb = NSPasteboard.general
                    pb.clearContents()
                    pb.setString("pmset -g assertions", forType: .string)
                    didCopyCheckCommand = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        didCopyCheckCommand = false
                    }
                } label: {
                    Label(
                        didCopyCheckCommand ? "Copied" : "Copy pmset command",
                        systemImage: didCopyCheckCommand ? "checkmark" : "doc.on.doc"
                    )
                }
                .controlSize(.small)
                Text("Paste into Terminal to see which assertions DropThings holds.")
                    .font(DTTypography.caption)
                    .foregroundStyle(DTColor.textSecondary)
            }
        }
    }
}
