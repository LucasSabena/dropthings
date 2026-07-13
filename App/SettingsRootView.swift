import AppKit
import SwiftUI
import DropThingsCore
import DropThingsDesignSystem

private let productModuleOrder: [ModuleID] = [
    .fileShelf,
    .clipboardHistory,
    .colorPicker,
    .scrollControl,
    .keepAwake
]

private func productOrder(_ id: ModuleID) -> Int {
    productModuleOrder.firstIndex(of: id) ?? Int.max
}

struct SettingsRootView: View {
    @EnvironmentObject private var services: AppServices
    @AppStorage("ui.settings.sidebarSection") private var sectionRaw = SidebarItem.controlCenter.storageKey
    @AppStorage("ui.settings.sidebarModuleID") private var moduleIDRaw = ""

    private var currentSelection: SidebarItem {
        if !moduleIDRaw.isEmpty {
            let id = ModuleID(moduleIDRaw)
            if services.registry.modules[id] != nil { return .module(id) }
        }
        return SidebarItem.fromStorageKey(sectionRaw) ?? .controlCenter
    }

    private var selection: Binding<SidebarItem> {
        Binding(
            get: { currentSelection },
            set: { item in
                sectionRaw = item.storageKey
                if case .module(let id) = item {
                    moduleIDRaw = id.rawValue
                } else {
                    moduleIDRaw = ""
                }
            }
        )
    }

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(DTColor.background)
        }
        .navigationSplitViewStyle(.balanced)
        .tint(DTColor.accent)
    }

    private var sidebar: some View {
        List(selection: selection) {
            Section {
                Label("Control Center", systemImage: "switch.2")
                    .tag(SidebarItem.controlCenter)
                Label("Permissions", systemImage: "hand.raised")
                    .badge(permissionAttentionCount)
                    .tag(SidebarItem.permissions)
                Label("Settings", systemImage: "gearshape")
                    .tag(SidebarItem.settings)
            }

            Section("Utilities") {
                ForEach(orderedModules, id: \.id) { module in
                    SidebarModuleRow(
                        module: module,
                        state: services.registry.states[module.id] ?? .off
                    )
                    .tag(SidebarItem.module(module.id))
                }
            }

            Section {
                Label("About", systemImage: "info.circle")
                    .tag(SidebarItem.about)
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("DropThings")
        .navigationSplitViewColumnWidth(
            min: DTSize.sidebarWidth,
            ideal: DTSize.sidebarWidth,
            max: DTSize.sidebarWidth + DTSpace.xxl
        )
    }

    @ViewBuilder
    private var detail: some View {
        switch currentSelection {
        case .controlCenter:
            ControlCenterView(openModule: open)
        case .permissions:
            PermissionsCenterView()
        case .settings:
            AppSettingsView()
        case .about:
            AboutView()
        case .module(let id):
            ModuleDetailView(moduleID: id)
        }
    }

    private var orderedModules: [any DropThingsModule] {
        services.registry.modules.values.sorted {
            productOrder($0.id) < productOrder($1.id)
        }
    }

    private var permissionAttentionCount: Int {
        let missing = services.registry.states.values.reduce(into: Set<SystemPermission>()) { result, state in
            if case .needsPermission(let permissions) = state {
                result.formUnion(permissions)
            }
        }
        return missing.count
    }

    private func open(_ id: ModuleID) {
        moduleIDRaw = id.rawValue
        sectionRaw = SidebarItem.module(id).storageKey
    }
}

enum SidebarItem: Hashable {
    case controlCenter
    case permissions
    case settings
    case about
    case module(ModuleID)

    var storageKey: String {
        switch self {
        case .controlCenter: return "control-center"
        case .permissions: return "permissions"
        case .settings: return "settings"
        case .about: return "about"
        case .module(let id): return "module:\(id.rawValue)"
        }
    }

    static func fromStorageKey(_ key: String) -> SidebarItem? {
        switch key {
        case "control-center", "modules": return .controlCenter
        case "permissions", "diagnostics": return .permissions
        case "settings", "general": return .settings
        case "about": return .about
        default:
            guard key.hasPrefix("module:") else { return nil }
            return .module(ModuleID(String(key.dropFirst("module:".count))))
        }
    }
}

private struct SidebarModuleRow: View {
    let module: any DropThingsModule
    let state: ModuleState

    var body: some View {
        Label {
            HStack(spacing: DTSpace.xs) {
                Text(module.name)
                Spacer(minLength: 0)
                Circle()
                    .fill(statusColor)
                    .frame(width: DTSize.statusDot, height: DTSize.statusDot)
                    .accessibilityLabel(state.shortLabel)
            }
        } icon: {
            Image(systemName: module.iconName)
        }
    }

    private var statusColor: Color {
        switch state {
        case .running: return DTColor.success
        case .starting: return DTColor.accent
        case .needsPermission, .degraded: return DTColor.warning
        case .failed: return DTColor.danger
        case .off, .unavailable: return DTColor.textTertiary
        }
    }
}

private struct ControlCenterView: View {
    @EnvironmentObject private var services: AppServices
    @State private var permissionSetup: PermissionSetup?
    let openModule: (ModuleID) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DTSpace.xl) {
                PageHeader(
                    title: "Control Center",
                    subtitle: "Five focused utilities. Enable only what you use."
                ) {
                    StatusSummary(active: activeCount, total: orderedModules.count, attention: attentionCount)
                }

                if permissionAttentionCount > 0 {
                    AttentionBanner {
                        if let first = orderedModules.first(where: { !services.registry.missingPermissions(for: $0.id).isEmpty }) {
                            openPermissionSetup(for: first, disableOnCancel: false)
                        }
                    }
                }

                VStack(spacing: DTSpace.sm) {
                    ForEach(orderedModules, id: \.id) { module in
                        UtilityRow(
                            module: module,
                            state: services.registry.states[module.id] ?? .off,
                            isEnabled: services.registry.isEnabled(module.id),
                            onToggle: { setEnabled($0, module: module) },
                            onOpen: { openModule(module.id) },
                            onSetUpPermission: { openPermissionSetup(for: module, disableOnCancel: false) }
                        )
                    }
                }
            }
            .padding(DTSpace.xl)
            .frame(maxWidth: DTSize.contentMaxWidth, alignment: .leading)
        }
        .sheet(item: $permissionSetup) { setup in
            PermissionSetupView(setup: setup)
                .environmentObject(services)
        }
    }

    private var orderedModules: [any DropThingsModule] {
        services.registry.modules.values.sorted { productOrder($0.id) < productOrder($1.id) }
    }

    private var activeCount: Int {
        orderedModules.filter { services.registry.states[$0.id]?.isActive == true }.count
    }

    private var attentionCount: Int {
        orderedModules.filter { module in
            switch services.registry.states[module.id] ?? .off {
            case .needsPermission, .degraded, .failed: return true
            default: return false
            }
        }.count
    }

    private var permissionAttentionCount: Int {
        orderedModules.filter {
            if case .needsPermission = services.registry.states[$0.id] ?? .off { return true }
            return false
        }.count
    }

    private func setEnabled(_ enabled: Bool, module: any DropThingsModule) {
        if enabled, !services.registry.missingPermissions(for: module.id).isEmpty {
            services.registry.setEnabled(true, for: module.id)
            openPermissionSetup(for: module, disableOnCancel: true)
        } else {
            services.registry.setEnabled(enabled, for: module.id)
        }
    }

    private func openPermissionSetup(for module: any DropThingsModule, disableOnCancel: Bool) {
        guard let permission = services.registry.missingPermissions(for: module.id).first else { return }
        permissionSetup = PermissionSetup(
            moduleID: module.id,
            moduleName: module.name,
            moduleIcon: module.iconName,
            permission: permission,
            disableOnCancel: disableOnCancel
        )
    }
}

