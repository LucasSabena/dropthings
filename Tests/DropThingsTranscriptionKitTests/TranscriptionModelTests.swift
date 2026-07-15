import XCTest
@testable import DropThingsTranscriptionKit

final class TranscriptionModelTests: XCTestCase {
    func testCuratedManifestHasUniqueStableEntries() {
        XCTAssertEqual(Set(CuratedTranscriptionModels.all.map(\.id)).count, 3)
        for descriptor in CuratedTranscriptionModels.all {
            XCTAssertEqual(descriptor.sha256.count, 64)
            XCTAssertGreaterThan(descriptor.byteCount, 0)
            XCTAssertEqual(descriptor.downloadURL.scheme, "https")
        }
    }
}
