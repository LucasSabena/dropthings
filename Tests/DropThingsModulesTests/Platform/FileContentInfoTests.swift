import XCTest
@testable import DropThingsPlatform

final class FileContentInfoTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    func testClassifiesFolder() {
        XCTAssertEqual(FileContentInfo.inspect(directory).kind, .folder)
    }

    func testClassifiesVideoFromType() throws {
        let movie = directory.appendingPathComponent("clip.mov")
        try Data().write(to: movie)
        XCTAssertEqual(FileContentInfo.inspect(movie).kind, .video)
    }

    func testClassifiesImageFromType() throws {
        let image = directory.appendingPathComponent("preview.png")
        try Data().write(to: image)
        XCTAssertEqual(FileContentInfo.inspect(image).kind, .image)
    }
}