private struct PageHeader<Trailing: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: DTSpace.lg) {
            VStack(alignment: .leading, spacing: DTSpace.xs) {
                Text(title)
                    .font(DTTypography.pageTitle)
                    .foregroundStyle(DTColor.textPrimary)
                Text(subtitle)
                    .font(DTTypography.body)
                    .foregroundStyle(DTColor.textSecondary)
            }
            Spacer(minLength: DTSpace.lg)
            trailing()
        }
    }
}

private struct StatusSummary: View {
    let active: Int
    let total: Int
    let attention: Int

    var body: some View {
        HStack(spacing: DTSpace.xs) {
            Circle()
                .fill(attention == 0 ? DTColor.success : DTColor.warning)
                .frame(width: DTSize.statusDot, height: DTSize.statusDot)
            Text(attention == 0 ? "\(active) of \(total) active" : "\(attention) needs attention")
                .font(DTTypography.caption.weight(.medium))
                .foregroundStyle(DTColor.textSecondary)
        }
    }
}

private struct AttentionBanner: View {
    let action: () -> Void

    var body: some View {
        HStack(spacing: DTSpace.md) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(DTColor.warning)
            VStack(alignment: .leading, spacing: DTSpace.xxs) {
                Text("One utility needs your attention")
                    .font(DTTypography.body.weight(.semibold))
                Text("Finish its permission setup to make the shortcut and background behavior available.")
                    .font(DTTypography.caption)
                    .foregroundStyle(DTColor.textSecondary)
            }
            Spacer()
            Button("Review", action: action)
                .controlSize(.small)
        }
        .padding(DTSpace.md)
        .background(DTColor.warning.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: DTRadius.lg, style: .continuous))
    }
}

