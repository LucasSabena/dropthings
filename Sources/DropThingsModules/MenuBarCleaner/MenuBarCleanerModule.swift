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

    private let settingsStore: SettingsStore
    private let logger = ModuleLogger(subsystem: "app.dropthings", category: "menu-bar-cleaner")

    private var dividerItem: DropThingsStatusItem?
    private var toggleItem: DropThingsStatusItem?
    private var hoverView: HoverTrackingView?
    private var screenObserver: NSObjectProtocol?
    private var hoverTimer: Timer?
    private var wasHoverRevealed: Bool = false
    private let expandedDividerLength: CGFloat = 18

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
        saveSettings(new)
        logger.notice("Menu Bar Cleaner reset: all icons visible, always-visible list cleared, no active profile")
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
        guard dividerItem == nil else { return }
        let divider = DropThingsStatusItem(length: expandedDividerLength)
        divider.setAutosaveName("dropthings-menu-bar-cleaner-divider")
        divider.setSymbol("line.vertical", accessibilityDescription: "DropThings menu bar divider")
        divider.show()
        dividerItem = divider

        let toggle = DropThingsStatusItem()
        toggle.setAutosaveName("dropthings-menu-bar-cleaner-toggle")
        toggle.setOnClick { [weak self] in
            self?.toggleCollapsed()
        }
        toggle.show()
        toggleItem = toggle
        installHoverTracking()
        updateToggleItem()
    }

    private func installHoverTracking() {
        guard let button = toggleItem?.button else { return }
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
        dividerItem = nil
    }

    private func applyMenuBarState() {
        dividerItem?.setLength(isCollapsed ? collapsedDividerLength : expandedDividerLength)
        updateToggleItem()
        validateControlOrder()
    }

    private func updateToggleItem() {
        guard let toggleItem else { return }
        toggleItem.setTitle("")
        toggleItem.setSymbol(
            isCollapsed ? "chevron.right.circle.fill" : "chevron.left.circle",
            accessibilityDescription: isCollapsed ? "Reveal hidden menu bar icons" : "Collapse menu bar icons"
        )
    }

    private var collapsedDividerLength: CGFloat {
        let widestScreen = NSScreen.screens.map(\.frame.width).max() ?? 1728
        return max(500, min(widestScreen * 2, 10_000))
    }

    private func validateControlOrder() {
        guard let dividerX = dividerItem?.buttonOriginX,
              let toggleX = toggleItem?.buttonOriginX else {
            statusMessage = nil
            return
        }
        if toggleX < dividerX {
            statusMessage = "Move the DropThings chevron to the right of the divider with Command-drag."
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
                self.dividerItem?.setLength(self.collapsedDividerLength)
                self.validateControlOrder()
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
