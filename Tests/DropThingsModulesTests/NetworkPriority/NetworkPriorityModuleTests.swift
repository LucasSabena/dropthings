import XCTest
@testable import DropThingsModules
@testable import DropThingsPlatform

@MainActor
final class NetworkPriorityModuleTests: XCTestCase {
    func testStartPublishesConfirmedPreferenceAndMenuBarState() async throws {
        let controller = FakeNetworkServiceOrderController(snapshot: .ethernetFirst)
        let module = NetworkPriorityModule(controller: controller, refreshInterval: .seconds(60))

        try await module.start()

        XCTAssertEqual(module.state, .running)
        XCTAssertEqual(module.currentSnapshot?.preferredKind, .ethernet)
        XCTAssertEqual(module.menuBarIconName, "cable.connector.horizontal")
        XCTAssertTrue(module.menuBarAccessibilityLabel.contains("Ethernet first"))
        XCTAssertEqual(module.primaryAction?.title, "Prefer Wi-Fi")
        await module.stop()
    }

    func testPreferenceChangeUsesConfirmedResultBeforeChangingIcon() async throws {
        let controller = FakeNetworkServiceOrderController(snapshot: .ethernetFirst)
        let module = NetworkPriorityModule(controller: controller, refreshInterval: .seconds(60))
        try await module.start()

        await module.setPreferred(.wifi)

        XCTAssertEqual(module.state, .running)
        XCTAssertEqual(module.currentSnapshot?.preferredKind, .wifi)
        XCTAssertEqual(module.menuBarIconName, "wifi")
        XCTAssertNil(module.lastError)
        let setCount = await controller.numberOfSets()
        XCTAssertEqual(setCount, 1)
        await module.stop()
    }

    func testAuthorizationDenialKeepsLastConfirmedOrderHealthy() async throws {
        let controller = FakeNetworkServiceOrderController(snapshot: .ethernetFirst)
        await controller.setNextError(.authorizationDenied)
        let module = NetworkPriorityModule(controller: controller, refreshInterval: .seconds(60))
        try await module.start()

        await module.setPreferred(.wifi)

        XCTAssertEqual(module.state, .running)
        XCTAssertEqual(module.currentSnapshot?.preferredKind, .ethernet)
        XCTAssertEqual(module.menuBarIconName, "cable.connector.horizontal")
        XCTAssertEqual(module.lastError, NetworkServiceOrderError.authorizationDenied.localizedDescription)
        await module.stop()
    }

    func testMissingEthernetMakesModuleUnavailableAndDisablesAction() async throws {
        let controller = FakeNetworkServiceOrderController(snapshot: .wifiOnly)
        let module = NetworkPriorityModule(controller: controller, refreshInterval: .seconds(60))

        try await module.start()

        guard case .unavailable(let reason) = module.state else {
            return XCTFail("Expected unavailable, got \(module.state)")
        }
        XCTAssertTrue(reason.contains("Ethernet"))
        XCTAssertNil(module.primaryAction)
        XCTAssertEqual(module.menuBarIconName, "exclamationmark.triangle")
        await module.stop()
    }

    func testRapidRepeatedChangesProduceOneWrite() async throws {
        let controller = FakeNetworkServiceOrderController(
            snapshot: .ethernetFirst,
            setDelay: .milliseconds(100)
        )
        let module = NetworkPriorityModule(controller: controller, refreshInterval: .seconds(60))
        try await module.start()

        let first = Task { @MainActor in await module.setPreferred(.wifi) }
        try await Task.sleep(for: .milliseconds(10))
        await module.setPreferred(.wifi)
        await first.value

        let setCount = await controller.numberOfSets()
        XCTAssertEqual(setCount, 1)
        XCTAssertEqual(module.currentSnapshot?.preferredKind, .wifi)
        await module.stop()
    }

    func testStopClearsTransientStateWithoutRestoringSystemOrder() async throws {
        let controller = FakeNetworkServiceOrderController(snapshot: .ethernetFirst)
        let module = NetworkPriorityModule(controller: controller, refreshInterval: .seconds(60))
        try await module.start()
        await module.setPreferred(.wifi)

        await module.stop()

        XCTAssertEqual(module.state, .off)
        XCTAssertNil(module.currentSnapshot)
        let persistedSnapshot = await controller.currentSnapshot()
        XCTAssertEqual(persistedSnapshot.preferredKind, .wifi)
    }

    func testStopDuringWriteDoesNotResurrectModuleWhenResultArrives() async throws {
        let controller = FakeNetworkServiceOrderController(
            snapshot: .ethernetFirst,
            setDelay: .milliseconds(100)
        )
        let module = NetworkPriorityModule(controller: controller, refreshInterval: .seconds(60))
        try await module.start()

        let write = Task { @MainActor in await module.setPreferred(.wifi) }
        try await Task.sleep(for: .milliseconds(10))
        await module.stop()
        await write.value

        XCTAssertEqual(module.state, .off)
        XCTAssertNil(module.currentSnapshot)
        XCTAssertFalse(module.isApplying)
    }
}

private actor FakeNetworkServiceOrderController: NetworkServiceOrderControlling {
    private(set) var snapshotValue: NetworkServiceOrderSnapshot
    private(set) var setCount = 0
    private var nextError: NetworkServiceOrderError?
    private let setDelay: Duration?

    init(snapshot: NetworkServiceOrderSnapshot, setDelay: Duration? = nil) {
        snapshotValue = snapshot
        self.setDelay = setDelay
    }

    func setNextError(_ error: NetworkServiceOrderError) {
        nextError = error
    }

    func numberOfSets() -> Int { setCount }

    func currentSnapshot() -> NetworkServiceOrderSnapshot { snapshotValue }

    func snapshot() async throws -> NetworkServiceOrderSnapshot {
        snapshotValue
    }

    func setPreferred(_ kind: NetworkServiceKind) async throws -> NetworkServiceOrderSnapshot {
        setCount += 1
        if let setDelay { try await Task.sleep(for: setDelay) }
        if let nextError {
            self.nextError = nil
            throw nextError
        }
        let order = try NetworkServiceOrderPlanner.prioritizedOrder(
            preferred: kind,
            snapshot: snapshotValue
        )
        snapshotValue = NetworkServiceOrderSnapshot(
            orderIdentifiers: order,
            services: snapshotValue.services
        )
        return snapshotValue
    }
}

private extension NetworkServiceOrderSnapshot {
    static let ethernetFirst = NetworkServiceOrderSnapshot(
        orderIdentifiers: ["vpn", "ethernet", "wifi"],
        services: [
            NetworkServiceDescriptor(id: "vpn", name: "VPN", interfaceName: nil, kind: .other, isEnabled: true),
            NetworkServiceDescriptor(id: "ethernet", name: "Ethernet", interfaceName: "en1", kind: .ethernet, isEnabled: true),
            NetworkServiceDescriptor(id: "wifi", name: "Wi-Fi", interfaceName: "en0", kind: .wifi, isEnabled: true)
        ]
    )

    static let wifiOnly = NetworkServiceOrderSnapshot(
        orderIdentifiers: ["wifi"],
        services: [
            NetworkServiceDescriptor(id: "wifi", name: "Wi-Fi", interfaceName: "en0", kind: .wifi, isEnabled: true)
        ]
    )
}
