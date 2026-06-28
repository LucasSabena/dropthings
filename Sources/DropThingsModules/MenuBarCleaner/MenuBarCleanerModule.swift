import AppKit
import Combine
import SwiftUI
import DropThingsCore
import DropThingsDesignSystem
import DropThingsPlatform
import os

/// Hides menu bar items the user does not want to see and keeps the rest at
/// their natural position. Accessibility is required because the only way
/// to enumerate and toggle the OS-level menu bar extras is the macOS
/// accessibility API (`kAXMenuBarExtrasAttribute`).
///
/// v1 adds two DropThings-owned status items:
/// - A separator on the right side of the menu bar so the user can see
///   where the visible/hidden boundary is.
/// - A reveal button with a chevron icon. Click toggles between honoring
///   the user's hide list and showing every item.
public final class MenuBarCleanerModule: DropThingsModule, ObservableObject {
    public let id = ModuleID.menuBarCleaner
    public let name = "Menu Bar Cleaner"
    public let summary = "Hide menu bar icons you don't need. Bring them back any time."
    public let requiredPermissions: [SystemPermission] = [.accessibility]

    @Published public private(set) var state: ModuleState = .off
    @Published public private(set) var settings: MenuBarCleanerSettings
    @Published public private(set) var discoveredItems: [MenuBarItem] = []
    @Published public private(set) var lastRefreshError: String?
    @Published public private(set) var isRevealing: Bool = false

    private let settingsStore: SettingsStore
    private let permissions: PermissionCenter
    private let controller: MenuBarController
    private let logger = ModuleLogger(subsystem: "app.dropthings", category: "menu-bar-cleaner")

    private var separator: DropThingsStatusItem?
    private var revealButton: DropThingsStatusItem?
    private var workspaceObservers: [NSObjectProtocol] = []

    public init(settings: SettingsStore, permissions: PermissionCenter) {
        self.settingsStore = settings
        self.permissions = permissions
        self.settings = settings.loadMenuBarCleanerSettings()
        self.controller = MenuBarController()
    }

    public func start() async throws {
        guard permissions.state(for: .accessibility) == .granted else {
            state = .needsPermission(missing: [.accessibility])
            logger.notice("Start blocked: Accessibility not granted")
            return
        }
        refresh()
        if case .failed = state { return }
        installStatusItems()
        subscribeToWorkspace()
        state = .running
        logger.info("Menu Bar Cleaner started with \(self.discoveredItems.count) items")
    }

    public func stop() async {
        uninstallStatusItems()
        unsubscribeFromWorkspace()
        _ = controller.applyHidden([])
        discoveredItems = []
        state = .off
        logger.info("Menu Bar Cleaner stopped; menu bar restored")
    }

    // MARK: - Status items

    private func installStatusItems() {
        // Idempotent: a re-entrant start (e.g. after a permission re-grant
        // path) must not double-install the separator or the reveal button.
        guard separator == nil else { return }
        let separator = DropThingsStatusItem(length: 1)
        separator.setSymbol("circle.fill", accessibilityDescription: "DropThings divider")
        separator.show()
        self.separator = separator

        let reveal = DropThingsStatusItem()
        reveal.setOnClick { [weak self] in
            self?.toggleReveal()
        }
        updateRevealButton(reveal)
        reveal.show()
        self.revealButton = reveal
    }

    private func uninstallStatusItems() {
        revealButton = nil
        separator = nil
    }

    private func updateRevealButton(_ button: DropThingsStatusItem) {
        let hiddenCount = isRevealing ? 0 : settings.hiddenItemIds.count
        if hiddenCount == 0 {
            button.setSymbol("checkmark.circle", accessibilityDescription: "All menu bar items visible")
            button.setTitle("")
        } else {
            let symbol = isRevealing ? "chevron.up" : "chevron.down"
            button.setSymbol(symbol, accessibilityDescription: isRevealing ? "Hide items again" : "Show hidden items")
            button.setTitle("\(hiddenCount)")
        }
    }

