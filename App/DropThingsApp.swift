import AppKit
import SwiftUI
import Combine
import ServiceManagement
import UniformTypeIdentifiers
import Sparkle
import DropThingsCore
import DropThingsDesignSystem
import DropThingsPlatform
import DropThingsModules

/// Owns the long-lived services and exposes them to the UI. Lives in the App
/// target because it composes modules from every other target. Shared as a
/// static so `AppDelegate` and the SwiftUI scene talk to the same instance.
@MainActor
final class AppServices: ObservableObject {
    static let shared = AppServices()

    let settings: SettingsStore
    let permissions: PermissionCenter
    let diagnostics: DiagnosticsStore
    let registry: ModuleRegistry
    let moduleMenuBarPreferences: ModuleMenuBarPreferences
    let captureArchive: CaptureArchive
    let transientSurfaces: TransientSurfaceCoordinator
    let settingsWindow: SettingsWindowController
    let launchAtLogin = LaunchAtLoginController()
    let updates: SparkleUpdaterController
    let importer = SettingsImporter(suiteName: "app.dropthings")
    /// Single shared pasteboard observer for Clipboard History and Smart
    /// Clipboard so they never run two pollers and never echo each other's
    /// writes back as new changes.
    let pasteboardHub: PasteboardHub
    /// Core-owned registry for cross-module file actions. Smart Clipboard
    /// consumes actions published by other modules through this instead of
    /// importing them.
    let fileActionRegistry: FileActionRegistry
    private var moduleMenuBarController: ModuleMenuBarController?
    var bundleInfo: BundleInfo { BundleInfo.current() }

    /// Forwards change notifications from child observables so SwiftUI views
    /// observing `AppServices` re-render when `registry` or `permissions`
    /// mutate.
    private var cancellables: Set<AnyCancellable> = []
    private var recordedModuleStates: [ModuleID: ModuleState] = [:]
    private static let didPresentControlCenterKey = SettingsKey("app.control-center.presented")

    private init() {
        self.settings = .userDefaults(suiteName: "app.dropthings")
        self.permissions = PermissionCenter(settings: settings)
        self.diagnostics = DiagnosticsStore()
        self.registry = ModuleRegistry(settings: settings, permissions: permissions)
        self.moduleMenuBarPreferences = ModuleMenuBarPreferences(settings: settings)
        self.captureArchive = CaptureArchive()
        self.transientSurfaces = TransientSurfaceCoordinator()
        self.updates = SparkleUpdaterController()
        self.settingsWindow = SettingsWindowController(
            initialSize: NSSize(width: DTSize.settingsMinWidth, height: DTSize.settingsMinHeight)
        )
        self.pasteboardHub = PasteboardHub(backend: ClipboardMonitor())
        self.fileActionRegistry = FileActionRegistry()

        // The product intentionally ships only the modules that have a
        // reliable end-to-end interaction. Keeping this composition explicit
        // prevents half-finished modules from leaking back into the UI.
        registry.register(FileShelfModule(
            settings: settings,
            captureArchive: captureArchive,
            transientSurfaces: transientSurfaces
        ))
        registry.register(ScrollControlModule(settings: settings, permissions: permissions))
        registry.register(KeepAwakeModule(settings: settings))
        registry.register(ColorPickerModule(settings: settings, permissions: permissions))
        registry.register(ClipboardHistoryModule(
            settings: settings,
            permissions: permissions,
            hub: pasteboardHub,
            transientSurfaces: transientSurfaces
        ))
        registry.register(SmartClipboardModule(
            settings: settings,
            permissions: permissions,
            hub: pasteboardHub,
            fileActionRegistry: fileActionRegistry,
            transientSurfaces: transientSurfaces
        ))
        registry.register(MarkdownViewerModule(settings: settings, permissions: permissions))
        registry.register(ScreenshotStudioModule(settings: settings, permissions: permissions, captureArchive: captureArchive))
        registry.register(AudioControlModule(settings: settings))
        registry.register(LocalTranscriptionModule(settings: settings))
        registry.register(NetworkPriorityModule())
        registry.register(KeyboardLockModule(permissions: permissions))
        registry.register(MediaConverterModule(settings: settings, fileActionRegistry: fileActionRegistry))
        let commandPalette = CommandPaletteModule(
            settings: settings,
            permissions: permissions,
            commandSource: { [weak registry] in
                guard let registry else { return [] }
                return registry.modules.values
                    .filter { $0.id != .commandPalette && registry.isEnabled($0.id) }
                    .flatMap(\.commands)
            },
            transientSurfaces: transientSurfaces
        )
        registry.register(commandPalette)
        enableCommandPaletteByDefaultIfNeeded()
        registry.pruneUnregisteredEnablement()
        moduleMenuBarPreferences.prune(registeredModuleIDs: Set(registry.modules.keys))
        recordedModuleStates = registry.states

        settingsWindow.setContent(
            SettingsRootView().environmentObject(self)
        )
        importer.onImport = { [weak self] in
            self?.reloadAfterImport()
        }

        registry.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        permissions.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        diagnostics.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        registry.$states
            .dropFirst()
            .sink { [weak self, weak commandPalette] states in
                self?.recordModuleStateChanges(states)
                commandPalette?.refreshCommands()
            }
            .store(in: &cancellables)
        launchAtLogin.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        updates.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        moduleMenuBarPreferences.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        moduleMenuBarController = ModuleMenuBarController(
            registry: registry,
            preferences: moduleMenuBarPreferences,
            openSettings: { [weak self] moduleID in self?.showSettings(moduleID: moduleID) }
        )
    }

