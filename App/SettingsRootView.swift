import SwiftUI
import DropThingsCore
import DropThingsDesignSystem

struct SettingsRootView: View {
    @EnvironmentObject private var services: AppServices
    @State private var selection: SidebarItem = .general

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detail
        }
        .navigationSplitViewStyle(.balanced)
        .background(DTColor.background)
    }

    private var sidebar: some View {
        List(selection: $selection) {
            Section("App") {
                Label("General", systemImage: "gearshape")
                    .tag(SidebarItem.general)
                Label("Modules", systemImage: "square.stack.3d.up")
                    .tag(SidebarItem.modules)
                Label("Diagnostics", systemImage: "stethoscope")
                    .tag(SidebarItem.diagnostics)
                Label("About", systemImage: "info.circle")
                    .tag(SidebarItem.about)
            }
            Section("Modules") {
                ForEach(orderedModules(), id: \.key) { entry in
                    ModuleSidebarRow(module: entry.value, state: services.registry.states[entry.key] ?? .off)
                        .tag(SidebarItem.module(entry.key))
                }
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: DTSize.sidebarWidth, ideal: DTSize.sidebarWidth)
    }

    @ViewBuilder
    private var detail: some View {
        switch selection {
        case .general:
            GeneralSettingsView()
        case .modules:
            ModulesOverviewView()
        case .diagnostics:
            DiagnosticsView()
        case .about:
            AboutView()
        case .module(let id):
            ModuleDetailView(moduleID: id)
        }
    }

    private func orderedModules() -> [(key: ModuleID, value: any DropThingsModule)] {
        services.registry.modules
            .map { ($0.key, $0.value) }
            .sorted { $0.0.rawValue < $1.0.rawValue }
    }
}

enum SidebarItem: Hashable {
    case general
    case modules
    case diagnostics
    case about
    case module(ModuleID)
}

private struct GeneralSettingsView: View {
    @EnvironmentObject private var services: AppServices

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DTSpace.lg) {
                Text("General")
                    .font(DTTypography.windowTitle)
                Text("App-wide behavior for DropThings.")
                    .font(DTTypography.body)
                    .foregroundStyle(DTColor.textSecondary)

                startupSection
            }
            .padding(DTSpace.xl)
            .frame(maxWidth: 720, alignment: .leading)
        }
        .onAppear {
            services.launchAtLogin.refresh()
        }
    }

    private var startupSection: some View {
        SettingsSection(
            title: "Startup",
            caption: "Use macOS Login Items so DropThings opens automatically after you sign in."
        ) {
            VStack(alignment: .leading, spacing: DTSpace.sm) {
                Toggle(isOn: Binding(
                    get: { services.launchAtLogin.isEnabled },
                    set: { services.launchAtLogin.setEnabled($0) }
                )) {
                    VStack(alignment: .leading, spacing: DTSpace.xxs) {
                        Text("Open DropThings at login")
                            .font(DTTypography.body.weight(.semibold))
                        Text("Status: \(services.launchAtLogin.statusLabel)")
                            .font(DTTypography.caption)
                            .foregroundStyle(DTColor.textSecondary)
                    }
                }
                .toggleStyle(.switch)

                if services.launchAtLogin.needsApproval {
                    InlineAlert(
                        style: .warning,
                        message: "macOS needs you to approve DropThings in Login Items before it can open at startup."
                    )
                    Button {
                        services.launchAtLogin.openLoginItemsSettings()
                    } label: {
                        Label("Open Login Items", systemImage: "arrow.up.forward.app")
                    }
                    .controlSize(.small)
                }

                if let error = services.launchAtLogin.lastError {
                    InlineAlert(style: .error, message: error)
                }
            }
        }
    }
}

private struct ModuleSidebarRow: View {
    let module: any DropThingsModule
    let state: ModuleState

    var body: some View {
        HStack(spacing: DTSpace.sm) {
            Image(systemName: module.iconName)
                .frame(width: 18)
                .foregroundStyle(DTColor.accent)
            VStack(alignment: .leading, spacing: 0) {
                Text(module.name)
                    .font(DTTypography.body)
                Text(state.shortLabel)
                    .font(DTTypography.caption)
                    .foregroundStyle(DTColor.textSecondary)
            }
        }
    }
}

private struct ModulesOverviewView: View {
    @EnvironmentObject private var services: AppServices

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DTSpace.lg) {
                Text("Modules")
                    .font(DTTypography.windowTitle)
                Text("Enable one module at a time. Each module asks for the permissions it actually needs.")
                    .font(DTTypography.body)
                    .foregroundStyle(DTColor.textSecondary)

                ForEach(services.registry.modules.map(\.value), id: \.id) { module in
                    ModuleRow(
                        module: module,
                        state: services.registry.states[module.id] ?? .off,
                        isEnabled: services.registry.isEnabled(module.id)
                    ) { newValue in
                        services.registry.setEnabled(newValue, for: module.id)
                    }
                }
            }
            .padding(DTSpace.xl)
            .frame(maxWidth: 720, alignment: .leading)
        }
    }
}

