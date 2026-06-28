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

    public init(settings: SettingsStore, permissions: PermissionCenter) {
        self.settings = settings
        self.permissions = permissions
    }

    // MARK: - Registration

    public func register(_ module: any DropThingsModule) {
        modules[module.id] = module
        if states[module.id] == nil {
            states[module.id] = .off
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
            states[id] = module.state
            if case .off = states[id] ?? .off {
                states[id] = .running
            }
        } catch {
            states[id] = .failed(reason: String(describing: error), recovery: "Disable and re-enable the module.")
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
            guard case .needsPermission = states[id] else { continue }
            let missing = permissions.missing(from: module.requiredPermissions)
            if missing.isEmpty {
                await start(id: id)
            } else {
                states[id] = .needsPermission(missing: missing)
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
