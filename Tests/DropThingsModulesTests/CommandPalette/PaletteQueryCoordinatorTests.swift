import XCTest
@testable import DropThingsCore
@testable import DropThingsModules
import DropThingsPlatform

final class PaletteQueryCoordinatorTests: XCTestCase {
    @MainActor
    func testLateFileGenerationNeverReplacesNewQuery() async throws {
        let coordinator = makeCoordinator(spotlight: DelayedSpotlight())
        coordinator.start()
        coordinator.query = "old"
        try await Task.sleep(for: .milliseconds(150))
        coordinator.query = "new"
        try await Task.sleep(for: .milliseconds(450))

        XCTAssertTrue(coordinator.results.contains(where: { $0.result.title == "new.txt" }))
        XCTAssertFalse(coordinator.results.contains(where: { $0.result.title == "old.txt" }))
    }

    @MainActor
    func testFailedSpotlightKeepsApplicationResultsAndReportsDiagnostic() async throws {
        let coordinator = makeCoordinator(spotlight: FailingSpotlight())
        coordinator.start()
        try await Task.sleep(for: .milliseconds(30))
        coordinator.query = "Sample"
        try await Task.sleep(for: .milliseconds(220))

        XCTAssertTrue(coordinator.results.contains(where: { $0.result.title == "Sample App" }))
        XCTAssertNotNil(coordinator.diagnostics[.files])
    }

    @MainActor
    func testPerProviderMaximumIsAppliedBeforeMerge() async throws {
        let store = SettingsStore(backend: InMemorySettingsBackend())
        let apps = (0..<20).map { index in
            ApplicationRecord(id: "app:\(index)", name: "App \(index)", bundleIdentifier: "app.\(index)", url: URL(fileURLWithPath: "/Applications/App\(index).app"))
        }
        let commands = (0..<20).map { index in
            CommandDescriptor(id: "command-\(index)", title: "Command \(index)", action: {})
        }
        let coordinator = PaletteQueryCoordinator(
            settings: CommandPaletteSettings(calculatorEnabled: false, filesEnabled: false, maximumResultsPerProvider: 5),
            commandSource: { commands },
            applicationCatalog: FakeApplicationCatalog(records: apps),
            spotlight: FailingSpotlight(),
            workspace: PaletteWorkspace(),
            history: PaletteHistoryStore(settings: store)
        )
        coordinator.start()
        try await Task.sleep(for: .milliseconds(80))

        XCTAssertLessThanOrEqual(coordinator.results.filter { $0.result.kind == .application }.count, 5)
        XCTAssertLessThanOrEqual(coordinator.results.filter { [.command, .systemAction].contains($0.result.kind) }.count, 5)
    }

    @MainActor
    func testApplicationPathExclusionIsApplied() async throws {
        let store = SettingsStore(backend: InMemorySettingsBackend())
        let coordinator = PaletteQueryCoordinator(
            settings: CommandPaletteSettings(commandsEnabled: false, calculatorEnabled: false, filesEnabled: false, applicationExcludedPaths: ["/Applications/Sample.app"]),
            commandSource: { [] },
            applicationCatalog: FakeApplicationCatalog(),
            spotlight: FailingSpotlight(),
            workspace: PaletteWorkspace(),
            history: PaletteHistoryStore(settings: store)
        )
        coordinator.start()
        try await Task.sleep(for: .milliseconds(80))
        XCTAssertFalse(coordinator.results.contains(where: { $0.result.title == "Sample App" }))
    }

    @MainActor
    func testPinnedApplicationComesFirstAndSelectedModeHidesOthers() async throws {
        let store = SettingsStore(backend: InMemorySettingsBackend())
        let apps = [
            ApplicationRecord(id: "app:one", name: "Alpha", bundleIdentifier: "app.one", url: URL(fileURLWithPath: "/Applications/Alpha.app")),
            ApplicationRecord(id: "app:two", name: "Beta", bundleIdentifier: "app.two", url: URL(fileURLWithPath: "/Applications/Beta.app")),
            ApplicationRecord(id: "app:three", name: "Gamma", bundleIdentifier: "app.three", url: URL(fileURLWithPath: "/Applications/Gamma.app"))
        ]
        let settings = CommandPaletteSettings(
            commandsEnabled: false,
            calculatorEnabled: false,
            filesEnabled: false,
            applicationVisibility: .selected,
            selectedApplicationIDs: ["app:one"],
            pinnedApplicationIDs: ["app:two"]
        )
        let coordinator = PaletteQueryCoordinator(
            settings: settings,
            commandSource: { [] },
            applicationCatalog: FakeApplicationCatalog(records: apps),
            spotlight: FailingSpotlight(),
            workspace: PaletteWorkspace(),
            history: PaletteHistoryStore(settings: store)
        )
        coordinator.start()
        try await Task.sleep(for: .milliseconds(80))

        XCTAssertEqual(coordinator.results.map(\.id), ["app:two", "app:one"])
        XCTAssertFalse(coordinator.results.contains(where: { $0.id == "app:three" }))
    }