    /// Plain-text dump of the bundle path and current permission states.
    /// Used by the Diagnostics "Copy info" action so a user can paste it
    /// into a bug report.
    func diagnosticSnapshot() -> String {
        var lines: [String] = []
        let bundleInfo = BundleInfo.current()
        lines.append("Bundle ID: \(bundleInfo.bundleIdentifier)")
        lines.append("Bundle path: \(bundleInfo.bundlePath)")
        lines.append("Version: \(bundleInfo.shortVersion) (\(bundleInfo.buildNumber))")
        lines.append("AX trusted: \(bundleInfo.axIsProcessTrusted ? "yes" : "no")")
        lines.append("Launch at login: \(launchAtLogin.statusLabel)")
        lines.append("Automatic update checks: \(updates.automaticChecksEnabled ? "on" : "off")")
        lines.append("Permissions:")
        for permission in SystemPermission.allCases {
            lines.append("  - \(permission.displayName): \(permissions.state(for: permission))")
        }
        return lines.joined(separator: "\n")
    }

    /// The first-run experience is the actual control center, not a marketing
    /// window. Permissions remain untouched until the user enables the one
    /// module that needs them.
    func presentControlCenterOnFirstLaunch() {
        guard !settings.bool(Self.didPresentControlCenterKey, default: false) else { return }
        settings.setBool(true, Self.didPresentControlCenterKey)
        settingsWindow.show()
    }

    func exportSettings() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.propertyList]
        panel.nameFieldStringValue = "DropThings-Settings.plist"
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try importer.export(to: url)
        } catch {
            NSAlert(error: error).runModal()
        }
    }

    func importSettings() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.propertyList]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try importer.import(from: url)
        } catch {
            NSAlert(error: error).runModal()
        }
    }

    private func reloadAfterImport() {
        diagnostics.recordAndLog(
            level: .notice,
            category: "settings",
            message: "Settings imported; relaunching to apply every module atomically"
        )
        relaunch()
    }

    private func recordModuleStateChanges(_ states: [ModuleID: ModuleState]) {
        for (id, state) in states where recordedModuleStates[id] != state {
            let moduleName = registry.modules[id]?.name ?? id.rawValue
            let level: LogLevel
            switch state {
            case .degraded, .needsPermission, .unavailable: level = .warning
            case .failed: level = .error
            case .running: level = .notice
            case .off, .starting: level = .info
            }
            diagnostics.record(
                level: level,
                category: id.rawValue,
                message: "\(moduleName): \(state.diagnosticDescription)"
            )
        }
        recordedModuleStates = states
    }

    private func relaunch() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-n", Bundle.main.bundleURL.path]
        do {
            try process.run()
            NSApp.terminate(nil)
        } catch {
            diagnostics.recordAndLog(
                level: .error,
                category: "settings",
                message: "Could not relaunch after import: \(error.localizedDescription)"
            )
            NSAlert(error: error).runModal()
        }
    }

    func showAboutWindow() {
        settingsWindow.show()
    }

#if DEBUG
    func showCommandPaletteForVisualTesting(runQuerySequence: Bool = false) async {
        await registry.start(id: .commandPalette)
        guard let module = registry.modules[.commandPalette] as? CommandPaletteModule else { return }
        module.show()
        guard runQuerySequence else { return }
        try? await Task.sleep(for: .milliseconds(250))
        var prefix = ""
        for character in "safari browser search" {
            prefix.append(character)
            module.coordinator.query = prefix
            try? await Task.sleep(for: .milliseconds(20))
        }
        module.coordinator.query = "2+3*4"
        try? await Task.sleep(for: .milliseconds(200))
        module.coordinator.query = "README"
    }

    func showScreenshotEditorForVisualTesting() {
        guard let module = registry.modules[.screenshotStudio] as? ScreenshotStudioModule else { return }
        module.openEditorForVisualTesting()
    }

    func showNetworkPriorityForVisualTesting() {
        guard let module = registry.modules[.networkPriority] as? NetworkPriorityModule else { return }
        module.prepareVisualTestingState()
        showSettings(moduleID: .networkPriority)
    }
