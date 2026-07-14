import XCTest
@testable import DropThingsModules

final class CommandPaletteFilteringTests: XCTestCase {
    func testAccentAndCaseInsensitiveMatching() {
        let ranked = PaletteRanker.rank([result(id: "cafe", title: "Café")], query: "CAFE")
        XCTAssertEqual(ranked.map(\.id), ["cafe"])
    }

    func testTokenAndInitialMatching() {
        let results = [
            result(id: "settings", title: "System Settings"),
            result(id: "studio", title: "Screenshot Studio")
        ]
        XCTAssertEqual(PaletteRanker.rank(results, query: "sys set").first?.id, "settings")
        XCTAssertEqual(Set(PaletteRanker.rank(results, query: "ss").map(\.id)), Set(["settings", "studio"]))
    }

    func testFuzzyMatchingAndStableTieBreak() {
        let results = [result(id: "b", title: "Beta"), result(id: "a", title: "Alpha")]
        XCTAssertEqual(PaletteRanker.rank(results, query: "aa").map(\.id), ["a"])
        XCTAssertEqual(PaletteRanker.rank(results, query: "").map(\.id), ["a", "b"])
    }

    func testHistoryBoostIsBounded() {
        let results = [
            result(id: "prefix", title: "Notes", priority: 10),
            result(id: "history", title: "Notes Legacy", priority: 0)
        ]
        let ranked = PaletteRanker.rank(results, query: "notes", historyScores: ["history": 10_000])
        XCTAssertEqual(ranked.first?.id, "prefix", "History must not bury a stronger exact match")
        XCTAssertLessThan(ranked.last!.score, 1_100)
    }

    func testTenThousandLocalEntriesStayWithinInteractiveBudget() {
        let results = (0..<10_000).map { result(id: "app-\($0)", title: "Application \($0)") }
        measure {
            XCTAssertFalse(PaletteRanker.rank(results, query: "app 9999", limit: 30).isEmpty)
        }
    }

    private func result(id: String, title: String, priority: Double = 0) -> PaletteResult {
        PaletteResult(
            id: id,
            kind: .command,
            title: title,
            icon: .system("command"),
            providerPriority: priority,
            actions: []
        )
    }
}
