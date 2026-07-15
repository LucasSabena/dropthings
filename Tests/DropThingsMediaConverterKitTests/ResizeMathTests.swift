import XCTest
@testable import DropThingsMediaConverterKit

final class ResizeMathTests: XCTestCase {

    func testMaxEdgeScalesDownPreservingAspect() {
        let src = MediaDimensions(width: 4000, height: 2000)
        let out = ResizeMath.targetDimensions(source: src, policy: .maxEdge(maxEdge: 1600), noUpscale: false)
        XCTAssertEqual(out, MediaDimensions(width: 1600, height: 800))
    }

    func testNoUpscaleClampsMaxEdge() {
        let src = MediaDimensions(width: 200, height: 100)
        let out = ResizeMath.targetDimensions(source: src, policy: .maxEdge(maxEdge: 1600), noUpscale: true)
        XCTAssertEqual(out, src, "noUpscale must not enlarge")
    }

    func testPercentageScales() {
        let src = MediaDimensions(width: 1000, height: 500)
        let out = ResizeMath.targetDimensions(source: src, policy: .percentage(percent: 50), noUpscale: false)
        XCTAssertEqual(out, MediaDimensions(width: 500, height: 250))
    }

    func testExactFitKeepsAspect() {
        let src = MediaDimensions(width: 1000, height: 500) // 2:1
        let out = ResizeMath.targetDimensions(source: src, policy: .exact(width: 200, height: 200, mode: .fit), noUpscale: false)
        // Fit inside 200x200: width-limited -> 200x100
        XCTAssertEqual(out, MediaDimensions(width: 200, height: 100))
    }

    func testExactFillKeepsAspect() {
        let src = MediaDimensions(width: 1000, height: 500) // 2:1
        let out = ResizeMath.targetDimensions(source: src, policy: .exact(width: 200, height: 200, mode: .fill), noUpscale: false)
        // Cover 200x200: height-limited -> 400x200 then crop; dimensions report the scaled box
        XCTAssertEqual(out, MediaDimensions(width: 400, height: 200))
    }

    func testExactStretchIgnoresAspect() {
        let src = MediaDimensions(width: 1000, height: 500)
        let out = ResizeMath.targetDimensions(source: src, policy: .exact(width: 300, height: 100, mode: .stretch), noUpscale: false)
        XCTAssertEqual(out, MediaDimensions(width: 300, height: 100))
    }

    func testNoneReturnsSource() {
        let src = MediaDimensions(width: 800, height: 600)
        let out = ResizeMath.targetDimensions(source: src, policy: .none, noUpscale: true)
        XCTAssertEqual(out, src)
    }

    func testEmptySourceReturnsNil() {
        XCTAssertNil(ResizeMath.targetDimensions(source: MediaDimensions(width: 0, height: 0), policy: .none, noUpscale: false))
    }

    func testZeroEdgeReturnsNil() {
        XCTAssertNil(ResizeMath.targetDimensions(source: MediaDimensions(width: 100, height: 100), policy: .maxEdge(maxEdge: 0), noUpscale: false))
    }
}
