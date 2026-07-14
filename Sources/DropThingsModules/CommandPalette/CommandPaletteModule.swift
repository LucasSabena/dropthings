import AppKit
import Combine
import SwiftUI
import DropThingsCore
import DropThingsDesignSystem
import DropThingsPlatform

@MainActor
public final class CommandPaletteModule: DropThingsModule {
    public let id = ModuleID.commandPalette
    public let name = "Command Palette"
    public let summary = "Search apps, DropThings actions, local files, calculations, and the web."
    public let requiredPermissions: [SystemPermission] = []

    @Published public private(set) var state: ModuleState = .off
    @Published public private(set) var settings: CommandPaletteSettings

    public let coordinator: PaletteQueryCoordinator

    private let settingsStore: SettingsStore
    private let applicationCatalog: any ApplicationCataloging
    private let hotkeyFactory: @MainActor (GlobalHotkey.Definition, @escaping @MainActor () -> Void) -> any CommandPaletteHotkeyRegistration
    private var hotkey: (any CommandPaletteHotkeyRegistration)?
    private var applicationMonitors: [DirectoryMonitor] = []
    private var applicationRefreshTask: Task<Void, Never>?
    private var hotkeyFailureReason: String?
    private var providerFailureReason: String?
    private lazy var panel = CommandPalettePanelController(coordinator: coordinator)
    private var cancellables: Set<AnyCancellable> = []
    private let logger = ModuleLogger(subsystem: "app.dropthings", category: "command-palette")

    public init(
        settings: SettingsStore,
        permissions: PermissionCenter,
        commandSource: @escaping @MainActor () -> [CommandDescriptor]
    ) {
        self.settingsStore = settings
        let loaded = settings.loadCommandPaletteSettings()
        self.settings = loaded
        let catalog = ApplicationCatalog()
        self.applicationCatalog = catalog
        self.hotkeyFactory = { GlobalHotkey(definition: $0, onFire: $1) }
        self.coordinator = PaletteQueryCoordinator(
            settings: loaded,
            commandSource: commandSource,
            applicationCatalog: catalog,
            spotlight: SpotlightFileSearch(),
            workspace: PaletteWorkspace(),
            history: PaletteHistoryStore(settings: settings)
        )
        self.coordinator.settingsDidChange = { [weak self] in self?.applySettings($0) }
        observeCoordinatorHealth()
    }

    public init(
        settings: SettingsStore,
        permissions: PermissionCenter,
        commandSource: @escaping @MainActor () -> [CommandDescriptor],
        applicationCatalog: any ApplicationCataloging,
        spotlight: any SpotlightFileSearching,
        workspace: PaletteWorkspace,
        hotkeyFactory: @escaping @MainActor (GlobalHotkey.Definition, @escaping @MainActor () -> Void) -> any CommandPaletteHotkeyRegistration = { GlobalHotkey(definition: $0, onFire: $1) }
    ) {
        let loaded = settings.loadCommandPaletteSettings()
        let history = PaletteHistoryStore(settings: settings)
        self.settingsStore = settings
        self.settings = loaded
        self.applicationCatalog = applicationCatalog
        self.hotkeyFactory = hotkeyFactory
        self.coordinator = PaletteQueryCoordinator(
            settings: loaded,
            commandSource: commandSource,
            applicationCatalog: applicationCatalog,
            spotlight: spotlight,
            workspace: workspace,
            history: history
        )
        self.coordinator.settingsDidChange = { [weak self] in self?.applySettings($0) }
        observeCoordinatorHealth()
    }

    public func start() async throws {
        coordinator.start()
        startApplicationMonitors()
        registerHotkey()
        if case .degraded = state {} else { state = .running }
        logger.info("Command Palette started")
    }

    public func stop() async {
        unregisterHotkey()
        stopApplicationMonitors()
        coordinator.stop()
        panel.hide()
        hotkeyFailureReason = nil
        providerFailureReason = nil
        state = .off
        logger.info("Command Palette stopped")
    }

    public var primaryAction: ModulePrimaryAction? {
        ModulePrimaryAction(title: "Open Command Palette", iconName: iconName) { [weak self] in
            Task { @MainActor [weak self] in self?.show() }
        }
    }

    public func show() {
        coordinator.prepareForPresentation()
        panel.show()
    }

    public func hide() { panel.hide() }

    public func toggle() {
        panel.isVisible ? hide() : show()
    }

    public func setHotkeyEnabled(_ enabled: Bool) {
        var updated = settings
        updated.hotkeyEnabled = enabled
        applySettings(updated)
    }

    public func setHotkey(_ definition: GlobalHotkey.Definition?) {
        var updated = settings
        updated.hotkey = definition
        applySettings(updated)
    }

    public func setProvider(_ provider: PaletteProviderID, enabled: Bool) {
        var updated = settings
        switch provider {
        case .applications: updated.applicationsEnabled = enabled
        case .commands: updated.commandsEnabled = enabled
        case .calculator: updated.calculatorEnabled = enabled
        case .files: updated.filesEnabled = enabled
        case .web: updated.webSearchEnabled = enabled
        }
        applySettings(updated)
    }

    public func setFileContentSearchEnabled(_ enabled: Bool) {
        var updated = settings
        updated.fileContentSearchEnabled = enabled
        applySettings(updated)
    }

    public func setIncludeHiddenFiles(_ enabled: Bool) {
        var updated = settings
        updated.includeHiddenFiles = enabled
        applySettings(updated)
    }

    public func setExcludedPaths(_ paths: [String]) {
        var updated = settings
        updated.excludedPaths = paths
        applySettings(updated)
    }

