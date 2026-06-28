import AppKit
import SwiftUI
import Combine
import ServiceManagement
import UniformTypeIdentifiers
import DropThingsCore
import DropThingsDesignSystem
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
    let settingsWindow: SettingsWindowController
    let onboardingWindow: OnboardingWindowController
    let launchAtLogin = LaunchAtLoginController()
    let updates: AppUpdateService
    let importer = SettingsImporter(suiteName: "app.dropthings")
    var bundleInfo: BundleInfo { BundleInfo.current() }

    /// Forwards change notifications from child observables so SwiftUI views
    /// observing `AppServices` re-render when `registry` or `permissions`
    /// mutate.
    private var cancellables: Set<AnyCancellable> = []

    private init() {
        self.settings = .userDefaults(suiteName: "app.dropthings")
        self.permissions = PermissionCenter()
        self.diagnostics = DiagnosticsStore()
        self.registry = ModuleRegistry(settings: settings, permissions: permissions)
        self.updates = AppUpdateService(
            settings: settings,
            client: GitHubReleasesUpdateClient(owner: "LucasSabena", repository: "dropthings"),
            currentVersion: { BundleInfo.current().shortVersion }
        )
        self.settingsWindow = SettingsWindowController(
            initialSize: NSSize(width: DTSize.settingsMinWidth, height: DTSize.settingsMinHeight)
        )
        self.onboardingWindow = OnboardingWindowController()

        registry.register(FileShelfModule(settings: settings))
        registry.register(ScrollControlModule(settings: settings, permissions: permissions))
        registry.register(MenuBarCleanerModule(settings: settings, permissions: permissions))
        registry.register(KeepAwakeModule(settings: settings))
        registry.register(ColorPickerModule(settings: settings, permissions: permissions))

        settingsWindow.setContent(
            SettingsRootView().environmentObject(self)
        )
        configureOnboarding()
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
        launchAtLogin.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        updates.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
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
        if let lastCheckedAt = updates.lastCheckedAt {
            lines.append("Last update check: \(lastCheckedAt)")
        } else {
            lines.append("Last update check: never")
        }
        lines.append("Permissions:")
        for permission in SystemPermission.allCases {
            lines.append("  - \(permission.displayName): \(permissions.state(for: permission))")
        }
        return lines.joined(separator: "\n")
    }

    private func configureOnboarding() {
        onboardingWindow.setContent(
            OnboardingView(
                onEnableFileShelf: { [weak self] in
                    guard let self else { return }
                    self.registry.setEnabled(true, for: .fileShelf)
                    self.settingsWindow.show()
                },
                onSkip: { [weak self] in
                    self?.onboardingWindow.dismiss()
                }
            )
        )
    }

    /// Show the welcome window on first launch. Idempotent after the user
    /// dismisses it.
    func presentOnboardingIfNeeded() {
        guard !OnboardingWindowController.hasCompleted else { return }
        onboardingWindow.show()
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
        permissions.refresh()
        // Each module reads its own settings via SettingsStore so a fresh
        // load is enough; the user can re-enable modules from the registry.
        diagnostics.record(level: .notice, category: "settings", message: "Settings imported from plist")
    }

    func repairAccessibilityTrust() {
        do {
            try runTCCResetAccessibility()
            diagnostics.record(level: .notice, category: "permissions", message: "Accessibility TCC entry reset")
        } catch {
            diagnostics.record(level: .warning, category: "permissions", message: "Accessibility reset failed: \(error.localizedDescription)")
        }
        permissions.refresh()
        _ = permissions.requestPermission(.accessibility)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            guard let self else { return }
            self.permissions.refresh()
            Task {
                await self.registry.refreshPermissionsAndRetry()
            }
        }
    }

    private func runTCCResetAccessibility() throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tccutil")
        process.arguments = ["reset", "Accessibility", bundleInfo.bundleIdentifier]
        let stderr = Pipe()
        process.standardError = stderr
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let data = stderr.fileHandleForReading.readDataToEndOfFile()
            let message = String(data: data, encoding: .utf8) ?? "exit \(process.terminationStatus)"
            throw NSError(
                domain: "DropThingsTCCReset",
                code: Int(process.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: message]
            )
        }
    }

    func openUpdate(_ release: AppUpdateRelease) {
        NSWorkspace.shared.open(release.downloadURL ?? release.releaseURL)
    }
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
        if let shelf = services.registry.modules[.fileShelf] as? FileShelfModule {
            Button("Show File Shelf") {
                shelf.showPanel()
            }
            .keyboardShortcut("s", modifiers: [.command, .option])

            Divider()
        }

        Button("Open Settings…") {
            services.settingsWindow.show()
        }
        .keyboardShortcut(",")

        if let release = services.updates.state.availableRelease {
            Button("Download DropThings \(release.version)…") {
                services.openUpdate(release)
            }
        } else {
            Button(services.updates.state.isChecking ? "Checking for Updates…" : "Check for Updates…") {
                services.updates.checkNow()
                services.settingsWindow.show()
            }
            .disabled(services.updates.state.isChecking)
        }

        Divider()

        Button("Export Settings…") {
            services.exportSettings()
        }
        Button("Import Settings…") {
            services.importSettings()
        }

        Divider()

        Button("Quit DropThings") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