private struct ModuleDetailView: View {
    @EnvironmentObject private var services: AppServices
    let moduleID: ModuleID

    var body: some View {
        if let module = services.registry.modules[moduleID] {
            ScrollView {
                VStack(alignment: .leading, spacing: DTSpace.lg) {
                    header(module: module)

                    if !module.requiredPermissions.isEmpty {
                        permissionsSection(module: module)
                    }

                    module.makeSettingsView()
                        .environmentObject(services)
                }
                .padding(DTSpace.xl)
                .frame(maxWidth: 720, alignment: .leading)
            }
        } else {
            Text("Module not registered.")
                .foregroundStyle(DTColor.textSecondary)
                .padding()
        }
    }

    private func header(module: any DropThingsModule) -> some View {
        let state = services.registry.states[module.id] ?? .off
        return VStack(alignment: .leading, spacing: DTSpace.sm) {
            HStack(alignment: .center, spacing: DTSpace.md) {
                Image(systemName: module.iconName)
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(DTColor.accent)
                    .frame(width: 48, height: 48)
                    .background(DTColor.surfaceRaised)
                    .clipShape(RoundedRectangle(cornerRadius: DTRadius.lg, style: .continuous))
                VStack(alignment: .leading, spacing: DTSpace.xxs) {
                    Text(module.name)
                        .font(DTTypography.windowTitle)
                    Text(module.summary)
                        .font(DTTypography.body)
                        .foregroundStyle(DTColor.textSecondary)
                }
                Spacer()
                ModuleStatusPill(state: state)
            }
            HStack {
                Toggle(isOn: Binding(
                    get: { services.registry.isEnabled(module.id) },
                    set: { services.registry.setEnabled($0, for: module.id) }
                )) {
                    Text(state.isOff ? "Enable" : "Enabled")
                        .font(DTTypography.body.weight(.semibold))
                }
                .toggleStyle(.switch)
                Spacer()
                if case .needsPermission(let missing) = state {
                    Button("Refresh permissions") {
                        Task {
                            services.permissions.refresh()
                            await services.registry.refreshPermissionsAndRetry()
                        }
                    }
                    .controlSize(.small)
                    .help("Missing: \(missing.map(\.displayName).joined(separator: ", "))")
                }
            }
            alert(for: state)
        }
    }

    @ViewBuilder
    private func alert(for state: ModuleState) -> some View {
        switch state {
        case .off:
            EmptyView()
        case .starting:
            InlineAlert(style: .info, message: "Starting…")
        case .running:
            InlineAlert(style: .success, message: "This module is active.")
        case .needsPermission(let missing):
            InlineAlert(
                style: .warning,
                message: "Grant \(missing.map(\.displayName).joined(separator: ", ")) to use this module."
            )
        case .unavailable(let reason):
            InlineAlert(style: .warning, message: reason)
        case .degraded(let reason):
            InlineAlert(style: .warning, message: reason)
        case .failed(let reason, let recovery):
            InlineAlert(
                style: .error,
                message: recovery.map { "\(reason) — \($0)" } ?? reason
            )
        }
    }

    @ViewBuilder
    private func permissionsSection(module: any DropThingsModule) -> some View {
        SettingsSection(
            title: "Permissions",
            caption: "Requested only when you enable this module."
        ) {
            VStack(spacing: 0) {
                ForEach(module.requiredPermissions, id: \.self) { permission in
                    PermissionRow(
                        permission: permission,
                        state: services.permissions.state(for: permission),
                        onOpenSettings: {
                            services.permissions.openSystemSettings(for: permission)
                        },
                        onRequest: {
                            services.permissions.requestPermission(permission)
                        }
                    )
                    if permission != module.requiredPermissions.last {
                        Divider()
                    }
                }
            }
        }
    }
}

