import XCTest
@testable import DropThingsCore
@testable import DropThingsModules

final class PaletteHistoryStoreTests: XCTestCase {
    func testRecordsSuccessWithFrequencyCapAndBoundedCount() {
        let store = SettingsStore(backend: InMemorySettingsBackend())
        let clock = HistoryClock()
        let history = PaletteHistoryStore(settings: store, maximumRecords: 2, now: { clock.next() })
        history.recordSuccessfulAction(resultID: "one")
        history.recordSuccessfulAction(resultID: "one")
        history.recordSuccessfulAction(resultID: "two")
        history.recordSuccessfulAction(resultID: "three")
        XCTAssertEqual(history.records().count, 2)
        XCTAssertNotNil(history.scores()["three"])
    }

    func testFrequencyCapsAtOneHundredUses() {
        let store = SettingsStore(backend: InMemorySettingsBackend())
        let history = PaletteHistoryStore(settings: store)
        for _ in 0..<150 { history.recordSuccessfulAction(resultID: "frequent") }
        XCTAssertEqual(history.records().first?.useCount, 100)
    }

    func testRecentUseScoresHigherThanOldUse() {
        let store = SettingsStore(backend: InMemorySettingsBackend())
        let clock = MutableHistoryClock(Date(timeIntervalSince1970: 1_000_000))
        let history = PaletteHistoryStore(settings: store, now: { clock.now })
        history.recordSuccessfulAction(resultID: "old")
        clock.now = clock.now.addingTimeInterval(30 * 86_400)
        history.recordSuccessfulAction(resultID: "recent")
        XCTAssertGreaterThan(history.scores()["recent"] ?? 0, history.scores()["old"] ?? 0)
    }

    func testCorruptHistoryResetsOnlyHistory() {
        let store = SettingsStore(backend: InMemorySettingsBackend())
        store.setData(Data("broken".utf8), PaletteHistoryStore.key)
        let history = PaletteHistoryStore(settings: store)
        XCTAssertEqual(history.records(), [])
        XCTAssertNil(store.data(PaletteHistoryStore.key))
    }

    func testClearRemovesHistory() {
        let store = SettingsStore(backend: InMemorySettingsBackend())
        let history = PaletteHistoryStore(settings: store)
        history.recordSuccessfulAction(resultID: "one")
        history.clear()
        XCTAssertEqual(history.records(), [])
    }
}

private final class HistoryClock: @unchecked Sendable {
    private let lock = NSLock()
    private var value: TimeInterval = 1_000

    func next() -> Date {
        lock.withLock {
            value += 1
            return Date(timeIntervalSince1970: value)
        }
    }
}

private final class MutableHistoryClock: @unchecked Sendable {
    var now: Date
    init(_ now: Date) { self.now = now }
}
