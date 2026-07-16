import CoreGraphics
import XCTest
import DropThingsMediaConverterKit
@testable import DropThingsPlatform

final class NativeMediaProbeTests: XCTestCase {
    func testDisplayDimensionsApplyPortraitVideoTransform() {
        let quarterTurn = CGAffineTransform(
            a: 0, b: 1,
            c: -1, d: 0,
            tx: 1080, ty: 0
        )

        let dimensions = NativeMediaProbe.displayDimensions(
            naturalSize: CGSize(width: 1920, height: 1080),
            transform: quarterTurn
        )

        XCTAssertEqual(dimensions, MediaDimensions(width: 1080, height: 1920))
    }
}