private struct DiagnosticsView: View {
    @EnvironmentObject private var services: AppServices
    @State private var didCopyInfo = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DTSpace.lg) {
                Text("Diagnostics")
                    .font(DTTypography.windowTitle)
                Text("Recent in-app events. Long-term logs live in Console.app under subsystem app.dropthings.")
                    .font(DTTypography.body)
                    .foregroundStyle(DTColor.textSecondary)

                bundleSection
                permissionsSection
                recentEventsSection
                troubleshootingSection
            }
            .padding(DTSpace.xl)
            .frame(maxWidth: 820, alignment: .leading)
        }
    }

    private var bundleSection: some View {
        SettingsSection(title: "App", caption: "What macOS sees when granting permissions.") {
            VStack(alignment: .leading, spacing: DTSpace.xs) {
                let bundleInfo = services.bundleInfo
                keyValue("Bundle ID", bundleInfo.bundleIdentifier)
                keyValue("Bundle path", bundleInfo.bundlePath)
                keyValue("Version",
                         "\(bundleInfo.shortVersion) (\(bundleInfo.buildNumber))")
                HStack {
                    Text("Accessibility (AX) trusted")
                        .font(DTTypography.body)
                    Spacer()
                    Text(bundleInfo.axIsProcessTrusted ? "yes" : "no")
                        .font(DTTypography.caption.monospacedDigit())
                        .foregroundStyle(bundleInfo.axIsProcessTrusted ? DTColor.success : DTColor.warning)
                }
                if !bundleInfo.axIsProcessTrusted {
                    InlineAlert(
                        style: .warning,
                        message: "If System Settings already shows DropThings enabled, reset the stale macOS permission entry and approve it again."
                    )
                }
                HStack {
                    Spacer()
                    Button {
                        copyDiagnosticInfo()
                    } label: {
                        Label(didCopyInfo ? "Copied" : "Copy diagnostic info",
                              systemImage: didCopyInfo ? "checkmark" : "doc.on.doc")
                    }
                    .controlSize(.small)
                    Button {
                        services.permissions.refresh()
                    } label: {
                        Label("Refresh permissions", systemImage: "arrow.clockwise")
                    }
                    .controlSize(.small)
                    Button {
                        services.repairAccessibilityTrust()
                    } label: {
                        Label("Reset & Request Accessibility", systemImage: "wrench.and.screwdriver")
                    }
                    .controlSize(.small)
                }
            }
        }
    }

    private var permissionsSection: some View {
        SettingsSection(title: "Permissions") {
            VStack(alignment: .leading, spacing: DTSpace.xs) {
                ForEach(SystemPermission.allCases, id: \.self) { permission in
                    HStack {
                        Text(permission.displayName)
                        Spacer()
                        Text(stateLabel(permission))
                            .font(DTTypography.caption)
                            .foregroundStyle(stateColor(services.permissions.state(for: permission)))
                    }
                }
            }
        }
    }

    private var recentEventsSection: some View {
        SettingsSection(
            title: "Recent events",
            caption: "Last \(min(services.diagnostics.entries.count, DiagnosticsStore.maxEntries)) entries"
        ) {
            if services.diagnostics.entries.isEmpty {
                Text("No events yet. Enable a module to generate entries.")
                    .font(DTTypography.caption)
                    .foregroundStyle(DTColor.textSecondary)
            } else {
                VStack(alignment: .leading, spacing: DTSpace.xs) {
                    ForEach(services.diagnostics.entries.reversed()) { entry in
                        HStack(alignment: .top, spacing: DTSpace.sm) {
                            Text(entry.level.rawValue.uppercased())
                                .font(DTTypography.caption.weight(.bold))
                                .foregroundStyle(levelColor(entry.level))
                                .frame(width: 60, alignment: .leading)
                            Text(entry.category)
                                .font(DTTypography.caption)
                                .foregroundStyle(DTColor.textSecondary)
                                .frame(width: 100, alignment: .leading)
                            Text(entry.message)
                                .font(DTTypography.caption)
                        }
                    }
                }
            }
        }
    }

    private var troubleshootingSection: some View {
        SettingsSection(title: "Permissions stuck?", caption: "If a module says Needs permission even after you granted access in System Settings.") {
            Text(BundleInfo.resetHint)
                .font(DTTypography.caption.monospaced())
                .foregroundStyle(DTColor.textSecondary)
                .textSelection(.enabled)
        }
    }

    private func keyValue(_ key: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(key)
                .font(DTTypography.body)
            Spacer()
            Text(value)
                .font(DTTypography.caption.monospaced())
                .foregroundStyle(DTColor.textSecondary)
                .textSelection(.enabled)
                .multilineTextAlignment(.trailing)
        }
    }

    private func stateLabel(_ permission: SystemPermission) -> String {
        switch services.permissions.state(for: permission) {
        case .granted: return "Granted"
        case .denied: return "Denied"
        case .notDetermined: return "Not granted"
        case .unknown: return "Unknown"
        }
    }

    private func stateColor(_ state: SystemPermissionState) -> Color {
        switch state {
        case .granted: return DTColor.success
        case .denied: return DTColor.danger
        case .notDetermined: return DTColor.warning
        case .unknown: return DTColor.textSecondary
        }
    }

    private func levelColor(_ level: LogLevel) -> Color {
        switch level {
        case .info: return DTColor.textSecondary
        case .notice: return DTColor.accent
        case .warning: return DTColor.warning
        case .error: return DTColor.danger
        }
    }

    private func copyDiagnosticInfo() {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(services.diagnosticSnapshot(), forType: .string)
        didCopyInfo = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            didCopyInfo = false
        }
    }
}

private struct AboutView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: DTSpace.md) {
            Image("DropThingsLogoTransparent")
                .resizable()
                .scaledToFit()
                .frame(width: 72, height: 72)
                .accessibilityHidden(true)
            Text("DropThings")
                .font(DTTypography.windowTitle)
            Text("Native macOS utility hub")
                .font(DTTypography.body)
                .foregroundStyle(DTColor.textSecondary)
            Text("Small focused tools, clear permissions, and a compact control center.")
                .font(DTTypography.caption)
                .foregroundStyle(DTColor.textSecondary)
            Spacer()
        }
        .padding(DTSpace.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
