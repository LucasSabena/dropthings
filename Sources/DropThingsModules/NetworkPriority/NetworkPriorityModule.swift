import Combine
import SwiftUI
import DropThingsCore
import DropThingsDesignSystem
import DropThingsPlatform

@MainActor
public final class NetworkPriorityModule: DropThingsModule {
    public let id = ModuleID.networkPriority
    public let name = "Network Priority"
    public let summary = "Switch new connections between Ethernet-first and Wi-Fi-first."
    public let requiredPermissions: [SystemPermission] = []

    @Published public private(set) var state: ModuleState = .off
    @Published public private(set) var currentSnapshot: NetworkServiceOrderSnapshot?
    @Published public private(set) var isApplying = false
    @Published public private(set) var lastError: String?

    private let controller: any NetworkServiceOrderControlling
    private let refreshInterval: Duration
    private var refreshTask: Task<Void, Never>?
    private var generation: UInt64 = 0

    public init() {
        controller = SystemNetworkServiceOrderController()
        refreshInterval = .seconds(5)
    }

    init(
        controller: any NetworkServiceOrderControlling,
        refreshInterval: Duration = .seconds(5)
    ) {
        self.controller = controller
        self.refreshInterval = refreshInterval
    }

    public var menuBarPresentation: ModuleMenuBarPresentation? {
        ModuleMenuBarPresentation(
            iconName: menuBarIconName,
            accessibilityLabel: "Network Priority",
            preferredContentSize: .zero,
            isVisibleByDefault: true
        )
    }

    public var menuBarIconName: String {
        switch currentSnapshot?.preferredKind {
        case .ethernet: return "cable.connector.horizontal"
        case .wifi: return "wifi"
        case .other, .none: return "exclamationmark.triangle"
        }
    }

    public var menuBarAccessibilityLabel: String {
        guard let preferred = currentSnapshot?.preferredKind else {
            return "Network Priority unavailable"
        }
        let next = preferred == .ethernet ? NetworkServiceKind.wifi : .ethernet
        return "Network Priority: \(preferred.displayName) first. Click to prefer \(next.displayName)."
    }

    public var primaryAction: ModulePrimaryAction? {
        guard let current = currentSnapshot?.preferredKind else { return nil }
        let next: NetworkServiceKind = current == .ethernet ? .wifi : .ethernet
        return ModulePrimaryAction(
            title: "Prefer \(next.displayName)",
            iconName: next == .ethernet ? "cable.connector.horizontal" : "wifi"
        ) { [weak self] in
            Task { @MainActor [weak self] in await self?.setPreferred(next) }
        }
    }

    public var commands: [CommandDescriptor] {
        [NetworkServiceKind.ethernet, .wifi].map { kind in
            CommandDescriptor(
                id: "network-priority.prefer-\(kind.rawValue)",
                title: "Prefer \(kind.displayName)",
                subtitle: name,
                iconName: kind == .ethernet ? "cable.connector.horizontal" : "wifi"
            ) { [weak self] in
                Task { @MainActor [weak self] in await self?.setPreferred(kind) }
            }
        }
    }

    public func start() async throws {
        generation &+= 1
        let activeGeneration = generation
        state = .starting
        await refresh(generation: activeGeneration)
        guard generation == activeGeneration else { return }
        startRefreshing(generation: activeGeneration)
    }

    public func stop() async {
        generation &+= 1
        refreshTask?.cancel()
        refreshTask = nil
        isApplying = false
        lastError = nil
        currentSnapshot = nil
        state = .off
    }

    public func refresh() async {
        guard !state.isOff else { return }
        await refresh(generation: generation)
    }

    private func refresh(generation expectedGeneration: UInt64) async {
        do {
            let snapshot = try await controller.snapshot()
            guard generation == expectedGeneration else { return }
            lastError = nil
            apply(snapshot)
        } catch {
            guard generation == expectedGeneration else { return }
            lastError = error.localizedDescription
            currentSnapshot = nil
            state = unavailableState(for: error)
        }
    }

    public func setPreferred(_ kind: NetworkServiceKind) async {
        guard kind == .ethernet || kind == .wifi, !isApplying else { return }
        guard currentSnapshot?.availabilityIssue == nil else { return }
        let activeGeneration = generation
        isApplying = true
        defer { isApplying = false }

        do {
            let snapshot = try await controller.setPreferred(kind)
            guard generation == activeGeneration else { return }
            lastError = nil
            apply(snapshot)
        } catch {
            guard generation == activeGeneration else { return }
            let message = error.localizedDescription
            do {
                let snapshot = try await controller.snapshot()
                guard generation == activeGeneration else { return }
                currentSnapshot = snapshot
                if error as? NetworkServiceOrderError == .authorizationDenied {
                    apply(snapshot)
                } else {
                    state = .degraded(reason: message)
                }
            } catch {
                currentSnapshot = nil
                state = .failed(
                    reason: message,
                    recovery: "Open Network settings, confirm both services exist, then refresh."
                )
            }
            lastError = message
        }
    }

    public func makeSettingsView() -> AnyView {
        AnyView(NetworkPrioritySettingsView(module: self))
    }

    private func apply(_ snapshot: NetworkServiceOrderSnapshot) {
        currentSnapshot = snapshot
        if let issue = snapshot.availabilityIssue {
            state = .unavailable(reason: issue)
        } else if snapshot.preferredKind == nil {
            state = .unavailable(reason: "The current network location has no usable Ethernet/Wi-Fi order.")
        } else {
            state = .running
        }
    }

    private func unavailableState(for error: Error) -> ModuleState {
        switch error as? NetworkServiceOrderError {
        case .currentLocationUnavailable, .serviceOrderUnavailable, .missingService:
            return .unavailable(reason: error.localizedDescription)
        default:
            return .failed(
                reason: error.localizedDescription,
                recovery: "Refresh after checking Network settings."
            )
        }
    }

    private func startRefreshing(generation activeGeneration: UInt64) {
        refreshTask?.cancel()
        refreshTask = Task { @MainActor [weak self] in
            while let self, !Task.isCancelled, self.generation == activeGeneration {
                do {
                    try await Task.sleep(for: self.refreshInterval)
                } catch {
                    return
                }
                guard !Task.isCancelled, !self.isApplying else { continue }
                await self.refresh(generation: activeGeneration)
            }
        }
    }

#if DEBUG
    public func prepareVisualTestingState() {
        currentSnapshot = NetworkServiceOrderSnapshot(
            orderIdentifiers: ["vpn", "ethernet", "wifi"],
            services: [
                NetworkServiceDescriptor(
                    id: "vpn",
                    name: "Work VPN",
                    interfaceName: nil,
                    kind: .other,
                    isEnabled: true
                ),
                NetworkServiceDescriptor(
                    id: "ethernet",
                    name: "USB 10/100/1000 LAN",
                    interfaceName: "en5",
                    kind: .ethernet,
                    isEnabled: true
                ),
                NetworkServiceDescriptor(
                    id: "wifi",
                    name: "Wi-Fi",
                    interfaceName: "en0",
                    kind: .wifi,
                    isEnabled: true
                )
            ]
        )
        state = .running
        lastError = nil
    }
#endif
}