    public func toggleReveal() {
        isRevealing.toggle()
        let target: Set<String> = isRevealing ? [] : settings.hiddenItemIds
        let result = controller.applyHidden(target)
        reportApplyResult(result, context: isRevealing ? "Reveal-all engaged" : "Reveal-all released, hide list re-applied")
        if let revealButton {
            updateRevealButton(revealButton)
        }
    }

    // MARK: - Workspace observer

    private func subscribeToWorkspace() {
        let center = NSWorkspace.shared.notificationCenter
        let didLaunch = center.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // Re-enumerate after a short delay so the launched app has time
            // to register its status item.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self?.refresh()
            }
        }
        let didTerminate = center.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self?.refresh()
            }
        }
        workspaceObservers = [didLaunch, didTerminate]
    }

    private func unsubscribeFromWorkspace() {
        let center = NSWorkspace.shared.notificationCenter
        for observer in workspaceObservers {
            center.removeObserver(observer)
        }
        workspaceObservers.removeAll()
    }

    // MARK: - Discovery

    /// Re-enumerate the menu bar. Call after the user installs or removes
    /// menu-bar apps so the settings list reflects current state.
    public func refresh() {
        do {
            let items = try controller.refresh()
            discoveredItems = items.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
            lastRefreshError = nil
            if !isRevealing {
                let result = controller.applyHidden(settings.hiddenItemIds)
                reportApplyResult(result, context: "Refreshed menu bar: \(items.count) items")
            }
            if let revealButton {
                updateRevealButton(revealButton)
            }
            logger.info("Refreshed menu bar: \(items.count) items")
        } catch let error as MenuBarController.RefreshError {
            handle(error: error)
        } catch {
            state = .failed(reason: String(describing: error), recovery: "Disable and re-enable the module.")
            lastRefreshError = String(describing: error)
        }
    }

    private func handle(error: MenuBarController.RefreshError) {
        switch error {
        case .accessibilityDenied:
            let missing = permissions.missing(from: requiredPermissions)
            state = .needsPermission(missing: missing)
            lastRefreshError = "Accessibility not granted"
        case .enumerationFailed:
            state = .degraded(reason: "Could not enumerate menu bar. macOS may be hiding some controls.")
            lastRefreshError = "Enumeration failed"
        }
    }

    // MARK: - Settings surface

    public var hiddenIds: Set<String> { settings.hiddenItemIds }

    public func setHidden(_ id: String, hidden: Bool) {
        var new = settings
        if hidden {
            new.hiddenItemIds.insert(id)
        } else {
            new.hiddenItemIds.remove(id)
        }
        applySettings(new)
    }

    public func showAll() {
        applySettings(MenuBarCleanerSettings())
    }

    private func applySettings(_ new: MenuBarCleanerSettings) {
        settings = new
        settingsStore.saveMenuBarCleanerSettings(new)
        if state == .running && !isRevealing {
            let result = controller.applyHidden(new.hiddenItemIds)
            reportApplyResult(result, context: "Applied hide list (\(new.hiddenItemIds.count) items hidden)")
        } else {
            logger.info("Applied hide list (\(new.hiddenItemIds.count) items hidden)")
        }
        if let revealButton {
            updateRevealButton(revealButton)
        }
    }

    private func reportApplyResult(_ result: MenuBarController.ApplyResult, context: String) {
        if result.hasFailures {
            lastRefreshError = "\(result.failed.count) item(s) could not be hidden. macOS may not allow it for some items."
            state = .degraded(reason: lastRefreshError!)
            logger.warning("\(context); \(result.failed.count) failed: \(result.failed)")
        } else {
            logger.info(context)
        }
    }

    // MARK: - SwiftUI surface

    public func makeSettingsView() -> AnyView {
        AnyView(MenuBarCleanerSettingsView(module: self))
    }
}
