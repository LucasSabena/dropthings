import Foundation
import Combine
import SwiftUI

/// Single source of truth for module lifecycle. The settings UI and the
/// diagnostics screen read `states` from here, not from the modules directly.
///
/// The registry is `@MainActor` because it drives SwiftUI state and orchestrates
/// permission-gated UI flows.
@MainActor
public final class ModuleRegistry: ObservableObject {
    /// Persisted under this key. Stores `[ModuleID.rawValue: Bool]`.
    public static let enabledKey = SettingsKey("core.modules.enabled")

    @Published public private(set) var modules: [ModuleID: any DropThingsModule] = [:]
    @Published public private(set) var states: [ModuleID: ModuleState] = [:]

    private let settings: SettingsStore
    private let permissions: PermissionCenter
    private var didStartLaunchTasks = false
    private var stateObservers: [ModuleID: AnyCancellable] = [:]

    public init(settings: SettingsStore, permissions: PermissionCenter) {
        self.settings = settings
        self.permissions = permissions
    }

    // MARK: - Registration

    public func register(_ module: any DropThingsModule) {
        let id = module.id
        modules[module.id] = module
        if states[id] == nil {
            states[id] = module.state
        }

        // A module can degrade or recover long after `start()` returns (for
        // example when a shortcut is rebound or a permission is revoked).
        // Mirror those transitions on the next main-queue turn because
        // ObservableObject emits `objectWillChange` before @Published stores
        // its new value.
        stateObservers[id]?.cancel()
        stateObservers[id] = module.objectWillChange.sink { [weak self, module] _ in
            DispatchQueue.main.async { [weak self, module] in
                self?.mirrorState(of: module, id: id)
            }
        }
    }

    private func mirrorState(of module: any DropThingsModule, id: ModuleID) {
        let missing = permissions.missing(from: module.requiredPermissions)
        if isEnabled(id), !missing.isEmpty {
            states[id] = .needsPermission(missing: missing)
        } else {
            states[id] = module.state
        }
    }

    // MARK: - Boot

    /// Start every module the user previously left enabled. Call once after the
    /// app finishes launching. Does not block the caller.
    public func bootEnabledModules() {
        guard !didStartLaunchTasks else { return }
        didStartLaunchTasks = true
        permissions.refresh()
        for (id, _) in modules where isEnabled(id) {
            Task { await start(id: id) }
        }
    }

    // MARK: - Enable / disable

    public func isEnabled(_ id: ModuleID) -> Bool {
        let enabledMap = enabledFromSettings()
        return enabledMap[id.rawValue] ?? false
    }

    public func setEnabled(_ enabled: Bool, for id: ModuleID) {
        var enabledMap = enabledFromSettings()
        enabledMap[id.rawValue] = enabled
        persistEnabledMap(enabledMap)
        if enabled {
            Task { await start(id: id) }
        } else {
            Task { await stop(id: id) }
        }
    }

    /// Permissions missing for one module at this instant. The settings UI
    /// uses this before enabling a module so it can present a contextual
    /// explanation instead of surprising the user with a system dialog.
    public func missingPermissions(for id: ModuleID) -> Set<SystemPermission> {
        guard let module = modules[id] else { return [] }
        return permissions.missing(from: module.requiredPermissions)
    }

    /// Removes persisted enablement for modules that are no longer part of
    /// the product. Module-specific settings are intentionally left alone so
    /// downgrades remain non-destructive, but retired modules can never boot.
    public func pruneUnregisteredEnablement() {
        let registered = Set(modules.keys.map(\.rawValue))
        let current = enabledFromSettings()
        let retained = current.filter { registered.contains($0.key) }
        guard retained != current else { return }
        persistEnabledMap(retained)
    }

    // MARK: - Lifecycle

    public func start(id: ModuleID) async {
        guard let module = modules[id] else { return }
        states[id] = .starting

        let missing = permissions.missing(from: module.requiredPermissions)
        if !missing.isEmpty {
            states[id] = .needsPermission(missing: missing)
            return
        }

        do {
            try await module.start()
        } catch {
            states[id] = .failed(reason: String(describing: error), recovery: "Disable and re-enable the module.")
            return
        }
        // The module may have set its own state during `start()` — a
        // `.degraded` from a hotkey conflict, a `.needsPermission` from a
        // defensive re-check, etc. We always mirror it so the UI never
        // stays stuck on `.starting` when the module already decided it
        // cannot run. Modules that left `state` untouched fall through to
        // `.running` below.
        if case .off = module.state {
            states[id] = .running
        } else {
            states[id] = module.state
        }
    }

    public func stop(id: ModuleID) async {
        guard let module = modules[id] else { return }
        await module.stop()
        states[id] = .off
    }

    /// Stop every running module. Call from `applicationWillTerminate` so we
    /// never leave an event tap alive.
    public func stopAll() async {
        for (id, _) in modules where states[id] != .off {
            await stop(id: id)
        }
    }

    // MARK: - Permission re-grant

    /// Re-check permissions and try to advance modules that were blocked.
    public func refreshPermissionsAndRetry() async {
        permissions.refresh()
        for (id, module) in modules where isEnabled(id) {
            let missing = permissions.missing(from: module.requiredPermissions)
            if !missing.isEmpty {
                // Permission may be revoked while a listener or event tap is
                // active. Stop the module before publishing the blocked state
                // so privileged resources are released immediately.
                if states[id] != .needsPermission(missing: missing) {
                    await module.stop()
                }
                states[id] = .needsPermission(missing: missing)
            } else if case .needsPermission = states[id] {
                await start(id: id)
            }
        }
    }

    // MARK: - Persistence

    private func enabledFromSettings() -> [String: Bool] {
        guard let data = settings.data(Self.enabledKey) else { return [:] }
        return (try? JSONDecoder().decode([String: Bool].self, from: data)) ?? [:]
    }

    private func persistEnabledMap(_ map: [String: Bool]) {
        guard let data = try? JSONEncoder().encode(map) else { return }
        settings.setData(data, Self.enabledKey)
    }
}
