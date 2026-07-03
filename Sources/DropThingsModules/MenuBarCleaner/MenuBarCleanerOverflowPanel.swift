import AppKit
import SwiftUI
import DropThingsCore
import DropThingsDesignSystem

/// Floating control panel for Menu Bar Cleaner. Mimics the Windows-style
/// overflow tray: one click opens a compact drawer with the current state,
/// profiles, and quick actions.
public final class MenuBarCleanerOverflowPanelController {
    private let module: MenuBarCleanerModule
    private var panel: NSPanel?

    public init(module: MenuBarCleanerModule) {
        self.module = module
    }

    public func show(relativeTo button: NSStatusBarButton?) {
        if panel == nil {
            createPanel()
        }
        guard let panel else { return }
        positionPanel(panel, relativeTo: button)
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    public func hide() {
        panel?.orderOut(nil)
    }

    public var isVisible: Bool {
        panel?.isVisible == true
    }

    private func createPanel() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 320),
            styleMask: [.titled, .closable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.title = "Menu Bar Cleaner"
        panel.becomesKeyOnlyIfNeeded = true
        panel.hidesOnDeactivate = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.animationBehavior = .utilityWindow
        panel.isReleasedWhenClosed = false

        let view = MenuBarCleanerOverflowView(module: module)
        panel.contentView = NSHostingView(rootView: AnyView(view))
        self.panel = panel
    }

    private func positionPanel(_ panel: NSPanel, relativeTo button: NSStatusBarButton?) {
        guard let button, let screen = button.window?.screen ?? NSScreen.main else {
            panel.center()
            return
        }
        let buttonFrame = button.window?.convertToScreen(button.convert(button.bounds, to: nil)) ?? .zero
        let size = panel.frame.size
        let margin: CGFloat = 8
        var x = buttonFrame.midX - size.width / 2
        x = max(screen.visibleFrame.minX + margin, min(x, screen.visibleFrame.maxX - size.width - margin))
        let y = buttonFrame.minY - size.height - margin
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}

private struct MenuBarCleanerOverflowView: View {
    @ObservedObject var module: MenuBarCleanerModule

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DTSpace.lg) {
                header
                mainAction
                profileSection
                quickSettings
                Divider()
                guideSection
            }
            .padding(DTSpace.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(DTColor.background)
    }

    private var header: some View {
        HStack(spacing: DTSpace.md) {
            Image(systemName: module.isCollapsed ? "eye.slash" : "eye")
                .font(DTTypography.moduleHeaderIcon)
                .foregroundStyle(DTColor.accent)
                .frame(width: 40, height: 40)
                .background(DTColor.surfaceRaised)
                .clipShape(RoundedRectangle(cornerRadius: DTRadius.lg, style: .continuous))

            VStack(alignment: .leading, spacing: DTSpace.xxs) {
                Text(module.isCollapsed ? "Icons hidden" : "Icons visible")
                    .font(DTTypography.sectionTitle)
                Text(module.statusMessage ?? "DropThings manages an overflow area in the menu bar.")
                    .font(DTTypography.caption)
                    .foregroundStyle(DTColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var mainAction: some View {
        Button {
            module.toggleCollapsed()
        } label: {
            Label(
                module.isCollapsed ? "Reveal all icons" : "Hide overflow icons",
                systemImage: module.isCollapsed ? "chevron.right.circle" : "chevron.left.circle"
            )
            .font(DTTypography.body.weight(.semibold))
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .controlSize(.large)
        .buttonStyle(.borderedProminent)
    }

    private var profileSection: some View {
        VStack(alignment: .leading, spacing: DTSpace.sm) {
            Text("Profile")
                .font(DTTypography.sectionTitle)

            if module.settings.profiles.isEmpty {
                Text("No profiles yet. Create one in settings.")
                    .font(DTTypography.caption)
                    .foregroundStyle(DTColor.textSecondary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 72))], spacing: DTSpace.sm) {
                    ForEach(module.settings.profiles) { profile in
                        ProfileChip(
                            name: profile.name,
                            isActive: profile.id == module.settings.activeProfileID
                        ) {
                            module.setActiveProfile(profile.id)
                        }
                    }
                }
            }
        }
    }

    private var quickSettings: some View {
        VStack(alignment: .leading, spacing: DTSpace.sm) {
            Text("Quick settings")
                .font(DTTypography.sectionTitle)

            Toggle("Open drawer on click", isOn: Binding(
                get: { module.settings.drawerMode },
                set: { module.setDrawerMode($0) }
            ))
            .font(DTTypography.body)

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
                .frame(width: 120)
            }
        }
    }

    private var guideSection: some View {
        VStack(alignment: .leading, spacing: DTSpace.sm) {
            Text("How it works")
                .font(DTTypography.sectionTitle)
            guideRow(number: "1", text: "Command-drag the DropThings divider to mark the overflow edge.")
            guideRow(number: "2", text: "Drag low-priority icons to the left of the divider.")
            guideRow(number: "3", text: "Click here or the chevron to collapse or reveal them.")
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

private struct ProfileChip: View {
    let name: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(name)
                .font(DTTypography.caption.weight(.medium))
                .lineLimit(1)
                .padding(.horizontal, DTSpace.sm)
                .padding(.vertical, DTSpace.xs)
                .frame(maxWidth: .infinity)
                .background(isActive ? DTColor.accent.opacity(0.15) : DTColor.surfaceRaised)
                .foregroundStyle(isActive ? DTColor.accent : DTColor.textPrimary)
                .clipShape(RoundedRectangle(cornerRadius: DTRadius.md, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: DTRadius.md, style: .continuous)
                        .strokeBorder(isActive ? DTColor.accent : DTColor.border, lineWidth: isActive ? 1.5 : 0.5)
                )
        }
        .buttonStyle(.plain)
    }
}
