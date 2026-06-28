import XCTest
@testable import DropThingsCore

@MainActor
final class DiagnosticsStoreTests: XCTestCase {
    func testRecordAppearsInEntries() {
        let store = DiagnosticsStore()
        store.record(level: .info, category: "test", message: "hello")
        XCTAssertEqual(store.entries.count, 1)
        XCTAssertEqual(store.entries.first?.message, "hello")
    }

    func testClearRemovesEntries() {
        let store = DiagnosticsStore()
        store.record(level: .warning, category: "test", message: "x")
        store.clear()
        XCTAssertTrue(store.entries.isEmpty)
    }

    func testRespectsMaxEntries() {
        let store = DiagnosticsStore()
        for index in 0..<(DiagnosticsStore.maxEntries + 50) {
            store.record(level: .info, category: "test", message: "msg-\(index)")
        }
        XCTAssertEqual(store.entries.count, DiagnosticsStore.maxEntries)
        XCTAssertEqual(store.entries.first?.message, "msg-50")
        XCTAssertEqual(store.entries.last?.message, "msg-\(DiagnosticsStore.maxEntries + 49)")
    }
}
