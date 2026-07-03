import XCTest
import UniformTypeIdentifiers
@testable import DropThingsModules
import DropThingsPlatform

@MainActor
final class ShelfIngestCoordinatorTests: XCTestCase {

    func testFileURLCandidateBecomesFileItem() async {
        let coordinator = makeCoordinator()
        let outcome = await coordinator.resolve(.fileURL(URL(fileURLWithPath: "/tmp/a.txt"))) { _ in }
        if case .item(let kind) = outcome {
            if case .file(let url) = kind {
                XCTAssertEqual(url.path, "/tmp/a.txt")
            } else {
                XCTFail("expected .file, got \(kind)")
            }
        } else {
            XCTFail("expected .item, got \(outcome)")
        }
    }

    func testTextCandidateBecomesTextItem() async {
        let coordinator = makeCoordinator()
        let outcome = await coordinator.resolve(.text("hello")) { _ in }
        if case .item(let kind) = outcome, case .text(let s) = kind {
            XCTAssertEqual(s, "hello")
        } else {
            XCTFail("expected .item(.text), got \(outcome)")
        }
    }

    func testWebURLCandidateIsDownloadedThenFileItem() async {
        let fake = FakeDownloader(result: .saved(URL(fileURLWithPath: "/tmp/Dropthings/cat.png")))
        let coordinator = ShelfIngestCoordinator(downloader: fake, imageSaver: FakeImageSaver())
        let outcome = await coordinator.resolve(.webURL(URL(string: "https://ex.com/cat.png")!)) { _ in }
        XCTAssertEqual(fake.recordedURLs.map(\.absoluteString), ["https://ex.com/cat.png"])
        if case .item(let kind) = outcome, case .file(let url) = kind {
            XCTAssertEqual(url.lastPathComponent, "cat.png")
        } else {
            XCTFail("expected downloaded .file, got \(outcome)")
        }
    }

    func testWebURLFailureSurfacesError() async {
        let fake = FakeDownloader(result: .failed(.nonImageStatus(404)))
        let coordinator = ShelfIngestCoordinator(downloader: fake, imageSaver: FakeImageSaver())
        let outcome = await coordinator.resolve(.webURL(URL(string: "https://ex.com/x")!)) { _ in }
        if case .failed(_, let error) = outcome {
            XCTAssertEqual(error, .nonImageStatus(404))
        } else {
            XCTFail("expected .failed, got \(outcome)")
        }
    }

    func testImageCandidateIsSavedThenFileItem() async {
        let saver = FakeImageSaver(saved: URL(fileURLWithPath: "/tmp/Dropthings/Image.png"))
        let coordinator = ShelfIngestCoordinator(downloader: FakeDownloader(result: .saved(URL(fileURLWithPath: "/x"))), imageSaver: saver)
        let outcome = await coordinator.resolve(.image(Data([0x89, 0x50]), .png)) { _ in }
        XCTAssertEqual(saver.recordedTypes, [.png])
        if case .item(let kind) = outcome, case .file(let url) = kind {
            XCTAssertEqual(url.lastPathComponent, "Image.png")
        } else {
            XCTFail("expected saved .file, got \(outcome)")
        }
    }

    // MARK: - filename de-duplication (WebItemDownloader.resolveDestination)

    func testDownloaderNamesFromLastPathComponent() {
        let dir = makeTempDir()
        let downloader = WebItemDownloader(directory: dir)
        let dest = downloader.resolveDestination(for: URL(string: "https://ex.com/path/logo.svg")!)
        XCTAssertEqual(dest.lastPathComponent, "logo.svg")
    }

    func testDownloaderAddsExtensionWhenMissing() {
        let dir = makeTempDir()
        let downloader = WebItemDownloader(directory: dir)
        // A URL with no extension on the last component.
        let dest = downloader.resolveDestination(for: URL(string: "https://ex.com/noext")!)
        XCTAssertEqual(dest.lastPathComponent, "noext.bin")
    }

    func testDownloaderDeDuplicatesCollisions() throws {
        let dir = makeTempDir()
        // Pre-create a file to collide with.
        try Data("x".utf8).write(to: dir.appendingPathComponent("logo.svg"))
        let downloader = WebItemDownloader(directory: dir)
        let dest = downloader.resolveDestination(for: URL(string: "https://ex.com/logo.svg")!)
        XCTAssertEqual(dest.lastPathComponent, "logo 2.svg")
    }

    // MARK: - fakes & helpers

    private func makeCoordinator() -> ShelfIngestCoordinator {
        ShelfIngestCoordinator(downloader: FakeDownloader(result: .saved(URL(fileURLWithPath: "/x"))), imageSaver: FakeImageSaver())
    }

    private func makeTempDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("dropthings-ingest-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}

@MainActor
final class FakeDownloader: WebItemDownloading {
    let result: WebDownloadResult
    private(set) var recordedURLs: [URL] = []
    init(result: WebDownloadResult) { self.result = result }
    func download(_ remote: URL, progress: @escaping @MainActor (Double) -> Void) async -> WebDownloadResult {
        recordedURLs.append(remote)
        return result
    }
}

@MainActor
final class FakeImageSaver: ImageSaverProtocol {
    let saved: URL
    private(set) var recordedTypes: [UTType] = []
    init(saved: URL = URL(fileURLWithPath: "/tmp/Dropthings/Image.png")) { self.saved = saved }
    func save(data: Data, type: UTType) async throws -> URL {
        recordedTypes.append(type)
        return saved
    }
}