    @MainActor
    func testWebSearchProviderIsOptInAndDoesNotPersistRawQuery() async throws {
        let store = SettingsStore(backend: InMemorySettingsBackend())
        let history = PaletteHistoryStore(settings: store)
        let coordinator = PaletteQueryCoordinator(
            settings: CommandPaletteSettings(applicationsEnabled: false, commandsEnabled: false, calculatorEnabled: false, filesEnabled: false, webSearchEnabled: true),
            commandSource: { [] },
            applicationCatalog: FakeApplicationCatalog(records: []),
            spotlight: FailingSpotlight(),
            workspace: PaletteWorkspace(),
            history: history
        )
        coordinator.start()
        coordinator.query = "private test query"
        try await Task.sleep(for: .milliseconds(40))
        let result = try XCTUnwrap(coordinator.results.first?.result)
        XCTAssertEqual(result.kind, .webSearch)
        let action = PaletteAction(id: "test", title: "Test", symbolName: "globe", role: .primary) {}
        let safeWebResult = PaletteResult(
            id: "web:raw-private-query",
            kind: .webSearch,
            title: "Search",
            icon: .system("globe"),
            providerPriority: 0,
            actions: [action]
        )
        let didExecute = await coordinator.execute(action, for: safeWebResult)
        XCTAssertTrue(didExecute)
        XCTAssertTrue(history.records().isEmpty)
    }

    @MainActor
    func testPresentationUsesCatalogCacheWithoutForcedInvalidation() async throws {
        let catalog = CountingApplicationCatalog()
        let store = SettingsStore(backend: InMemorySettingsBackend())
        let coordinator = PaletteQueryCoordinator(
            settings: CommandPaletteSettings(commandsEnabled: false, calculatorEnabled: false, filesEnabled: false),
            commandSource: { [] },
            applicationCatalog: catalog,
            spotlight: FailingSpotlight(),
            workspace: PaletteWorkspace(),
            history: PaletteHistoryStore(settings: store)
        )
        coordinator.start()
        try await Task.sleep(for: .milliseconds(50))
        coordinator.prepareForPresentation()
        try await Task.sleep(for: .milliseconds(50))

        let invalidationCount = await catalog.invalidationCount()
        let requestCount = await catalog.requestCount()
        XCTAssertEqual(invalidationCount, 0)
        XCTAssertGreaterThanOrEqual(requestCount, 1)
    }

    @MainActor
    func testExplicitCatalogRefreshInvalidatesBeforeRescan() async throws {
        let catalog = CountingApplicationCatalog()
        let store = SettingsStore(backend: InMemorySettingsBackend())
        let coordinator = PaletteQueryCoordinator(
            settings: CommandPaletteSettings(commandsEnabled: false, calculatorEnabled: false, filesEnabled: false),
            commandSource: { [] },
            applicationCatalog: catalog,
            spotlight: FailingSpotlight(),
            workspace: PaletteWorkspace(),
            history: PaletteHistoryStore(settings: store)
        )
        coordinator.start()
        try await Task.sleep(for: .milliseconds(40))
        coordinator.refreshApplicationCatalog()
        try await Task.sleep(for: .milliseconds(40))

        let invalidations = await catalog.invalidationCount()
        let requests = await catalog.requestCount()
        XCTAssertEqual(invalidations, 1)
        XCTAssertGreaterThanOrEqual(requests, 2)
    }

    @MainActor
    func testRefreshingCommandsRemovesCommandThatBecameUnavailable() async throws {
        let source = MutableCommandSource()
        let store = SettingsStore(backend: InMemorySettingsBackend())
        let coordinator = PaletteQueryCoordinator(
            settings: CommandPaletteSettings(applicationsEnabled: false, calculatorEnabled: false, filesEnabled: false),
            commandSource: { source.commands },
            applicationCatalog: FakeApplicationCatalog(records: []),
            spotlight: FailingSpotlight(),
            workspace: PaletteWorkspace(),
            history: PaletteHistoryStore(settings: store)
        )
        source.commands = [CommandDescriptor(id: "temporary", title: "Temporary", action: {})]
        coordinator.start()
        try await Task.sleep(for: .milliseconds(40))
        XCTAssertTrue(coordinator.results.contains(where: { $0.id == "command:temporary" }))

        source.commands = []
        coordinator.refreshCommands()
        try await Task.sleep(for: .milliseconds(40))
        XCTAssertFalse(coordinator.results.contains(where: { $0.id == "command:temporary" }))
    }

