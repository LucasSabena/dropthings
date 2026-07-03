import SwiftUI
import DropThingsCore
import DropThingsDesignSystem

struct MenuBarCleanerSettingsView: View {
    @ObservedObject var module: MenuBarCleanerModule
    @State private var newBundleID: String = ""
    @State private var newDividerName: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: DTSpace.lg) {
            statusSection
            modeSection
            quickActionsSection
            profilesSection
            dividersSection
            alwaysVisibleSection
        }
    }

    // MARK: - Status

    private var statusSection: some View {
        SettingsSection(
            title: "Menu Bar Cleaner",
            caption: "Create a collapsible overflow area in the macOS menu bar."
        ) {
            HStack(alignment: .top, spacing: DTSpace.sm) {
                Image(systemName: module.isCollapsed ? "eye.slash" : "eye")
                    .foregroundStyle(module.isCollapsed ? DTColor.warning : DTColor.success)
                    .frame(width: DTSize.iconButton, height: DTSize.iconButton)
                    .background(DTColor.surfaceRaised)
                    .clipShape(RoundedRectangle(cornerRadius: DTRadius.md, style: .continuous))

                VStack(alignment: .leading, spacing: DTSpace.xxs) {
                    Text(module.isCollapsed ? "Overflow hidden" : "Overflow visible")
                        .font(DTTypography.body.weight(.semibold))
                    Text(module.statusMessage ?? "DropThings adds a divider and a chevron to your menu bar.")
                        .font(DTTypography.caption)
                        .foregroundStyle(DTColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }
        }
    }

    // MARK: - Mode

    private var modeSection: some View {
        SettingsSection(
            title: "Interaction mode",
            caption: "Choose what happens when you click the DropThings chevron in the menu bar."
        ) {
            VStack(alignment: .leading, spacing: DTSpace.md) {
                Picker("", selection: Binding(
                    get: { module.settings.drawerMode },
                    set: { module.setDrawerMode($0) }
                )) {
                    Text("Toggle collapse").tag(false)
                    Text("Open overflow drawer").tag(true)
                }
                .pickerStyle(.segmented)

                HStack(spacing: DTSpace.sm) {
                    Image(systemName: "info.circle")
                        .foregroundStyle(DTColor.textSecondary)
                    Text(module.settings.drawerMode
                         ? "A compact drawer opens with one-tap collapse, profiles, and settings."
                         : "The chevron immediately collapses or reveals the overflow area.")
                        .font(DTTypography.caption)
                        .foregroundStyle(DTColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    // MARK: - Quick actions

    private var quickActionsSection: some View {
        SettingsSection(
            title: "Quick actions",
            caption: "Try the overflow behavior without leaving settings."
        ) {
            VStack(alignment: .leading, spacing: DTSpace.md) {
                HStack(spacing: DTSpace.sm) {
                    Button {
                        module.toggleCollapsed()
                    } label: {
                        Label(module.isCollapsed ? "Reveal icons" : "Collapse icons",
                              systemImage: module.isCollapsed ? "chevron.right.circle" : "chevron.left.circle")
                    }
                    .controlSize(.regular)

                    Button {
                        module.showOverflowPanel()
                    } label: {
                        Label("Open drawer", systemImage: "rectangle.portrait.bottomhalf.inset.filled")
                    }
                    .controlSize(.regular)

                    Button {
                        module.safeReset()
                    } label: {
                        Label("Reset", systemImage: "arrow.counterclockwise")
                    }
                    .controlSize(.regular)
                }

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

                Toggle("Collapse on launch", isOn: Binding(
                    get: { module.collapseOnLaunch },
                    set: { module.setCollapseOnLaunch($0) }
                ))
            }
        }
    }

    // MARK: - Profiles

    private var profilesSection: some View {
        SettingsSection(
            title: "Profiles",
            caption: "Save collapse states for different moments. Tap a profile to switch."
        ) {
            VStack(alignment: .leading, spacing: DTSpace.sm) {
                Picker("Active profile", selection: Binding(
                    get: { module.settings.activeProfileID },
                    set: { module.setActiveProfile($0) }
                )) {
                    Text("None").tag(nil as UUID?)
                    ForEach(module.settings.profiles) { profile in
                        Text(profile.name).tag(profile.id as UUID?)
                    }
                }
                .pickerStyle(.menu)

                if let active = module.settings.activeProfile {
                    Toggle("Collapsed in this profile", isOn: Binding(
                        get: { active.collapsed },
                        set: { newValue in
                            var updated = active
                            updated.collapsed = newValue
                            module.updateProfile(updated)
                        }
                    ))
                    .font(DTTypography.body)
                }

                HStack {
                    Spacer()
                    Button {
                        module.addProfile(name: "New profile", collapsed: false)
                    } label: {
                        Label("Add profile", systemImage: "plus")
                    }
                    .controlSize(.small)
                }
            }
        }
    }

    // MARK: - Dividers

    private var dividersSection: some View {
        SettingsSection(
            title: "Dividers",
            caption: "Add named separators to group icons. Overflow dividers hide everything to their left when collapsed; visual dividers only separate groups."
        ) {
            VStack(alignment: .leading, spacing: DTSpace.sm) {
                ForEach(module.settings.dividers) { divider in
                    HStack(spacing: DTSpace.sm) {
                        Image(systemName: divider.symbolName)
                            .foregroundStyle(divider.id == MenuBarCleanerDivider.mainID ? DTColor.accent : DTColor.textSecondary)
                            .frame(width: 18)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(divider.name)
                                .font(DTTypography.body)
                            Text(divider.isOverflow ? "Overflow divider" : "Visual divider")
                                .font(DTTypography.caption)
                                .foregroundStyle(DTColor.textSecondary)
                        }
                        Spacer()
                        if divider.id != MenuBarCleanerDivider.mainID {
                            Button {
                                module.removeDivider(divider.id)
                            } label: {
                                Image(systemName: "xmark")
                                    .font(DTTypography.badgeButton)
                            }
                            .buttonStyle(.borderless)
                            .controlSize(.small)
                        }
                    }
                }

                HStack {
                    TextField("Divider name", text: $newDividerName)
                        .textFieldStyle(.roundedBorder)
                    Button("Add visual") {
                        guard !newDividerName.isEmpty else { return }
                        module.addDivider(name: newDividerName, isOverflow: false)
                        newDividerName = ""
                    }
                    .controlSize(.small)
                    .disabled(newDividerName.isEmpty)
                    Button("Add overflow") {
                        guard !newDividerName.isEmpty else { return }
                        module.addDivider(name: newDividerName, isOverflow: true)
                        newDividerName = ""
                    }
                    .controlSize(.small)
                    .disabled(newDividerName.isEmpty)
                }
            }
        }
    }

    // MARK: - Always visible

    private var alwaysVisibleSection: some View {
        SettingsSection(
            title: "Always visible",
            caption: "Bundle IDs of status items that should stay visible even when collapsed. This is a preference for future reordering; the divider model cannot force individual icons today."
        ) {
            VStack(alignment: .leading, spacing: DTSpace.xs) {
                if module.settings.alwaysVisibleBundleIDs.isEmpty {
                    Text("No bundle IDs pinned yet.")
                        .font(DTTypography.caption)
                        .foregroundStyle(DTColor.textSecondary)
                } else {
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
    }
}
