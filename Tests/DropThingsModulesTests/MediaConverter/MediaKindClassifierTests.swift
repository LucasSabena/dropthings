import XCTest
import DropThingsMediaConverterKit
@testable import DropThingsModules

final class MediaKindClassifierTests: XCTestCase {
    func testContainersMissingFromLaunchServicesStillClassifyCorrectly() {
        XCTAssertEqual(MediaKindClassifier.kind(of: URL(fileURLWithPath: "/tmp/talk.opus")), .audio)
        XCTAssertEqual(MediaKindClassifier.kind(of: URL(fileURLWithPath: "/tmp/talk.ogg")), .audio)
        XCTAssertEqual(MediaKindClassifier.kind(of: URL(fileURLWithPath: "/tmp/capture.mkv")), .video)
        XCTAssertEqual(MediaKindClassifier.kind(of: URL(fileURLWithPath: "/tmp/capture.webm")), .video)
    }
}
