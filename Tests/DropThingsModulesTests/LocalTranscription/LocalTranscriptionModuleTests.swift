import Foundation
import XCTest
import DropThingsCore
import DropThingsTranscriptionKit
@testable import DropThingsModules

private actor FakeLocalTranscriptionClient: LocalTranscriptionClient {
    let reportedAvailability: TranscriptionClientAvailability

    init(_ availability: TranscriptionClientAvailability) {
        reportedAvailability = availability
    }

    func availability() async -> TranscriptionClientAvailability { reportedAvailability }
    func transcribe(
        _ request: TranscriptionRequest,
        progress: @escaping @Sendable (TranscriptionProgress) -> Void
    ) async throws -> TranscriptDocument {
        throw TranscriptionClientError.helperFailed("Unused in lifecycle tests")
    }
    func cancel(jobID: UUID) async {}
}

@MainActor
final class LocalTranscriptionModuleTests: XCTestCase {
    func testStartReportsUnavailableHelperWithoutRequestingPermissions() async throws {
        let module = makeModule(client: FakeLocalTranscriptionClient(.unavailable(reason: "Helper missing")))

        try await module.start()

        XCTAssertEqual(module.requiredPermissions, [])
        XCTAssertEqual(module.state, .unavailable(reason: "Helper missing"))
    }

    func testAvailableHelperStartsAndStopReturnsOff() async throws {
        let module = makeModule(client: FakeLocalTranscriptionClient(.available(version: "test")))
        try await module.start()
        XCTAssertEqual(module.state, .running)

        await module.stop()

        XCTAssertEqual(module.state, .off)
    }

    func testStableModuleIdentityAndProposedSymbol() {
        let module = makeModule(client: FakeLocalTranscriptionClient(.available(version: "test")))
        XCTAssertEqual(module.id, .localTranscription)
        XCTAssertEqual(module.iconName, "waveform.and.mic")
        XCTAssertEqual(module.releaseStage, .beta)
    }

    private func makeModule(client: any LocalTranscriptionClient) -> LocalTranscriptionModule {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        return LocalTranscriptionModule(
            settings: SettingsStore(backend: InMemorySettingsBackend()),
            client: client,
            modelManager: TranscriptionModelManager(modelsDirectory: directory)
        )
    }
}
