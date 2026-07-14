import Combine
import Foundation

/// Persisted, per-module visibility choices for independent menu-bar items.
/// Keeping this in Core prevents every module from inventing a UserDefaults
/// key and gives the app shell one observable source of truth.
@MainActor
public final class ModuleMenuBarPreferences: ObservableObject {
    public static let visibilityKey = SettingsKey("core.modules.menu-bar-visibility")

    @Published public private(set) var explicitVisibility: [String: Bool]

    private let settings: SettingsStore

    public init(settings: SettingsStore) {
        self.settings = settings
        if let data = settings.data(Self.visibilityKey),
           let decoded = try? JSONDecoder().decode([String: Bool].self, from: data) {
            explicitVisibility = decoded
        } else {
            explicitVisibility = [:]
        }
    }

    public func isVisible(
        for moduleID: ModuleID,
        default defaultValue: Bool
    ) -> Bool {
        explicitVisibility[moduleID.rawValue] ?? defaultValue
    }

    public func setVisible(_ visible: Bool, for moduleID: ModuleID) {
        explicitVisibility[moduleID.rawValue] = visible
        persist()
    }

    public func prune(registeredModuleIDs: Set<ModuleID>) {
        let registered = Set(registeredModuleIDs.map(\.rawValue))
        let retained = explicitVisibility.filter { registered.contains($0.key) }
        guard retained != explicitVisibility else { return }
        explicitVisibility = retained
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(explicitVisibility) else { return }
        settings.setData(data, Self.visibilityKey)
    }
}