    @MainActor
    func testFailedActionStaysVisibleAndIsNotRecorded() async throws {
        let store = SettingsStore(backend: InMemorySettingsBackend())
        let history = PaletteHistoryStore(settings: store)
        let coordinator = PaletteQueryCoordinator(
            settings: CommandPaletteSettings(applicationsEnabled: false, commandsEnabled: false, calculatorEnabled: false, filesEnabled: false),
            commandSource: { [] },
            applicationCatalog: FakeApplicationCatalog(records: []),
            spotlight: FailingSpotlight(),
            workspace: PaletteWorkspace(),
            history: history
        )
        let action = PaletteAction(id: "fail", title: "Fail", symbolName: "xmark", role: .primary) {
            throw TestActionError.expected
        }
        let result = PaletteResult(
            id: "failed-result",
            kind: .command,
            title: "Failure",
            icon: .system("xmark"),
            providerPriority: 0,
            actions: [action]
        )

        let didExecute = await coordinator.execute(action, for: result)
        XCTAssertFalse(didExecute)
        XCTAssertNotNil(coordinator.actionError)
        XCTAssertTrue(history.records().isEmpty)
    }

    @MainActor
    func testDisablingFailedProviderClearsItsDiagnostic() async throws {
        let coordinator = makeCoordinator(spotlight: FailingSpotlight())
        coordinator.start()
        coordinator.query = "failure"
        try await Task.sleep(for: .milliseconds(180))
        XCTAssertNotNil(coordinator.diagnostics[.files])

        var updated = coordinator.settings
        updated.filesEnabled = false
        coordinator.updateSettings(updated)
        XCTAssertNil(coordinator.diagnostics[.files])
    }

    @MainActor
    private func makeCoordinator(spotlight: any SpotlightFileSearching) -> PaletteQueryCoordinator {
        let store = SettingsStore(backend: InMemorySettingsBackend())
        return PaletteQueryCoordinator(
            settings: CommandPaletteSettings(commandsEnabled: false, calculatorEnabled: false),
            commandSource: { [] },
            applicationCatalog: FakeApplicationCatalog(),
            spotlight: spotlight,
            workspace: PaletteWorkspace(),
            history: PaletteHistoryStore(settings: store)
        )
    }
}

@MainActor
private final class MutableCommandSource {
    var commands: [CommandDescriptor] = []
}

private enum TestActionError: LocalizedError {
    case expected
    var errorDescription: String? { "Expected action failure" }
}

private actor CountingApplicationCatalog: ApplicationCataloging {
    private var requests = 0
    private var invalidations = 0

    func applications(in additionalLocations: [URL]) async -> [ApplicationRecord] {
        requests += 1
        return []
    }

    func invalidate() async { invalidations += 1 }
    func requestCount() -> Int { requests }
    func invalidationCount() -> Int { invalidations }
}

private actor FakeApplicationCatalog: ApplicationCataloging {
    private let records: [ApplicationRecord]

    init(records: [ApplicationRecord] = [ApplicationRecord(
        id: "app:sample",
        name: "Sample App",
        bundleIdentifier: "example.sample",
        url: URL(fileURLWithPath: "/Applications/Sample.app")
    )]) {
        self.records = records
    }

    func applications(in additionalLocations: [URL]) async -> [ApplicationRecord] {
        records
    }

    func invalidate() async {}
}

@MainActor
private final class DelayedSpotlight: SpotlightFileSearching, @unchecked Sendable {
    func search(query: String, includeContents: Bool, includeHidden: Bool, excludedPaths: [String], maximumResults: Int) async throws -> [SpotlightFileRecord] {
        let delay: UInt64 = query == "old" ? 250_000_000 : 20_000_000
        await withCheckedContinuation { continuation in
            DispatchQueue.main.asyncAfter(deadline: .now() + .nanoseconds(Int(delay))) { continuation.resume() }
        }
        let url = URL(fileURLWithPath: "/tmp/\(query).txt")
        return [SpotlightFileRecord(id: "file:\(url.path)", url: url, name: "\(query).txt", parentPath: "/tmp", isDirectory: false, modifiedAt: nil, relevance: 0)]
    }
}

@MainActor
private final class FailingSpotlight: SpotlightFileSearching, @unchecked Sendable {
    func search(query: String, includeContents: Bool, includeHidden: Bool, excludedPaths: [String], maximumResults: Int) async throws -> [SpotlightFileRecord] {
        throw SpotlightFileSearchError.failed
    }
}
