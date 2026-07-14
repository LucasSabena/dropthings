import XCTest
@testable import DropThingsPlatform

final class NetworkServiceOrderPlannerTests: XCTestCase {
    func testWiFiFirstPreservesUnrelatedSlotsAndRelativeOrder() throws {
        let snapshot = makeSnapshot(
            order: ["vpn", "ethernet-1", "other", "wifi", "ethernet-2"],
            services: [
                service("vpn", .other),
                service("ethernet-1", .ethernet),
                service("other", .other),
                service("wifi", .wifi),
                service("ethernet-2", .ethernet)
            ]
        )

        let result = try NetworkServiceOrderPlanner.prioritizedOrder(
            preferred: .wifi,
            snapshot: snapshot
        )

        XCTAssertEqual(result, ["vpn", "wifi", "other", "ethernet-1", "ethernet-2"])
    }

    func testEthernetFirstPreservesMultipleAdapterOrder() throws {
        let snapshot = makeSnapshot(
            order: ["wifi-1", "vpn", "ethernet-1", "wifi-2", "ethernet-2"],
            services: [
                service("wifi-1", .wifi),
                service("vpn", .other),
                service("ethernet-1", .ethernet),
                service("wifi-2", .wifi),
                service("ethernet-2", .ethernet)
            ]
        )

        let result = try NetworkServiceOrderPlanner.prioritizedOrder(
            preferred: .ethernet,
            snapshot: snapshot
        )

        XCTAssertEqual(result, ["ethernet-1", "vpn", "ethernet-2", "wifi-1", "wifi-2"])
    }

    func testDisabledServicesNeverParticipateOrMove() throws {
        let snapshot = makeSnapshot(
            order: ["disabled-wifi", "ethernet", "virtual", "wifi"],
            services: [
                service("disabled-wifi", .wifi, enabled: false),
                service("ethernet", .ethernet),
                service("virtual", .other),
                service("wifi", .wifi)
            ]
        )

        let result = try NetworkServiceOrderPlanner.prioritizedOrder(
            preferred: .wifi,
            snapshot: snapshot
        )

        XCTAssertEqual(result, ["disabled-wifi", "wifi", "virtual", "ethernet"])
    }

    func testAlreadyPreferredOrderIsNoOp() throws {
        let snapshot = makeSnapshot(
            order: ["vpn", "wifi", "ethernet"],
            services: [service("vpn", .other), service("wifi", .wifi), service("ethernet", .ethernet)]
        )

        let result = try NetworkServiceOrderPlanner.prioritizedOrder(
            preferred: .wifi,
            snapshot: snapshot
        )

        XCTAssertEqual(result, snapshot.orderIdentifiers)
    }

    func testMissingEnabledKindThrowsInsteadOfGuessing() {
        let snapshot = makeSnapshot(
            order: ["wifi", "disabled-ethernet"],
            services: [service("wifi", .wifi), service("disabled-ethernet", .ethernet, enabled: false)]
        )

        XCTAssertThrowsError(
            try NetworkServiceOrderPlanner.prioritizedOrder(preferred: .ethernet, snapshot: snapshot)
        ) { error in
            XCTAssertEqual(error as? NetworkServiceOrderError, .missingService(.ethernet))
        }
    }

    func testOtherCannotBeSelectedAsPreference() {
        let snapshot = makeSnapshot(
            order: ["wifi", "ethernet"],
            services: [service("wifi", .wifi), service("ethernet", .ethernet)]
        )

        XCTAssertThrowsError(
            try NetworkServiceOrderPlanner.prioritizedOrder(preferred: .other, snapshot: snapshot)
        ) { error in
            XCTAssertEqual(error as? NetworkServiceOrderError, .unsupportedPreference)
        }
    }

    func testSnapshotPreferenceIgnoresDisabledServices() {
        let snapshot = makeSnapshot(
            order: ["disabled-ethernet", "wifi", "ethernet"],
            services: [
                service("disabled-ethernet", .ethernet, enabled: false),
                service("wifi", .wifi),
                service("ethernet", .ethernet)
            ]
        )

        XCTAssertEqual(snapshot.preferredKind, .wifi)
    }

    private func makeSnapshot(
        order: [String],
        services: [NetworkServiceDescriptor]
    ) -> NetworkServiceOrderSnapshot {
        NetworkServiceOrderSnapshot(orderIdentifiers: order, services: services)
    }

    private func service(
        _ id: String,
        _ kind: NetworkServiceKind,
        enabled: Bool = true
    ) -> NetworkServiceDescriptor {
        NetworkServiceDescriptor(
            id: id,
            name: id,
            interfaceName: nil,
            kind: kind,
            isEnabled: enabled
        )
    }
}
