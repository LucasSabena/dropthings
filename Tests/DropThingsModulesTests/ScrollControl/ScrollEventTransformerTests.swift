import XCTest
@testable import DropThingsModules
import DropThingsPlatform

final class ScrollEventTransformerTests: XCTestCase {
    // MARK: - Classifier

    func testTrackpadHasPhase() {
        let input = ScrollEventInput(
            pointDeltaY: 4.2, pointDeltaX: 0,
            fixedDeltaY: 0, fixedDeltaX: 0,
            phase: 1, momentumPhase: 0
        )
        XCTAssertEqual(ScrollEventTransformer(settings: ScrollSettings()).classify(input), .trackpad)
    }

    func testMouseWheelHasOnlyFixedDelta() {
        let input = ScrollEventInput(
            pointDeltaY: 0, pointDeltaX: 0,
            fixedDeltaY: 1, fixedDeltaX: 0,
            phase: 0, momentumPhase: 0
        )
        XCTAssertEqual(ScrollEventTransformer(settings: ScrollSettings()).classify(input), .mouseWheel)
    }

    func testMagicMouseHasPointDeltaWithoutPhase() {
        let input = ScrollEventInput(
            pointDeltaY: 2.5, pointDeltaX: 0,
            fixedDeltaY: 0, fixedDeltaX: 0,
            phase: 0, momentumPhase: 0
        )
        XCTAssertEqual(ScrollEventTransformer(settings: ScrollSettings()).classify(input), .magicMouse)
    }

    func testUnknownEventIsEmpty() {
        XCTAssertEqual(ScrollEventTransformer(settings: ScrollSettings()).classify(.empty), .unknown)
    }

    // MARK: - Natural direction passes through

    func testNaturalTrackpadIsUntouched() {
        let input = ScrollEventInput(
            pointDeltaY: 7, pointDeltaX: 3,
            fixedDeltaY: 0, fixedDeltaX: 0,
            phase: 1, momentumPhase: 0
        )
        let settings = ScrollSettings(trackpadDirection: .natural)
        let decision = ScrollEventTransformer(settings: settings).transform(input)
        XCTAssertEqual(decision.pointDeltaY, 7)
        XCTAssertEqual(decision.pointDeltaX, 3)
        XCTAssertEqual(decision.deviceKind, .trackpad)
        XCTAssertFalse(decision.didMutate)
    }

    // MARK: - Inverted direction flips sign

    func testInvertedTrackpadFlipsBothAxes() {
        let input = ScrollEventInput(
            pointDeltaY: 10, pointDeltaX: 5,
            fixedDeltaY: 0, fixedDeltaX: 0,
            phase: 1, momentumPhase: 0
        )
        let settings = ScrollSettings(trackpadDirection: .inverted)
        let decision = ScrollEventTransformer(settings: settings).transform(input)
        XCTAssertEqual(decision.pointDeltaY, -10)
        XCTAssertEqual(decision.pointDeltaX, -5)
        XCTAssertTrue(decision.didMutate)
    }

    func testInvertedMouseWheelFlipsFixedDelta() {
        let input = ScrollEventInput(
            pointDeltaY: 0, pointDeltaX: 0,
            fixedDeltaY: 3, fixedDeltaX: -2,
            phase: 0, momentumPhase: 0
        )
        let settings = ScrollSettings(mouseWheelDirection: .inverted)
        let decision = ScrollEventTransformer(settings: settings).transform(input)
        XCTAssertEqual(decision.deviceKind, .mouseWheel)
        XCTAssertEqual(decision.fixedDeltaY, -3)
        XCTAssertEqual(decision.fixedDeltaX, 2)
    }

    // MARK: - Multiplier

    func testMultiplierScalesInvertedDelta() {
        let input = ScrollEventInput(
            pointDeltaY: 10, pointDeltaX: 0,
            fixedDeltaY: 0, fixedDeltaX: 0,
            phase: 1, momentumPhase: 0
        )
        let settings = ScrollSettings(
            trackpadDirection: .inverted,
            scrollMultiplier: 1.5
        )
        let decision = ScrollEventTransformer(settings: settings).transform(input)
        XCTAssertEqual(decision.pointDeltaY, -15.0, accuracy: 0.0001)
    }

    func testMultiplierIsClampedToBounds() {
        let settings = ScrollSettings.sanitized(
            trackpadDirection: .natural,
            mouseWheelDirection: .natural,
            magicMouseDirection: .natural,
            horizontalScrollEnabled: true,
            scrollMultiplier: 999,
            hotkey: nil
        )
        XCTAssertEqual(settings.scrollMultiplier, ScrollSettings.multiplierMax)

        let tooSmall = ScrollSettings.sanitized(
            trackpadDirection: .natural,
            mouseWheelDirection: .natural,
            magicMouseDirection: .natural,
            horizontalScrollEnabled: true,
            scrollMultiplier: -5,
            hotkey: nil
        )
        XCTAssertEqual(tooSmall.scrollMultiplier, ScrollSettings.multiplierMin)
    }

    // MARK: - Horizontal scroll toggle

    func testHorizontalDisabledZerosHorizontalAxis() {
        let input = ScrollEventInput(
            pointDeltaY: 5, pointDeltaX: 5,
            fixedDeltaY: 0, fixedDeltaX: 0,
            phase: 1, momentumPhase: 0
        )
        let settings = ScrollSettings(
            trackpadDirection: .inverted,
            horizontalScrollEnabled: false
        )
        let decision = ScrollEventTransformer(settings: settings).transform(input)
        XCTAssertEqual(decision.pointDeltaX, 0)
        XCTAssertEqual(decision.pointDeltaY, -5)
    }

    // MARK: - Per-category routing

    func testPerCategoryRouting() {
        let trackpad = ScrollEventInput(
            pointDeltaY: 1, pointDeltaX: 0,
            fixedDeltaY: 0, fixedDeltaX: 0,
            phase: 1, momentumPhase: 0
        )
        let wheel = ScrollEventInput(
            pointDeltaY: 0, pointDeltaX: 0,
            fixedDeltaY: 1, fixedDeltaX: 0,
            phase: 0, momentumPhase: 0
        )
        let settings = ScrollSettings(
            trackpadDirection: .natural,
            mouseWheelDirection: .inverted
        )
        let transformer = ScrollEventTransformer(settings: settings)
        XCTAssertFalse(transformer.transform(trackpad).didMutate)
        XCTAssertTrue(transformer.transform(wheel).didMutate)
    }
}
