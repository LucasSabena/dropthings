import SwiftUI
import DropThingsDesignSystem

struct MenuBarCleanerSettingsView: View {
    @ObservedObject var module: MenuBarCleanerModule

    var body: some View {
        SettingsSection(
            title: "Menu Bar Cleaner",
            caption: "Create a collapsible overflow area in the macOS menu bar."
        ) {
            VStack(alignment: .leading, spacing: DTSpace.md) {
                statusRow

                HStack(spacing: DTSpace.sm) {
                    Button {
                        module.toggleCollapsed()
                    } label: {
                        Label(module.isCollapsed ? "Reveal icons" : "Collapse icons",
                              systemImage: module.isCollapsed ? "chevron.right.circle" : "chevron.left.circle")
                    }
                    .controlSize(.regular)

                    Button {
                        module.reveal()
                    } label: {
                        Label("Keep visible", systemImage: "eye")
                    }
                    .controlSize(.regular)
                    .disabled(!module.isCollapsed)
                }

                Toggle("Collapse on launch", isOn: Binding(
                    get: { module.collapseOnLaunch },
                    set: { module.setCollapseOnLaunch($0) }
                ))

                Divider()

                VStack(alignment: .leading, spacing: DTSpace.xs) {
                    guideRow(number: "1", text: "Hold Command and drag the DropThings divider to the menu bar position you want.")
                    guideRow(number: "2", text: "Command-drag low-priority icons to the left of that divider.")
                    guideRow(number: "3", text: "Click the DropThings chevron to collapse or reveal that side.")
                }
            }
        }
    }

    private var statusRow: some View {
        HStack(alignment: .top, spacing: DTSpace.sm) {
            Image(systemName: module.isCollapsed ? "eye.slash" : "eye")
                .foregroundStyle(DTColor.accent)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: DTSpace.xxs) {
                Text(module.isCollapsed ? "Overflow collapsed" : "Overflow visible")
                    .font(DTTypography.body.weight(.semibold))
                Text(module.statusMessage ?? "DropThings adds a divider and a chevron to your menu bar.")
                    .font(DTTypography.caption)
                    .foregroundStyle(DTColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
    }

    private func guideRow(number: String, text: String) -> some View {
        HStack(alignment: .top, spacing: DTSpace.sm) {
            Text(number)
                .font(DTTypography.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(DTColor.textSecondary)
                .frame(width: 18, height: 18)
                .background(DTColor.surfaceRaised)
                .clipShape(Circle())
            Text(text)
                .font(DTTypography.caption)
                .foregroundStyle(DTColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
