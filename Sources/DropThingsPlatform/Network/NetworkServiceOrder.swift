import Foundation

public enum NetworkServiceKind: String, Codable, Sendable, CaseIterable {
    case ethernet
    case wifi
    case other

    public var displayName: String {
        switch self {
        case .ethernet: return "Ethernet"
        case .wifi: return "Wi-Fi"
        case .other: return "Other"
        }
    }
}

public struct NetworkServiceDescriptor: Equatable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let interfaceName: String?
    public let kind: NetworkServiceKind
    public let isEnabled: Bool

    public init(
        id: String,
        name: String,
        interfaceName: String?,
        kind: NetworkServiceKind,
        isEnabled: Bool
    ) {
        self.id = id
        self.name = name
        self.interfaceName = interfaceName
        self.kind = kind
        self.isEnabled = isEnabled
    }
}

public struct NetworkServiceOrderSnapshot: Equatable, Sendable {
    public let orderIdentifiers: [String]
    public let services: [NetworkServiceDescriptor]

    public init(orderIdentifiers: [String], services: [NetworkServiceDescriptor]) {
        self.orderIdentifiers = orderIdentifiers
        self.services = services
    }

    public var orderedServices: [NetworkServiceDescriptor] {
        let byID = services.reduce(into: [String: NetworkServiceDescriptor]()) {
            $0[$1.id] = $1
        }
        return orderIdentifiers.compactMap { byID[$0] }
    }

    public func enabledServices(of kind: NetworkServiceKind) -> [NetworkServiceDescriptor] {
        orderedServices.filter { $0.isEnabled && $0.kind == kind }
    }

    public var preferredKind: NetworkServiceKind? {
        let participants = orderedServices.filter {
            $0.isEnabled && ($0.kind == .ethernet || $0.kind == .wifi)
        }
        guard participants.contains(where: { $0.kind == .ethernet }),
              participants.contains(where: { $0.kind == .wifi }) else {
            return nil
        }
        return participants.first?.kind
    }

    public var availabilityIssue: String? {
        guard !enabledServices(of: .ethernet).isEmpty else {
            return "No enabled Ethernet service exists in the current network location."
        }
        guard !enabledServices(of: .wifi).isEmpty else {
            return "No enabled Wi-Fi service exists in the current network location."
        }
        return nil
    }
}

public enum NetworkServiceOrderError: LocalizedError, Equatable, Sendable {
    case preferencesUnavailable
    case currentLocationUnavailable
    case serviceOrderUnavailable
    case missingService(NetworkServiceKind)
    case authorizationFailed(code: Int32)
    case authorizationDenied
    case unsupportedPreference
    case systemConfiguration(stage: String, code: Int32, message: String)
    case verificationFailed(NetworkServiceKind)

    public var errorDescription: String? {
        switch self {
        case .preferencesUnavailable:
            return "macOS did not provide access to its network preferences."
        case .currentLocationUnavailable:
            return "macOS did not provide the current network location."
        case .serviceOrderUnavailable:
            return "The current network location has no explicit service order."
        case .missingService(let kind):
            return "No enabled \(kind.displayName) service exists in the current network location."
        case .authorizationFailed(let code):
            return "macOS could not start administrator authorization (error \(code))."
        case .authorizationDenied:
            return "The network priority was not changed because macOS did not authorize it."
        case .unsupportedPreference:
            return "Only Ethernet or Wi-Fi can be selected as the preferred connection."
        case .systemConfiguration(let stage, let code, let message):
            return "macOS could not \(stage) the network service order: \(message) (\(code))."
        case .verificationFailed(let kind):
            return "macOS accepted the change but did not report \(kind.displayName) as the first service."
        }
    }
}

public protocol NetworkServiceOrderControlling: Sendable {
    func snapshot() async throws -> NetworkServiceOrderSnapshot
    func setPreferred(_ kind: NetworkServiceKind) async throws -> NetworkServiceOrderSnapshot
}

public enum NetworkServiceOrderPlanner {
    public static func prioritizedOrder(
        preferred kind: NetworkServiceKind,
        snapshot: NetworkServiceOrderSnapshot
    ) throws -> [String] {
        guard kind == .ethernet || kind == .wifi else {
            throw NetworkServiceOrderError.unsupportedPreference
        }
        let alternate: NetworkServiceKind = kind == .ethernet ? .wifi : .ethernet
        let serviceByID = snapshot.services.reduce(into: [String: NetworkServiceDescriptor]()) {
            $0[$1.id] = $1
        }
        let preferredIDs = snapshot.orderIdentifiers.filter {
            serviceByID[$0]?.isEnabled == true && serviceByID[$0]?.kind == kind
        }
        let alternateIDs = snapshot.orderIdentifiers.filter {
            serviceByID[$0]?.isEnabled == true && serviceByID[$0]?.kind == alternate
        }

        guard !preferredIDs.isEmpty else { throw NetworkServiceOrderError.missingService(kind) }
        guard !alternateIDs.isEmpty else { throw NetworkServiceOrderError.missingService(alternate) }

        let participantIDs = Set(preferredIDs + alternateIDs)
        var replacements = ArraySlice(preferredIDs + alternateIDs)
        return snapshot.orderIdentifiers.map { identifier in
            guard participantIDs.contains(identifier), let replacement = replacements.popFirst() else {
                return identifier
            }
            return replacement
        }
    }
}