private struct UtilityRow: View {
    let module: any DropThingsModule
    let state: ModuleState
    let isEnabled: Bool
    let onToggle: (Bool) -> Void
    let onOpen: () -> Void
    let onSetUpPermission: () -> Void

    var body: some View {
        HStack(spacing: DTSpace.md) {
            Image(systemName: module.iconName)
                .font(DTTypography.moduleIcon)
                .foregroundStyle(isEnabled ? DTColor.accent : DTColor.textSecondary)
                .frame(width: DTSize.utilityIcon, height: DTSize.utilityIcon)
                .background(DTColor.surfaceRaised)
                .clipShape(RoundedRectangle(cornerRadius: DTRadius.lg, style: .continuous))

            VStack(alignment: .leading, spacing: DTSpace.xxs) {
                Text(module.name)
                    .font(DTTypography.body.weight(.semibold))
                Text(module.summary)
                    .font(DTTypography.caption)
                    .foregroundStyle(DTColor.textSecondary)
                    .lineLimit(2)
                if case .needsPermission = state {
                    Button("Finish permission setup", action: onSetUpPermission)
                        .buttonStyle(.link)
                        .controlSize(.small)
                }
            }

            Spacer(minLength: DTSpace.md)

            ModuleStateLabel(state: state)

            Toggle("", isOn: Binding(get: { isEnabled }, set: onToggle))
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
                .disabled(isUnavailable)

            Button(action: onOpen) {
                Image(systemName: "chevron.right")
                    .foregroundStyle(DTColor.textSecondary)
                    .frame(width: DTSize.iconButton, height: DTSize.iconButton)
            }
            .buttonStyle(.plain)
            .help("Open \(module.name) settings")
            .accessibilityLabel("Open \(module.name) settings")
        }
        .padding(DTSpace.md)
        .background(DTColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: DTRadius.lg, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: DTRadius.lg, style: .continuous)
                .strokeBorder(DTColor.border.opacity(0.7), lineWidth: 0.5)
        }
    }

    private var isUnavailable: Bool {
        if case .unavailable = state { return true }
        return false
    }
}

private struct ModuleStateLabel: View {
    let state: ModuleState

