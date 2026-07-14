import XCTest
@testable import DropThingsPlatform

final class SystemNetworkServiceOrderControllerTests: XCTestCase {
    func testReadsLiveServiceOrderWithoutMutation() async throws {
        let controller = SystemNetworkServiceOrderController()
        do {
            let snapshot = try await controller.snapshot()
            XCTAssertFalse(snapshot.orderIdentifiers.isEmpty)
            XCTAssertFalse(snapshot.services.isEmpty)
            XCTAssertTrue(Set(snapshot.orderedServices.map(\.id)).isSubset(of: Set(snapshot.orderIdentifiers)))
        } catch NetworkServiceOrderError.currentLocationUnavailable,
                NetworkServiceOrderError.serviceOrderUnavailable {
            throw XCTSkip("This test host has no readable current network service order.")
        }
    }
}
