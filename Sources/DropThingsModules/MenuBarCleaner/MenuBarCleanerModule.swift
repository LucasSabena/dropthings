import AppKit
import SwiftUI
import DropThingsCore
import DropThingsDesignSystem
import DropThingsPlatform
import os

/// Hidden-Bar-style overflow for menu bar items. DropThings owns a divider
/// and a toggle item; the user Command-drags icons to the left of the divider
/// once, then Collapse expands the divider so that zone moves off-screen.
public final class MenuBarCleanerModule: DropThingsModule, ObservableObject {
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
    private var wasHoverRevealed: Bool = false
    private var overflowPanel: MenuBarCleanerOverflowPanelController?

    public init(settings: SettingsStore, permissions: PermissionCenter) {
        self.settingsStore = settings
        self.settings = settings.loadMenuBarCleanerSettings()
    }

    public func start() async throws {
        installStatusItems()
        subscribeToScreenChanges()
        applyProfileOnLaunch()
        state = .running
        logger.info("Menu Bar Cleaner started")
    }

    public func stop() async {
        revealForShutdown()
        uninstallStatusItems()
        unsubscribeFromScreenChanges()
        hoverTimer?.invalidate()
        hoverTimer = nil
        state = .off
        logger.info("Menu Bar Cleaner stopped")
    }

    // MARK: - Actions

    public func toggleCollapsed() {
        isCollapsed ? reveal() : collapse()
    }

    public func collapse() {
        guard !isCollapsed else { return }
        isCollapsed = true
        persistCollapsedToActiveProfile()
        applyMenuBarState()
        logger.info("Menu bar overflow collapsed")
    }

    public func reveal() {
        guard isCollapsed else { return }
        isCollapsed = false
        persistCollapsedToActiveProfile()
        applyMenuBarState()
        logger.info("Menu bar overflow revealed")
    }

    private func revealForShutdown() {
        guard isCollapsed else { return }
        isCollapsed = false
        applyMenuBarState()
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
        if let profile = new.activeProfile {
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

    public func addDivider(name: String, symbolName: String = "line.vertical", isOverflow: Bool = false) {
        var new = settings
        let divider = MenuBarCleanerDivider(name: name, symbolName: symbolName, isOverflow: isOverflow)
        new.dividers.append(divider)
        saveSettings(new)
        installDividerStatusItem(divider)
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

    public func toggleAlwaysVisible(_ bundleID: String) {
        var new = settings
        if new.alwaysVisibleBundleIDs.contains(bundleID) {
            new.alwaysVisibleBundleIDs.removeAll { $0 == bundleID }
        } else {
            new.alwaysVisibleBundleIDs.append(bundleID)
        }
        saveSettings(new)
    }

    public func safeReset() {
        reveal()
        var new = settings
        new.alwaysVisibleBundleIDs = []
        new.activeProfileID = nil
        new.dividers = [.defaultMain]
        new.drawerMode = false
        saveSettings(new)
        uninstallStatusItems()
        installStatusItems()
        logger.notice("Menu Bar Cleaner reset: all icons visible, always-visible list cleared, no active profile, dividers reset")
    }

    // MARK: - SwiftUI surface

    public func makeSettingsView() -> AnyView {
        AnyView(MenuBarCleanerSettingsView(module: self))
    }

    // MARK: - Settings persistence

    private func saveSettings(_ new: MenuBarCleanerSettings) {
        settings = new
        settingsStore.saveMenuBarCleanerSettings(new)
    }

    private func persistCollapsedToActiveProfile() {
        guard let activeID = settings.activeProfileID,
              let index = settings.profiles.firstIndex(where: { $0.id == activeID }) else { return }
        var new = settings
        new.profiles[index].collapsed = isCollapsed
        saveSettings(new)
    }

    private func applyProfileOnLaunch() {
        if let profile = settings.activeProfile {
            isCollapsed = profile.collapsed
        } else {
            isCollapsed = settings.collapseOnLaunch
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
        validateControlOrder()
    }

    // MARK: - Overflow drawer

    public func showOverflowPanel() {
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
        let widestScreen = NSScreen.screens.map(\.frame.width).max() ?? 1728
        return max(divider.collapsedLength, min(widestScreen * 2, 10_000))
    }

    private func validateControlOrder() {
        guard let mainItem = dividerItems[MenuBarCleanerDivider.mainID],
              let dividerX = mainItem.buttonOriginX,
              let toggleX = toggleItem?.buttonOriginX else {
            statusMessage = nil
            return
        }
        if toggleX < dividerX {
            statusMessage = "Move the DropThings chevron to the right of the main divider with Command-drag."
        } else if isCollapsed {
            statusMessage = "Collapsed. Click the DropThings chevron to reveal the hidden side."
        } else {
            statusMessage = "Revealed. Icons placed left of the divider will collapse behind it."
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
                self.reveal()
            }
        }
    }

    private func handleHoverExited() {
        hoverTimer?.invalidate()
        hoverTimer = nil
        guard wasHoverRevealed else { return }
        wasHoverRevealed = false
        collapse()
    }

    // MARK: - Screen observer

    private func subscribeToScreenChanges() {
        guard screenObserver == nil else { return }
        screenObserver = NSWorkspace.shared.notificationCenter.addObserver(
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
            NSWorkspace.shared.notificationCenter.removeObserver(screenObserver)
            self.screenObserver = nil
        }
    }
}
