import SwiftUI
import DropThingsCore
import DropThingsDesignSystem

struct MenuBarCleanerSettingsView: View {
    @ObservedObject var module: MenuBarCleanerModule
    @State private var newBundleID: String = ""

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

                    Button {
                        module.safeReset()
                    } label: {
                        Label("Reset", systemImage: "arrow.counterclockwise")
                    }
                    .controlSize(.regular)
                }

                Toggle("Collapse on launch", isOn: Binding(
                    get: { module.collapseOnLaunch },
                    set: { module.setCollapseOnLaunch($0) }
                ))

                hoverDelayPicker

                profileSection

                alwaysVisibleSection

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

    private var hoverDelayPicker: some View {
        HStack {
            Text("Hover reveal")
                .font(DTTypography.body)
            Spacer()
            Picker("", selection: Binding(
                get: { module.hoverRevealDelay },
                set: { module.setHoverRevealDelay($0) }
            )) {
                Text("Off").tag(TimeInterval(0))
                Text("0.5 s").tag(TimeInterval(0.5))
                Text("1 s").tag(TimeInterval(1.0))
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
        }
    }

    private var profileSection: some View {
        VStack(alignment: .leading, spacing: DTSpace.xs) {
            HStack {
                Text("Profile")
                    .font(DTTypography.body.weight(.semibold))
                Spacer()
            }
            Picker("", selection: Binding(
                get: { module.settings.activeProfileID },
                set: { module.setActiveProfile($0) }
            )) {
                Text("None").tag(nil as UUID?)
                ForEach(module.settings.profiles) { profile in
                    Text(profile.name).tag(profile.id as UUID?)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .frame(width: 160)

            if let active = module.settings.activeProfile {
                Toggle("Profile collapsed", isOn: Binding(
                    get: { active.collapsed },
                    set: { newValue in
                        var updated = active
                        updated.collapsed = newValue
                        module.updateProfile(updated)
                    }
                ))
                .font(DTTypography.caption)
            }
        }
    }

    private var alwaysVisibleSection: some View {
        VStack(alignment: .leading, spacing: DTSpace.xs) {
            HStack {
                Text("Always visible")
                    .font(DTTypography.body.weight(.semibold))
                Spacer()
            }
            Text("Bundle IDs of status items that should stay visible even when collapsed. This is a hint for future reordering; the divider model cannot force individual icons today.")
                .font(DTTypography.caption)
                .foregroundStyle(DTColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(module.settings.alwaysVisibleBundleIDs, id: \.self) { bundleID in
                HStack {
                    Text(bundleID)
                        .font(DTTypography.caption.monospaced())
                        .lineLimit(1)
                    Spacer()
                    Button {
                        module.toggleAlwaysVisible(bundleID)
                    } label: {
                        Image(systemName: "xmark")
                            .font(DTTypography.badgeButton)
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                }
            }

            HStack {
                TextField("Bundle ID", text: $newBundleID)
                    .textFieldStyle(.roundedBorder)
                Button("Add") {
                    guard !newBundleID.isEmpty else { return }
                    module.toggleAlwaysVisible(newBundleID)
                    newBundleID = ""
                }
                .controlSize(.small)
                .disabled(newBundleID.isEmpty)
            }
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
