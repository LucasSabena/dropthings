import AppKit
import SwiftUI
import DropThingsCore
import DropThingsDesignSystem
import DropThingsPlatform
import os

/// Hidden-Bar-style overflow for menu bar items. DropThings owns a divider
/// and a toggle item; the user Command-drags icons to the left of the divider
/// once, then Collapse expands the divider so that zone moves off-screen.
public final class MenuBarCleanerModule: DropThingsModule {
    public let id = ModuleID.menuBarCleaner
    public let name = "Menu Bar Cleaner"
    public let summary = "Collapse low-priority menu bar icons behind one control."
    public let requiredPermissions: [SystemPermission] = []

    @Published public private(set) var state: ModuleState = .off
    @Published public private(set) var settings: MenuBarCleanerSettings
    @Published public private(set) var isCollapsed: Bool = false
    @Published public private(set) var statusMessage: String?

    /// One-tap entry point from the menu bar. In drawer mode this opens the
    /// overflow drawer; otherwise it toggles collapse directly.
    public var primaryAction: ModulePrimaryAction? {
        ModulePrimaryAction(
            title: settings.drawerMode ? "Open Menu Bar Cleaner" : (isCollapsed ? "Reveal icons" : "Collapse icons"),
            iconName: iconName,
            action: { [weak self] in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if self.settings.drawerMode {
                        self.showOverflowPanel()
                    } else {
                        self.toggleCollapsed()
                    }
                }
            }
        )
    }

    public var commands: [CommandDescriptor] {
        [
            CommandDescriptor(
                id: "menu-bar-cleaner.toggle",
                title: isCollapsed ? "Reveal Menu Bar Icons" : "Collapse Menu Bar Icons",
                subtitle: name,
                iconName: isCollapsed ? "eye" : "eye.slash",
                action: { [weak self] in
                    Task { @MainActor [weak self] in self?.toggleCollapsed() }
                }
            )
        ]
    }

    private let settingsStore: SettingsStore
    private let logger = ModuleLogger(subsystem: "app.dropthings", category: "menu-bar-cleaner")

    /// The chevron that opens the drawer or toggles collapse.
    private var toggleItem: DropThingsStatusItem?
    /// All divider status items, keyed by divider id. The main divider is
    /// always present; extra dividers are visual group separators.
    private var dividerItems: [UUID: DropThingsStatusItem] = [:]
    private var hoverView: HoverTrackingView?
    private var screenObserver: NSObjectProtocol?
    private var hoverTimer: Timer?
    private var hoverExitMonitor: Timer?
    private var wasHoverRevealed: Bool = false
    private var overflowPanel: MenuBarCleanerOverflowPanelController?
    private var startupTask: Task<Void, Never>?
    private var layoutFailureReason: String?

    public init(settings: SettingsStore, permissions: PermissionCenter) {
        self.settingsStore = settings
        self.settings = settings.loadMenuBarCleanerSettings()
    }

    public func start() async throws {
        installStatusItems()
        subscribeToScreenChanges()
        state = .running
        scheduleInitialState()
        logger.info("Menu Bar Cleaner started")
    }

    public func stop() async {
        revealForShutdown()
        uninstallStatusItems()
        unsubscribeFromScreenChanges()
        hoverTimer?.invalidate()
        hoverTimer = nil
        hoverExitMonitor?.invalidate()
        hoverExitMonitor = nil
        startupTask?.cancel()
        startupTask = nil
        state = .off
        logger.info("Menu Bar Cleaner stopped")
    }

    // MARK: - Actions

    public func toggleCollapsed() {
        guard state.isStarted else { return }
        isCollapsed ? reveal() : collapse()
    }

    public func collapse() {
        guard state.isStarted else { return }
        guard !isCollapsed else { return }
        guard validateControlOrder() else { return }
        setCollapsed(true, persist: true)
        logger.info("Menu bar overflow collapsed")
    }

    public func reveal() {
        guard isCollapsed else { return }
        setCollapsed(false, persist: true)
        logger.info("Menu bar overflow revealed")
    }

    private func revealForShutdown() {
        guard isCollapsed else { return }
        setCollapsed(false, persist: false)
    }

    public func setCollapseOnLaunch(_ enabled: Bool) {
        var new = settings
        new.collapseOnLaunch = enabled
        saveSettings(new)
    }

    public var collapseOnLaunch: Bool {
        settings.collapseOnLaunch
    }

    public func setHoverRevealDelay(_ delay: TimeInterval) {
        var new = settings
        new.hoverRevealDelay = delay
        saveSettings(new)
        if settings.hoverRevealDelay == 0 {
            hoverTimer?.invalidate()
            hoverTimer = nil
            hoverExitMonitor?.invalidate()
            hoverExitMonitor = nil
        }
        installHoverTracking()
    }

    public var hoverRevealDelay: TimeInterval {
        settings.hoverRevealDelay
    }

    public func setDrawerMode(_ enabled: Bool) {
        var new = settings
        new.drawerMode = enabled
        saveSettings(new)
        installClickHandler()
    }

    public func setActiveProfile(_ profileID: UUID?) {
        var new = settings
        new.activeProfileID = profileID
        saveSettings(new)
        if state.isStarted, let profile = new.activeProfile {
            if profile.collapsed {
                collapse()
            } else {
                reveal()
            }
        }
    }

    public func updateProfile(_ profile: MenuBarCleanerProfile) {
        var new = settings
        if let index = new.profiles.firstIndex(where: { $0.id == profile.id }) {
            new.profiles[index] = profile
            saveSettings(new)
        }
    }

    public func addProfile(name: String, collapsed: Bool) {
        var new = settings
        let profile = MenuBarCleanerProfile(id: UUID(), name: name, collapsed: collapsed)
        new.profiles.append(profile)
        saveSettings(new)
    }

    public func removeProfile(_ profileID: UUID) {
        var new = settings
        new.profiles.removeAll { $0.id == profileID }
        if new.activeProfileID == profileID {
            new.activeProfileID = nil
        }
        saveSettings(new)
    }

    // MARK: - Dividers

    public func addDivider(name: String, symbolName: String = "line.vertical") {
        var new = settings
        let divider = MenuBarCleanerDivider(name: name, symbolName: symbolName, isOverflow: false)
        new.dividers.append(divider)
        saveSettings(new)
        if toggleItem != nil {
            installDividerStatusItem(divider)
        }
    }

    public func removeDivider(_ dividerID: UUID) {
        guard dividerID != MenuBarCleanerDivider.mainID else { return }
        var new = settings
        new.dividers.removeAll { $0.id == dividerID }
        saveSettings(new)
        dividerItems[dividerID] = nil
    }

    public func updateDivider(_ divider: MenuBarCleanerDivider) {
        var new = settings
        guard let index = new.dividers.firstIndex(where: { $0.id == divider.id }) else { return }
        new.dividers[index] = divider
        saveSettings(new)
        applyMenuBarState()
    }

    public func safeReset() {
        let wasStarted = state.isStarted
        setCollapsed(false, persist: false)
        layoutFailureReason = nil
        var new = settings
        new.activeProfileID = nil
        new.dividers = [.defaultMain]
        new.drawerMode = false
        saveSettings(new)
        uninstallStatusItems()
        if wasStarted {
            installStatusItems()
            state = .running
        } else {
            state = .off
        }
        statusMessage = "Reset complete. Command-drag low-priority icons to the left of the divider."
        logger.notice("Menu Bar Cleaner reset: all icons visible, no active profile, dividers reset")
    }

    // MARK: - SwiftUI surface

    public func makeSettingsView() -> AnyView {
        AnyView(MenuBarCleanerSettingsView(module: self))
    }

    // MARK: - Settings persistence

    private func saveSettings(_ new: MenuBarCleanerSettings) {
        let sanitized = new.sanitized()
        settings = sanitized
        settingsStore.saveMenuBarCleanerSettings(sanitized)
    }

    private func persistCollapsedToActiveProfile() {
        guard let activeID = settings.activeProfileID,
              let index = settings.profiles.firstIndex(where: { $0.id == activeID }) else { return }
        var new = settings
        new.profiles[index].collapsed = isCollapsed
        saveSettings(new)
    }

    private func applyProfileOnLaunch() {
        let shouldCollapse = settings.activeProfile?.collapsed ?? settings.collapseOnLaunch
        if shouldCollapse {
            collapseWithoutPersisting()
        } else {
            setCollapsed(false, persist: false)
        }
    }

    private func scheduleInitialState() {
        startupTask?.cancel()
        startupTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled, let self, self.state.isStarted else { return }
            self.applyProfileOnLaunch()
        }
    }

    private func collapseWithoutPersisting() {
        guard !isCollapsed, validateControlOrder() else { return }
        setCollapsed(true, persist: false)
    }

    private func setCollapsed(_ collapsed: Bool, persist: Bool) {
        isCollapsed = collapsed
        if persist {
            persistCollapsedToActiveProfile()
        }
        applyMenuBarState()
    }

    // MARK: - Status items

    private func installStatusItems() {
        guard toggleItem == nil else { return }

        let toggle = DropThingsStatusItem()
        toggle.setAutosaveName("dropthings-menu-bar-cleaner-toggle")
        toggle.show()
        toggleItem = toggle

        for divider in settings.dividers {
            installDividerStatusItem(divider)
        }

        installHoverTracking()
        installClickHandler()
        applyMenuBarState()
    }

    private func installDividerStatusItem(_ divider: MenuBarCleanerDivider) {
        let item = DropThingsStatusItem(length: divider.expandedLength)
        item.setAutosaveName("dropthings-menu-bar-cleaner-divider-\(divider.id.uuidString)")
        item.setSymbol(divider.symbolName, accessibilityDescription: "DropThings menu bar divider: \(divider.name)")
        item.show()
        dividerItems[divider.id] = item
    }

    private func installClickHandler() {
        guard let toggleItem else { return }
        toggleItem.setOnClick { [weak self] in
            guard let self else { return }
            if self.settings.drawerMode {
                self.showOverflowPanel()
            } else {
                self.toggleCollapsed()
            }
        }
    }

    private func installHoverTracking() {
        guard let button = toggleItem?.button else { return }
        hoverView?.removeFromSuperview()
        let hover = HoverTrackingView()
        hover.onEnter = { [weak self] in
            Task { @MainActor [weak self] in
                self?.handleHoverEntered()
            }
        }
        hover.onExit = { [weak self] in
            Task { @MainActor [weak self] in
                self?.handleHoverExited()
            }
        }
        hover.frame = button.bounds
        hover.autoresizingMask = [.width, .height]
        button.addSubview(hover)
        hoverView = hover
    }

    private func uninstallStatusItems() {
        hoverView?.removeFromSuperview()
        hoverView = nil
        toggleItem = nil
        dividerItems.removeAll()
    }

    private func applyMenuBarState() {
        for divider in settings.dividers {
            guard let item = dividerItems[divider.id] else { continue }
            let length: CGFloat
            if isCollapsed && divider.isOverflow {
                length = collapsedDividerLength(for: divider)
            } else {
                length = divider.expandedLength
            }
            item.setLength(length)
        }
        updateToggleItem()
        _ = validateControlOrder(reportFailure: false)
    }

    // MARK: - Overflow drawer

    public func showOverflowPanel() {
        guard state.isStarted else { return }
        if overflowPanel == nil {
            overflowPanel = MenuBarCleanerOverflowPanelController(module: self)
        }
        overflowPanel?.show(relativeTo: toggleItem?.button)
    }

    public func hideOverflowPanel() {
        overflowPanel?.hide()
    }

    private func updateToggleItem() {
        guard let toggleItem else { return }
        toggleItem.setTitle("")
        toggleItem.setSymbol(
            isCollapsed ? "chevron.right.circle.fill" : "chevron.left.circle",
            accessibilityDescription: isCollapsed ? "Reveal hidden menu bar icons" : "Collapse menu bar icons"
        )
    }

    private func collapsedDividerLength(for divider: MenuBarCleanerDivider) -> CGFloat {
        let widestScreenWidth = NSScreen.screens.map(\.frame.width).max() ?? 1728
        return Self.collapsedDividerLength(for: divider, widestScreenWidth: widestScreenWidth)
    }

    @discardableResult
    private func validateControlOrder(reportFailure: Bool = true) -> Bool {
        let dividerX = dividerItems[MenuBarCleanerDivider.mainID]?.buttonOriginX
        let toggleX = toggleItem?.buttonOriginX
        statusMessage = Self.statusMessage(dividerX: dividerX, toggleX: toggleX, isCollapsed: isCollapsed)
        guard let dividerX, let toggleX else {
            if reportFailure { reportLayoutFailure(statusMessage) }
            return false
        }
        let isValid: Bool
        if NSApp.userInterfaceLayoutDirection == .rightToLeft {
            isValid = toggleX <= dividerX
        } else {
            isValid = toggleX >= dividerX
        }
        if isValid {
            recoverFromLayoutFailureIfNeeded()
        } else if reportFailure {
            reportLayoutFailure(statusMessage)
        }
        return isValid
    }

    private func reportLayoutFailure(_ reason: String?) {
        let reason = reason ?? "Place the DropThings chevron on the visible side of its divider before collapsing."
        layoutFailureReason = reason
        state = .degraded(reason: reason)
        logger.warning("Menu bar controls are not in a safe collapse order")
    }

    private func recoverFromLayoutFailureIfNeeded() {
        guard let layoutFailureReason else { return }
        self.layoutFailureReason = nil
        if case .degraded(let reason) = state, reason == layoutFailureReason {
            state = .running
        }
    }

    // MARK: - Testable helpers

    /// Computes the divider length that pushes items off the visible menu bar.
    /// - Parameters:
    ///   - divider: The divider whose length is being computed.
    ///   - widestScreenWidth: The widest connected display in points.
    nonisolated static func collapsedDividerLength(
        for divider: MenuBarCleanerDivider,
        widestScreenWidth: CGFloat
    ) -> CGFloat {
        let requested = max(divider.collapsedLength, widestScreenWidth * 2)
        return min(requested, 10_000)
    }

    /// Returns the user-facing status message for the current control order.
    /// - Parameters:
    ///   - dividerX: The divider button's origin x, if known.
    ///   - toggleX: The toggle button's origin x, if known.
    ///   - isCollapsed: Whether the module is currently collapsed.
    nonisolated static func statusMessage(
        dividerX: CGFloat?,
        toggleX: CGFloat?,
        isCollapsed: Bool
    ) -> String {
        guard dividerX != nil, toggleX != nil else {
            return "DropThings controls are being installed in the menu bar."
        }
        if toggleX! < dividerX! {
            return "The chevron is on the wrong side. Command-drag the DropThings chevron so it sits to the right of the divider."
        } else if isCollapsed {
            return "Collapsed. Click the DropThings chevron to reveal the hidden side."
        } else {
            return "Revealed. Icons placed left of the divider will collapse behind it."
        }
    }

    // MARK: - Hover reveal

    private func handleHoverEntered() {
        guard isCollapsed, settings.hoverRevealDelay > 0 else { return }
        hoverTimer?.invalidate()
        wasHoverRevealed = false
        hoverTimer = Timer.scheduledTimer(withTimeInterval: settings.hoverRevealDelay, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.isCollapsed else { return }
                self.wasHoverRevealed = true
                self.setCollapsed(false, persist: false)
                self.startHoverExitMonitor()
            }
        }
    }

    private func handleHoverExited() {
        hoverTimer?.invalidate()
        hoverTimer = nil
        if wasHoverRevealed {
            startHoverExitMonitor()
        }
    }

    private func startHoverExitMonitor() {
        guard hoverExitMonitor == nil else { return }
        hoverExitMonitor = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] timer in
            Task { @MainActor [weak self] in
                guard let self else {
                    timer.invalidate()
                    return
                }
                guard self.isPointerInMenuBar else {
                    timer.invalidate()
                    self.hoverExitMonitor = nil
                    guard self.wasHoverRevealed else { return }
                    self.wasHoverRevealed = false
                    self.collapseWithoutPersisting()
                    return
                }
            }
        }
    }

    private var isPointerInMenuBar: Bool {
        let pointer = NSEvent.mouseLocation
        return NSScreen.screens.contains { screen in
            let menuBarBottom = screen.visibleFrame.maxY
            return pointer.x >= screen.frame.minX
                && pointer.x <= screen.frame.maxX
                && pointer.y >= menuBarBottom
                && pointer.y <= screen.frame.maxY
        }
    }

    // MARK: - Screen observer

    private func subscribeToScreenChanges() {
        guard screenObserver == nil else { return }
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.isCollapsed else { return }
                self.applyMenuBarState()
            }
        }
    }

    private func unsubscribeFromScreenChanges() {
        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
            self.screenObserver = nil
        }
    }
}