    var body: some View {
        HStack(spacing: DTSpace.xs) {
            Circle()
                .fill(color)
                .frame(width: DTSize.statusDot, height: DTSize.statusDot)
            Text(label)
                .font(DTTypography.caption)
                .foregroundStyle(DTColor.textSecondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Status: \(label)")
    }

    private var label: String {
        switch state {
        case .off: return "Off"
        case .starting: return "Starting"
        case .running: return "Ready"
        case .needsPermission: return "Permission"
        case .unavailable: return "Unavailable"
        case .degraded: return "Limited"
        case .failed: return "Error"
        }
    }

    private var color: Color {
        switch state {
        case .running: return DTColor.success
        case .starting: return DTColor.accent
        case .needsPermission, .degraded: return DTColor.warning
        case .failed: return DTColor.danger
        case .off, .unavailable: return DTColor.textTertiary
        }
    }
}

private struct ModuleDetailView: View {
    @EnvironmentObject private var services: AppServices
    @State private var permissionSetup: PermissionSetup?
    let moduleID: ModuleID

    var body: some View {
        Group {
            if let module = services.registry.modules[moduleID] {
                ScrollView {
                    VStack(alignment: .leading, spacing: DTSpace.xl) {
                        moduleHeader(module)
                        stateMessage(services.registry.states[module.id] ?? .off)
                        module.makeSettingsView()
                            .environmentObject(services)
                    }
                    .padding(DTSpace.xl)
                    .frame(maxWidth: DTSize.contentMaxWidth, alignment: .leading)
                }
                .sheet(item: $permissionSetup) { setup in
                    PermissionSetupView(setup: setup)
                        .environmentObject(services)
                }
            } else {
                ContentUnavailableView("Utility unavailable", systemImage: "questionmark.app")
            }
        }
    }

    private func moduleHeader(_ module: any DropThingsModule) -> some View {
        let state = services.registry.states[module.id] ?? .off
        return HStack(spacing: DTSpace.md) {
            Image(systemName: module.iconName)
                .font(DTTypography.moduleHeaderIcon)
                .foregroundStyle(DTColor.accent)
                .frame(width: DTSize.moduleHeaderIcon, height: DTSize.moduleHeaderIcon)
                .background(DTColor.surfaceRaised)
                .clipShape(RoundedRectangle(cornerRadius: DTRadius.lg, style: .continuous))
            VStack(alignment: .leading, spacing: DTSpace.xxs) {
                Text(module.name)
                    .font(DTTypography.pageTitle)
                Text(module.summary)
                    .font(DTTypography.body)
                    .foregroundStyle(DTColor.textSecondary)
            }
            Spacer()
            ModuleStateLabel(state: state)
            Toggle("", isOn: Binding(
                get: { services.registry.isEnabled(module.id) },
                set: { setEnabled($0, module: module) }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
        }
    }

    @ViewBuilder
    private func stateMessage(_ state: ModuleState) -> some View {
        switch state {
        case .needsPermission(let missing):
            PermissionCallout(permission: missing.first ?? .accessibility) {
                guard let module = services.registry.modules[moduleID],
                      let permission = missing.first else { return }
                permissionSetup = PermissionSetup(
                    moduleID: module.id,
                    moduleName: module.name,
                    moduleIcon: module.iconName,
                    permission: permission,
                    disableOnCancel: false
                )
            }
        case .degraded(let reason):
            InlineAlert(style: .warning, message: reason)
        case .failed(let reason, let recovery):
            InlineAlert(style: .error, message: recovery.map { "\(reason) — \($0)" } ?? reason)
        case .unavailable(let reason):
            InlineAlert(style: .warning, message: reason)
        case .starting:
            InlineAlert(style: .info, message: "Starting…")
        case .off, .running:
            EmptyView()
        }
    }

    private func setEnabled(_ enabled: Bool, module: any DropThingsModule) {
        if enabled, let permission = services.registry.missingPermissions(for: module.id).first {
            services.registry.setEnabled(true, for: module.id)
            permissionSetup = PermissionSetup(
                moduleID: module.id,
                moduleName: module.name,
                moduleIcon: module.iconName,
                permission: permission,
                disableOnCancel: true
            )
        } else {
            services.registry.setEnabled(enabled, for: module.id)
        }
    }
}

private struct PermissionCallout: View {
    let permission: SystemPermission
    let action: () -> Void

    var body: some View {
        HStack(spacing: DTSpace.md) {
            Image(systemName: permission.iconName)
                .foregroundStyle(DTColor.warning)
            VStack(alignment: .leading, spacing: DTSpace.xxs) {
                Text("\(permission.displayName) is required")
                    .font(DTTypography.body.weight(.semibold))
                Text(permission.reason)
                    .font(DTTypography.caption)
                    .foregroundStyle(DTColor.textSecondary)
            }
            Spacer()
            Button("Set Up", action: action)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        }
        .padding(DTSpace.md)
        .background(DTColor.warning.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: DTRadius.lg, style: .continuous))
    }
}

private struct PermissionSetup: Identifiable {
    let moduleID: ModuleID
    let moduleName: String
    let moduleIcon: String
    let permission: SystemPermission
    let disableOnCancel: Bool

    var id: String { "\(moduleID.rawValue):\(permission.rawValue)" }
}

private struct PermissionSetupView: View {
    @EnvironmentObject private var services: AppServices
    @Environment(\.dismiss) private var dismiss
    @State private var didRequest = false
    let setup: PermissionSetup

    private var state: SystemPermissionState {
        services.permissions.state(for: setup.permission)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DTSpace.xl) {
            HStack(alignment: .top, spacing: DTSpace.md) {
                Image(systemName: setup.moduleIcon)
                    .font(DTTypography.moduleHeaderIcon)
                    .foregroundStyle(DTColor.accent)
                    .frame(width: DTSize.moduleHeaderIcon, height: DTSize.moduleHeaderIcon)
                    .background(DTColor.surfaceRaised)
                    .clipShape(RoundedRectangle(cornerRadius: DTRadius.lg, style: .continuous))
                VStack(alignment: .leading, spacing: DTSpace.xs) {
                    Text("Allow \(setup.moduleName) to work")
                        .font(DTTypography.pageTitle)
                    Text(setup.permission.reason)
                        .font(DTTypography.body)
                        .foregroundStyle(DTColor.textSecondary)
                }
            }

            VStack(alignment: .leading, spacing: DTSpace.md) {
                Label("Why this is needed", systemImage: "hand.raised.fill")
                    .font(DTTypography.sectionTitle)
                Text(setup.permission.privacyDetail)
                    .font(DTTypography.body)
                    .foregroundStyle(DTColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Divider()
                Label("You stay in control", systemImage: "checkmark.shield.fill")
                    .font(DTTypography.sectionTitle)
                Text("You can turn the utility off in DropThings or revoke access later in System Settings.")
                    .font(DTTypography.body)
                    .foregroundStyle(DTColor.textSecondary)
            }
            .padding(DTSpace.lg)
            .background(DTColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: DTRadius.lg, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: DTRadius.lg, style: .continuous)
                    .strokeBorder(DTColor.border, lineWidth: 0.5)
            }

            if didRequest || state == .denied {
                VStack(alignment: .leading, spacing: DTSpace.xs) {
                    Text("Finish in System Settings")
                        .font(DTTypography.sectionTitle)
                    Text("Open \(setup.permission.settingsPath), enable DropThings, then return here. The utility starts automatically when access is detected.")
                        .font(DTTypography.caption)
                        .foregroundStyle(DTColor.textSecondary)
                }
            }

            HStack {
                Button("Not Now") {
                    if setup.disableOnCancel {
                        services.registry.setEnabled(false, for: setup.moduleID)
                    }
                    dismiss()
                }
                Spacer()
                if didRequest || state == .denied {
                    Button("Check Again") { recheck() }
                    Button("Open System Settings") {
                        services.permissions.openSystemSettings(for: setup.permission)
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button("Continue") { request() }
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding(DTSpace.xl)
        .frame(width: DTSize.permissionSheetWidth)
        .onChange(of: state) { _, newState in
            if newState == .granted {
                Task {
                    await services.registry.refreshPermissionsAndRetry()
                    dismiss()
                }
            }
        }
    }

    private func request() {
        didRequest = true
        _ = services.permissions.requestPermission(setup.permission)
        if services.permissions.state(for: setup.permission) == .granted {
            recheck()
        }
    }

    private func recheck() {
        Task {
            await services.registry.refreshPermissionsAndRetry()
            if services.permissions.state(for: setup.permission) == .granted {
                dismiss()
            }
        }
    }
}

private struct PermissionsCenterView: View {
    @EnvironmentObject private var services: AppServices

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DTSpace.xl) {
                PageHeader(
                    title: "Permissions",
                    subtitle: "DropThings asks only when a utility needs access."
                ) {
                    Button {
                        Task { await services.registry.refreshPermissionsAndRetry() }
                    } label: {
                        Label("Check Again", systemImage: "arrow.clockwise")
                    }
                    .controlSize(.small)
                }

                if requiredPermissions.allSatisfy({ services.permissions.state(for: $0) == .granted }) {
                    InlineAlert(style: .success, message: "Every permission used by your installed utilities is ready.")
                }

                SettingsSection(
                    title: "Used by your utilities",
                    caption: "No permission is requested just by opening DropThings."
                ) {
                    VStack(spacing: 0) {
                        ForEach(requiredPermissions, id: \.self) { permission in
                            PermissionRow(
                                permission: permission,
                                state: services.permissions.state(for: permission),
                                onOpenSettings: { services.permissions.openSystemSettings(for: permission) },
                                onRequest: { services.permissions.requestPermission(permission) }
                            )
                            if permission != requiredPermissions.last { Divider() }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: DTSpace.xs) {
                    Label("What DropThings does not request", systemImage: "lock.shield")
                        .font(DTTypography.sectionTitle)
                    Text("The current six utilities do not require Screen Recording, Full Disk Access, Contacts, Camera, or Microphone access. Markdown Viewer requests Finder Automation only if you enable its optional selection shortcut.")
                        .font(DTTypography.body)
                        .foregroundStyle(DTColor.textSecondary)
                }
            }
            .padding(DTSpace.xl)
            .frame(maxWidth: DTSize.contentMaxWidth, alignment: .leading)
        }
    }

    private var requiredPermissions: [SystemPermission] {
        Array(Set(services.registry.modules.values.flatMap(\.requiredPermissions)))
            .sorted { $0.displayName < $1.displayName }
    }
}

private struct AppSettingsView: View {
    @EnvironmentObject private var services: AppServices
    @State private var didCopyDiagnostics = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DTSpace.xl) {
                PageHeader(title: "Settings", subtitle: "App-wide behavior and support tools.") { EmptyView() }
                startup
                data
                diagnostics
            }
            .padding(DTSpace.xl)
            .frame(maxWidth: DTSize.contentMaxWidth, alignment: .leading)
        }
        .onAppear { services.launchAtLogin.refresh() }
    }

    private var startup: some View {
        SettingsSection(title: "Startup") {
            VStack(alignment: .leading, spacing: DTSpace.sm) {
                Toggle(isOn: Binding(
                    get: { services.launchAtLogin.isEnabled },
                    set: { services.launchAtLogin.setEnabled($0) }
                )) {
                    VStack(alignment: .leading, spacing: DTSpace.xxs) {
                        Text("Open DropThings at login")
                            .font(DTTypography.body.weight(.semibold))
                        Text("Keep shortcuts and background utilities available after you sign in.")
                            .font(DTTypography.caption)
                            .foregroundStyle(DTColor.textSecondary)
                    }
                }
                .toggleStyle(.switch)

                if services.launchAtLogin.needsApproval {
                    InlineAlert(style: .warning, message: "macOS needs you to approve DropThings in Login Items.")
                    Button("Open Login Items") { services.launchAtLogin.openLoginItemsSettings() }
                        .controlSize(.small)
                }
                if let error = services.launchAtLogin.lastError {
                    InlineAlert(style: .error, message: error)
                }
            }
        }
    }

    private var data: some View {
        SettingsSection(
            title: "Backup",
            caption: "Export or restore utility preferences. Importing relaunches the app."
        ) {
            HStack(spacing: DTSpace.sm) {
                Button("Export Settings…") { services.exportSettings() }
                Button("Import Settings…") { services.importSettings() }
            }
            .controlSize(.small)
        }
    }

    private var diagnostics: some View {
        SettingsSection(
            title: "Support",
            caption: "Copy a compact snapshot without personal clipboard or file history."
        ) {
            HStack {
                VStack(alignment: .leading, spacing: DTSpace.xxs) {
                    Text("Version \(services.bundleInfo.shortVersion) (\(services.bundleInfo.buildNumber))")
                        .font(DTTypography.body)
                    Text("\(services.diagnostics.entries.count) recent diagnostic events")
                        .font(DTTypography.caption)
                        .foregroundStyle(DTColor.textSecondary)
                }
                Spacer()
                Button {
                    copyDiagnostics()
                } label: {
                    Label(didCopyDiagnostics ? "Copied" : "Copy Diagnostics", systemImage: didCopyDiagnostics ? "checkmark" : "doc.on.doc")
                }
                .controlSize(.small)
            }
        }
    }

    private func copyDiagnostics() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(services.diagnosticSnapshot(), forType: .string)
        didCopyDiagnostics = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { didCopyDiagnostics = false }
    }
}

private struct AboutView: View {
    @EnvironmentObject private var services: AppServices

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DTSpace.xl) {
                HStack(spacing: DTSpace.lg) {
                    Image("DropThingsLogoTransparent")
                        .resizable()
                        .scaledToFit()
                        .frame(width: DTSize.aboutIcon, height: DTSize.aboutIcon)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: DTSpace.xs) {
                        Text("DropThings")
                            .font(DTTypography.pageTitle)
                        Text("Five small utilities. Native, local, and under your control.")
                            .font(DTTypography.body)
                            .foregroundStyle(DTColor.textSecondary)
                        Text("Version \(services.bundleInfo.shortVersion) (\(services.bundleInfo.buildNumber))")
                            .font(DTTypography.caption.monospacedDigit())
                            .foregroundStyle(DTColor.textSecondary)
                    }
                }

