import Foundation
import Security
@preconcurrency import SystemConfiguration

public final class SystemNetworkServiceOrderController: NetworkServiceOrderControlling, @unchecked Sendable {
    private let queue = DispatchQueue(label: "app.dropthings.network-service-order", qos: .userInitiated)
    private let sessionName = "DropThings Network Priority" as CFString

    public init() {}

    public func snapshot() async throws -> NetworkServiceOrderSnapshot {
        try await perform {
            guard let preferences = SCPreferencesCreate(nil, self.sessionName, nil) else {
                throw NetworkServiceOrderError.preferencesUnavailable
            }
            return try self.readSnapshot(from: preferences)
        }
    }

    public func setPreferred(_ kind: NetworkServiceKind) async throws -> NetworkServiceOrderSnapshot {
        try await perform {
            guard let readPreferences = SCPreferencesCreate(nil, self.sessionName, nil) else {
                throw NetworkServiceOrderError.preferencesUnavailable
            }
            let initial = try self.readSnapshot(from: readPreferences)
            if initial.preferredKind == kind { return initial }

            var authorization: AuthorizationRef?
            let status = AuthorizationCreate(nil, nil, [], &authorization)
            guard status == errAuthorizationSuccess, let authorization else {
                throw NetworkServiceOrderError.authorizationFailed(code: status)
            }
            defer { AuthorizationFree(authorization, []) }

            guard let preferences = SCPreferencesCreateWithAuthorization(
                nil,
                self.sessionName,
                nil,
                authorization
            ) else {
                throw NetworkServiceOrderError.preferencesUnavailable
            }

            guard SCPreferencesLock(preferences, true) else {
                throw self.lastError(stage: "lock")
            }
            defer { SCPreferencesUnlock(preferences) }

            let before = try self.readSnapshot(from: preferences)
            let requestedOrder = try NetworkServiceOrderPlanner.prioritizedOrder(
                preferred: kind,
                snapshot: before
            )
            if requestedOrder == before.orderIdentifiers {
                return before
            }

            guard let currentSet = SCNetworkSetCopyCurrent(preferences) else {
                throw NetworkServiceOrderError.currentLocationUnavailable
            }
            guard SCNetworkSetSetServiceOrder(currentSet, requestedOrder as CFArray) else {
                throw self.lastError(stage: "set")
            }
            guard SCPreferencesCommitChanges(preferences) else {
                throw self.lastError(stage: "save")
            }
            guard SCPreferencesApplyChanges(preferences) else {
                throw self.lastError(stage: "apply")
            }

            SCPreferencesSynchronize(preferences)
            let after = try self.readSnapshot(from: preferences)
            guard after.preferredKind == kind else {
                throw NetworkServiceOrderError.verificationFailed(kind)
            }
            return after
        }
    }

    private func perform<T: Sendable>(_ operation: @escaping @Sendable () throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                continuation.resume(with: Result { try operation() })
            }
        }
    }

    private func readSnapshot(from preferences: SCPreferences) throws -> NetworkServiceOrderSnapshot {
        guard let currentSet = SCNetworkSetCopyCurrent(preferences) else {
            throw NetworkServiceOrderError.currentLocationUnavailable
        }
        guard let rawOrder = SCNetworkSetGetServiceOrder(currentSet) as? [String], !rawOrder.isEmpty else {
            throw NetworkServiceOrderError.serviceOrderUnavailable
        }
        let rawServices = (SCNetworkSetCopyServices(currentSet) as? [SCNetworkService]) ?? []
        let services = rawServices.compactMap(descriptor)
        return NetworkServiceOrderSnapshot(orderIdentifiers: rawOrder, services: services)
    }

    private func descriptor(for service: SCNetworkService) -> NetworkServiceDescriptor? {
        guard let identifier = SCNetworkServiceGetServiceID(service) as String? else { return nil }
        let interface = SCNetworkServiceGetInterface(service)
        let interfaceType = interface.flatMap { SCNetworkInterfaceGetInterfaceType($0) as String? }
        let kind: NetworkServiceKind
        if interfaceType == (kSCNetworkInterfaceTypeEthernet as String) {
            kind = .ethernet
        } else if interfaceType == (kSCNetworkInterfaceTypeIEEE80211 as String) {
            kind = .wifi
        } else {
            kind = .other
        }
        return NetworkServiceDescriptor(
            id: identifier,
            name: (SCNetworkServiceGetName(service) as String?) ?? "Unnamed service",
            interfaceName: interface.flatMap { SCNetworkInterfaceGetBSDName($0) as String? },
            kind: kind,
            isEnabled: SCNetworkServiceGetEnabled(service)
        )
    }

    private func lastError(stage: String) -> NetworkServiceOrderError {
        let code = SCError()
        if code == kSCStatusAccessError { return .authorizationDenied }
        let message = String(cString: SCErrorString(code))
        return .systemConfiguration(stage: stage, code: code, message: message)
    }
}
