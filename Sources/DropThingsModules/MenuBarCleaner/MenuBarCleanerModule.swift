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
    private var screenObserver: NSObjectProtocol?
    private let expandedDividerLength: CGFloat = 18

    public init(settings: SettingsStore, permissions: PermissionCenter) {
        self.settingsStore = settings
        self.settings = settings.loadMenuBarCleanerSettings()
    }

    public func start() async throws {
        installStatusItems()
        subscribeToScreenChanges()
        isCollapsed = settings.collapseOnLaunch
        applyMenuBarState()
        state = .running
        logger.info("Menu Bar Cleaner started")
    }

    public func stop() async {
        revealForShutdown()
        uninstallStatusItems()
        unsubscribeFromScreenChanges()
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
        applyMenuBarState()
        logger.info("Menu bar overflow collapsed")
    }

    public func reveal() {
        guard isCollapsed else { return }
        isCollapsed = false
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
        settings = new
        settingsStore.saveMenuBarCleanerSettings(new)
    }

    public var collapseOnLaunch: Bool {
        settings.collapseOnLaunch
    }

    // MARK: - SwiftUI surface

    public func makeSettingsView() -> AnyView {
        AnyView(MenuBarCleanerSettingsView(module: self))
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
        updateToggleItem()
    }

    private func uninstallStatusItems() {
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
                self.dividerItem?.setLength(self.collapsedDividerLength)
                self.validateControlOrder()
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