                SettingsSection(title: "Updates") {
                    VStack(alignment: .leading, spacing: DTSpace.md) {
                        HStack {
                            Label(updateTitle, systemImage: updateIcon)
                                .font(DTTypography.body.weight(.semibold))
                                .foregroundStyle(updateColor)
                            Spacer()
                            Button("Check for Updates") { services.updates.checkNow() }
                                .disabled(services.updates.state == .checking)
                        }
                        Toggle("Check automatically", isOn: Binding(
                            get: { services.updates.automaticChecksEnabled },
                            set: { services.updates.automaticChecksEnabled = $0 }
                        ))
                        .toggleStyle(.checkbox)
                    }
                }
            }
            .padding(DTSpace.xl)
            .frame(maxWidth: DTSize.contentMaxWidth, alignment: .leading)
        }
    }

    private var updateTitle: String {
        switch services.updates.state {
        case .idle: return "Ready to check"
        case .checking: return "Checking…"
        case .upToDate: return "DropThings is up to date"
        case .updateAvailable(let version, _): return "Version \(version) is available"
        case .downloading(let progress): return "Downloading \(Int(progress * 100))%"
        case .installing: return "Installing update…"
        case .failed: return "Could not check for updates"
        }
    }

    private var updateIcon: String {
        switch services.updates.state {
        case .upToDate: return "checkmark.circle.fill"
        case .updateAvailable, .downloading, .installing: return "arrow.down.circle.fill"
        case .failed: return "exclamationmark.triangle.fill"
        case .idle, .checking: return "arrow.clockwise"
        }
    }

    private var updateColor: Color {
        switch services.updates.state {
        case .upToDate: return DTColor.success
        case .updateAvailable, .downloading, .installing: return DTColor.accent
        case .failed: return DTColor.warning
        case .idle, .checking: return DTColor.textSecondary
        }
    }
}
