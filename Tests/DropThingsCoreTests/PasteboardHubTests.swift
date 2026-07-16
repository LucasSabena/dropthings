import XCTest
@testable import DropThingsCore

@MainActor
final class PasteboardHubTests: XCTestCase {
    private func makeSnapshot(changeCount: Int = 1, text: String? = "hello") -> PasteboardHub.Snapshot {
        PasteboardHub.Snapshot(
            changeCount: changeCount,
            text: text,
            url: nil,
            fileURLs: [],
            imageData: nil,
            colorHex: nil,
            isTransient: false,
            isConcealed: false,
            sourceBundleID: nil
        )
    }

    func testSubscribeReceivesSnapshots() {
        let backend = FakePasteboardBackend()
        let hub = PasteboardHub(backend: backend)
        hub.start()

        var received: [PasteboardHub.Snapshot] = []
        let subscription = hub.subscribe(origin: .init("consumer")) { snapshot in
            received.append(snapshot)
        }
        backend.emit(makeSnapshot(changeCount: 1))
        backend.emit(makeSnapshot(changeCount: 2, text: "world"))

        XCTAssertEqual(received.count, 2)
        XCTAssertEqual(received.first?.text, "hello")
        XCTAssertEqual(received.last?.text, "world")

        subscription.cancel()
    }

    func testCancelStopsDelivery() {
        let backend = FakePasteboardBackend()
        let hub = PasteboardHub(backend: backend)
        hub.start()
        var count = 0
        let subscription = hub.subscribe(origin: .init("consumer")) { _ in count += 1 }

        backend.emit(makeSnapshot())
        subscription.cancel()
        backend.emit(makeSnapshot())

        XCTAssertEqual(count, 1)
        XCTAssertFalse(backend.isRunning)
    }

    func testObserverKeepsRunningUntilLastSubscriberCancels() {
        let backend = FakePasteboardBackend()
        let hub = PasteboardHub(backend: backend)
        let first = hub.subscribe(origin: .init("first")) { _ in }
        let second = hub.subscribe(origin: .init("second")) { _ in }
        hub.start()

        first.cancel()
        XCTAssertTrue(backend.isRunning)

        second.cancel()
        XCTAssertFalse(backend.isRunning)
    }

    func testOriginSuppressionDropsEchoForAuthoringSubscriber() {
        let backend = FakePasteboardBackend()
        let hub = PasteboardHub(backend: backend)
        hub.start()
        let historyOrigin = PasteboardHub.OriginToken("history")
        let smartOrigin = PasteboardHub.OriginToken("smart")

        var historyReceived = 0
        var smartReceived = 0
        _ = hub.subscribe(origin: historyOrigin) { _ in historyReceived += 1 }
        _ = hub.subscribe(origin: smartOrigin) { _ in smartReceived += 1 }

        // History authors a write: hub records its origin before the poll.
        hub.recordWrite(origin: historyOrigin)
        backend.emit(makeSnapshot())

        // History must not see its own echo; Smart Clipboard still sees it.
        XCTAssertEqual(historyReceived, 0)
        XCTAssertEqual(smartReceived, 1)

        // Next external change is delivered to both, origin cleared.
        backend.emit(makeSnapshot())
        XCTAssertEqual(historyReceived, 1)
        XCTAssertEqual(smartReceived, 2)
    }

    func testStartIsIdempotent() {
        let backend = FakePasteboardBackend()
        let hub = PasteboardHub(backend: backend)
        hub.start()
        hub.start()
        XCTAssertTrue(backend.isRunning)
        hub.stop()
        XCTAssertFalse(backend.isRunning)
    }

    func testOverrideLatestUpdatesSnapshotWithoutDispatch() {
        let backend = FakePasteboardBackend()
        let hub = PasteboardHub(backend: backend)
        hub.start()
        var received = 0
        _ = hub.subscribe(origin: .init("consumer")) { _ in received += 1 }

        hub.overrideLatest(makeSnapshot(changeCount: 99, text: "manual"))
        XCTAssertEqual(hub.latestSnapshot?.text, "manual")
        XCTAssertEqual(hub.latestSnapshot?.changeCount, 99)
        // overrideLatest must NOT dispatch; subscribers are not called.
        XCTAssertEqual(received, 0)
    }
}