    public func setApplicationLocations(_ paths: [String]) {
        var updated = settings
        updated.applicationLocations = paths
        applySettings(updated, refreshCatalog: true)
    }

    public func setApplicationExcludedPaths(_ paths: [String]) {
        var updated = settings
        updated.applicationExcludedPaths = paths
        applySettings(updated, refreshCatalog: true)
    }

    public func setApplicationVisibility(_ visibility: ApplicationVisibilityMode) {
        var updated = settings
        updated.applicationVisibility = visibility
        applySettings(updated)
    }

    public func setApplicationVisible(_ id: String, visible: Bool) {
        var updated = settings
        if visible { updated.selectedApplicationIDs.append(id) }
        else { updated.selectedApplicationIDs.removeAll { $0 == id } }
        applySettings(updated)
    }

    public func setApplicationPinned(_ id: String, pinned: Bool) {
        var updated = settings
        if pinned { updated.pinnedApplicationIDs.append(id) }
        else { updated.pinnedApplicationIDs.removeAll { $0 == id } }
        applySettings(updated)
    }

    public func setWebSearchEnabled(_ enabled: Bool) {
        var updated = settings
        updated.webSearchEnabled = enabled
        applySettings(updated)
    }

    public func setWebSearchEngine(_ engine: WebSearchEngine) {
        var updated = settings
        updated.webSearchEngine = engine
        applySettings(updated)
    }

    public func setWebBrowserBundleIdentifier(_ identifier: String?) {
        var updated = settings
        updated.webBrowserBundleIdentifier = identifier
        applySettings(updated)
    }

    public func setMaximumResultsPerProvider(_ value: Int) {
        var updated = settings
        updated.maximumResultsPerProvider = value
        applySettings(updated)
    }

    public func clearHistory() { coordinator.clearHistory() }

    public func refreshCommands() { coordinator.refreshCommands() }

    public func restoreDefaults() {
        applySettings(CommandPaletteSettings(), refreshCatalog: true)
    }

    public func makeSettingsView() -> AnyView {
        AnyView(CommandPaletteSettingsView(module: self))
    }

    private func applySettings(_ newValue: CommandPaletteSettings, refreshCatalog: Bool = false) {
        let sanitized = newValue.sanitized()
        let hotkeyChanged = sanitized.hotkeyEnabled != settings.hotkeyEnabled || sanitized.hotkey != settings.hotkey
        let applicationLocationsChanged = sanitized.applicationLocations != settings.applicationLocations
        settings = sanitized
        settingsStore.saveCommandPaletteSettings(sanitized)
        coordinator.updateSettings(sanitized, refreshCatalog: refreshCatalog)
        if applicationLocationsChanged, state.isStarted { startApplicationMonitors() }
        if hotkeyChanged, state.isStarted {
            unregisterHotkey()
            registerHotkey()
        }
    }

    private func registerHotkey() {
        guard hotkey == nil else { return }
        guard settings.hotkeyEnabled, let definition = settings.hotkey else {
            hotkeyFailureReason = nil
            refreshHealthState()
            return
        }
        let hotkey = hotkeyFactory(definition) { [weak self] in self?.toggle() }
        do {
            try hotkey.register()
            self.hotkey = hotkey
            hotkeyFailureReason = nil
            refreshHealthState()
        } catch {
            let reason = "\(definition.displayString) is unavailable. Choose another shortcut in settings."
            hotkeyFailureReason = reason
            state = .degraded(reason: reason)
            logger.warning("Hotkey registration failed: \(error)")
        }
    }

    private func unregisterHotkey() {
        hotkey?.unregister()
        hotkey = nil
    }

    private func observeCoordinatorHealth() {
        coordinator.$diagnostics
            .dropFirst()
            .sink { [weak self] diagnostics in
                guard let self, state.isStarted else { return }
                providerFailureReason = diagnostics.values
                    .sorted(by: { $0.provider.rawValue < $1.provider.rawValue })
                    .first
                    .map { "\($0.provider.displayName): \($0.message)" }
                refreshHealthState()
            }
            .store(in: &cancellables)
    }

    private func startApplicationMonitors() {
        stopApplicationMonitors()
        let configured = settings.applicationLocations.map { URL(fileURLWithPath: $0, isDirectory: true) }
        let uniqueLocations = Dictionary(
            grouping: ApplicationCatalog.defaultLocations + configured,
            by: { $0.standardizedFileURL.path }
        ).compactMap(\.value.first)
        applicationMonitors = uniqueLocations.map { location in
            DirectoryMonitor(url: location) { [weak self] in self?.scheduleApplicationCatalogRefresh() }
        }
        applicationMonitors.forEach { $0.start() }
    }

    private func stopApplicationMonitors() {
        applicationRefreshTask?.cancel()
        applicationRefreshTask = nil
        applicationMonitors.forEach { $0.stop() }
        applicationMonitors = []
    }

    private func scheduleApplicationCatalogRefresh() {
        applicationRefreshTask?.cancel()
        applicationRefreshTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            self?.coordinator.refreshApplicationCatalog()
        }
    }

    private func refreshHealthState() {
        guard state.isStarted else { return }
        if let reason = hotkeyFailureReason ?? providerFailureReason {
            state = .degraded(reason: reason)
        } else {
            state = .running
        }
    }
}

@MainActor
public protocol CommandPaletteHotkeyRegistration: AnyObject {
    func register() throws
    func unregister()
}

extension GlobalHotkey: CommandPaletteHotkeyRegistration {}
