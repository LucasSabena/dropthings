import XCTest
@testable import DropThingsPlatform
import AppKit

final class ScreenCoordinateMapperTests: XCTestCase {
    func testSinglePrimaryDisplay() {
        // One screen at AppKit (0, 0) with size 1920x1080. CG bounds
        // match because primary is the reference.
        let screen = ScreenCoordinateMapper.Screen(
            appKitFrame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            cgBounds: CGRect(x: 0, y: 0, width: 1920, height: 1080)
        )
        let mapper = ScreenCoordinateMapper(
            screens: [screen],
            imageSize: screen.cgBounds.size
        )
        // Click at AppKit (100, 100) → image pixel (100, 1080 - 100) = (100, 980).
        XCTAssertEqual(
            mapper.imagePoint(forAppKitPoint: CGPoint(x: 100, y: 100)),
            CGPoint(x: 100, y: 980)
        )
        // Click at AppKit (1000, 540) → image pixel (1000, 540).
        XCTAssertEqual(
            mapper.imagePoint(forAppKitPoint: CGPoint(x: 1000, y: 540)),
            CGPoint(x: 1000, y: 540)
        )
    }

    func testSecondaryOnLeftOfPrimary() {
        // Primary at AppKit (0, 0, 1920, 1080), secondary at AppKit (-1920, 0, 1920, 1080).
        // CG layout: secondary at (0, 0, 1920, 1080), primary at (1920, 0, 1920, 1080).
        let secondary = ScreenCoordinateMapper.Screen(
            appKitFrame: CGRect(x: -1920, y: 0, width: 1920, height: 1080),
            cgBounds: CGRect(x: 0, y: 0, width: 1920, height: 1080)
        )
        let primary = ScreenCoordinateMapper.Screen(
            appKitFrame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            cgBounds: CGRect(x: 1920, y: 0, width: 1920, height: 1080)
        )
        let mapper = ScreenCoordinateMapper(
            screens: [secondary, primary],
            imageSize: CGSize(width: 3840, height: 1080)
        )
        // Click at AppKit (-500, 500) — middle of secondary.
        // local AppKit in secondary: (-500 - (-1920), 500) = (1420, 500).
        // CG y = 0 + (1080 - 500) = 580. CG x = 1420.
        // Image pixel (top-left origin): (1420, 580).
        XCTAssertEqual(
            mapper.imagePoint(forAppKitPoint: CGPoint(x: -500, y: 500)),
            CGPoint(x: 1420, y: 580)
        )
        // Click at AppKit (1500, 800) on primary, near right edge.
        // local AppKit in primary: (1500, 800).
        // CG: (1920 + 1500, 0 + (1080 - 800)) = (3420, 280).
        XCTAssertEqual(
            mapper.imagePoint(forAppKitPoint: CGPoint(x: 1500, y: 800)),
            CGPoint(x: 3420, y: 280)
        )
    }

    func testSecondaryAbovePrimary() {
        // AppKit's "above" means higher Y. The secondary's AppKit frame
        // is (0, 900, 1440, 900). Its CG frame is (0, 0, 1440, 900)
        // because CG is top-left origin. The primary's CG frame sits
        // below at (0, 900, 1440, 900).
        let primary = ScreenCoordinateMapper.Screen(
            appKitFrame: CGRect(x: 0, y: 0, width: 1440, height: 900),
            cgBounds: CGRect(x: 0, y: 900, width: 1440, height: 900)
        )
        let secondary = ScreenCoordinateMapper.Screen(
            appKitFrame: CGRect(x: 0, y: 900, width: 1440, height: 900),
            cgBounds: CGRect(x: 0, y: 0, width: 1440, height: 900)
        )
        let mapper = ScreenCoordinateMapper(
            screens: [primary, secondary],
            imageSize: CGSize(width: 1440, height: 1800)
        )
        // Click at AppKit (200, 1000) on secondary, near its top.
        // local AppKit in secondary: (200, 100). CG: (200, 0 + 800) = (200, 800).
        XCTAssertEqual(
            mapper.imagePoint(forAppKitPoint: CGPoint(x: 200, y: 1000)),
            CGPoint(x: 200, y: 800)
        )
        // Click at AppKit (700, 500) on primary, vertical center.
        // local AppKit in primary: (700, 500). CG: (700, 900 + 400) = (700, 1300).
        XCTAssertEqual(
            mapper.imagePoint(forAppKitPoint: CGPoint(x: 700, y: 500)),
            CGPoint(x: 700, y: 1300)
        )
    }

    func testPointOutsideAnyScreenFallsBackToZero() {
        let screen = ScreenCoordinateMapper.Screen(
            appKitFrame: CGRect(x: 0, y: 0, width: 1000, height: 1000),
            cgBounds: CGRect(x: 0, y: 0, width: 1000, height: 1000)
        )
        let mapper = ScreenCoordinateMapper(screens: [screen], imageSize: screen.cgBounds.size)
        XCTAssertEqual(
            mapper.imagePoint(forAppKitPoint: CGPoint(x: -5000, y: -5000)),
            CGPoint.zero
        )
    }

    func testUnionOfEmptyArrayIsZero() {
        XCTAssertEqual(
            ScreenCoordinateMapper.union(of: []),
            CGRect.zero
        )
    }

    func testUnionOfOneRectangleIsThatRectangle() {
        let r = CGRect(x: 10, y: 20, width: 100, height: 200)
        XCTAssertEqual(ScreenCoordinateMapper.union(of: [r]), r)
    }
}