#endif

    /// Existing installs predate Command Palette, so absence of its explicit
    /// key means "new module" rather than "user disabled it". Persist the
    /// default once; subsequent off values are always respected.
    private func enableCommandPaletteByDefaultIfNeeded() {
        var enabled: [String: Bool] = [:]
        if let data = settings.data(ModuleRegistry.enabledKey),
           let decoded = try? JSONDecoder().decode([String: Bool].self, from: data) {
            enabled = decoded
        }
        guard enabled[ModuleID.commandPalette.rawValue] == nil else { return }
        enabled[ModuleID.commandPalette.rawValue] = true
        guard let data = try? JSONEncoder().encode(enabled) else { return }
        settings.setData(data, ModuleRegistry.enabledKey)
    }

    func showSettings(moduleID: ModuleID? = nil) {
        if let moduleID {
            // Publish the selection through @AppStorage keys so the split view
            // navigates to the module detail pane.
            UserDefaults.standard.set(SidebarItem.module(moduleID).storageKey,
                                      forKey: "ui.settings.sidebarSection")
            UserDefaults.standard.set(moduleID.rawValue,
                                      forKey: "ui.settings.sidebarModuleID")
        }
        settingsWindow.show()
    }

#if DEBUG
    func showMenuBarItemForVisualTesting(moduleID: ModuleID) {
        (registry.modules[moduleID] as? AudioControlModule)?.prepareEmptyVisualTestingState()
        moduleMenuBarController?.showForVisualTesting(moduleID: moduleID)
    }
#endif
}

@MainActor
final class LaunchAtLoginController: ObservableObject {
    @Published private(set) var status: SMAppService.Status = SMAppService.mainApp.status
    @Published private(set) var lastError: String?

    var isEnabled: Bool {
        status == .enabled
    }

    var needsApproval: Bool {
        status == .requiresApproval
    }

    var statusLabel: String {
        switch status {
        case .enabled: return "enabled"
        case .notRegistered: return "off"
        case .requiresApproval: return "needs approval"
        case .notFound: return "not found"
        @unknown default: return "unknown"
        }
    }

    func refresh() {
        status = SMAppService.mainApp.status
    }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
        refresh()
    }

    func openLoginItemsSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension") else { return }
        NSWorkspace.shared.open(url)
    }
}

@main
struct DropThingsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var services = AppServices.shared

    var body: some Scene {
        MenuBarExtra {
            menuContent
        } label: {
            Image("DropThingsMenuBarIcon")
        }
        .menuBarExtraStyle(.menu)
    }

    @ViewBuilder
    private var menuContent: some View {
        activeModulesSection

        Divider()

        Button("Open Settings…") {
            services.showSettings()
        }
        .keyboardShortcut(",")

        Button("Check for Updates…") {
            services.updates.checkNow()
            services.showSettings()
        }
        .disabled(services.updates.state == .checking)

        Divider()

        Button("Quit DropThings") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }

    /// One-tap shortcuts for every active module that exposes a primary action.
    /// Modules without an action are omitted; the user can still reach them
    /// through Settings.
    @ViewBuilder
    private var activeModulesSection: some View {
        let activeModules = services.registry.modules
            .filter { services.registry.states[$0.key]?.isActive == true }
            .sorted { $0.key.rawValue < $1.key.rawValue }

        if activeModules.isEmpty {
            Text("No active modules")
                .font(DTTypography.caption)
                .foregroundStyle(DTColor.textSecondary)
                .disabled(true)
        } else {
            ForEach(activeModules, id: \.key) { entry in
                moduleMenuItem(module: entry.value)
            }
        }
    }

    @ViewBuilder
    private func moduleMenuItem(module: any DropThingsModule) -> some View {
        if module.menuBarPresentation?.togglesModuleLifecycle == true {
            Button {
                services.registry.setEnabled(!services.registry.isEnabled(module.id), for: module.id)
            } label: {
                Label(services.registry.isEnabled(module.id) ? "Disable \(module.name)" : "Enable \(module.name)", systemImage: module.menuBarIconName)
            }
        } else if let action = module.primaryAction {
            Button {
                action.action()
            } label: {
                Label(action.title, systemImage: action.iconName)
            }
        } else {
            Button {
                services.showSettings(moduleID: module.id)
            } label: {
                Label(module.name, systemImage: module.iconName)
            }
        }
    }
}
