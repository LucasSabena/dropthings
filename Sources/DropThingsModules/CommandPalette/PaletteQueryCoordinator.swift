import AppKit
import Combine
import Foundation
import os
import DropThingsCore
import DropThingsPlatform

public enum PaletteProviderID: String, CaseIterable, Sendable {
    case applications
    case commands
    case calculator
    case files
    case web

    public var displayName: String { rawValue.capitalized }
}

public struct PaletteProviderDiagnostic: Equatable, Sendable {
    public let provider: PaletteProviderID
    public let message: String
}

private struct LocalSearchSnapshot: Sendable {
    let ranked: [RankedPaletteResult]
    let staticResults: [PaletteResult]
}

@MainActor
public final class PaletteQueryCoordinator: ObservableObject {
    @Published public var query = "" {
        didSet { guard query != oldValue else { return }; scheduleSearch() }
    }
    @Published public private(set) var results: [RankedPaletteResult] = []
    @Published public private(set) var loadingProviders: Set<PaletteProviderID> = []
    @Published public private(set) var diagnostics: [PaletteProviderID: PaletteProviderDiagnostic] = [:]
    @Published public private(set) var actionError: String?

    public var settingsDidChange: (@MainActor (CommandPaletteSettings) -> Void)?

    public var availableApplications: [ApplicationRecord] {
        catalogApplications.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    public var availableBrowsers: [ApplicationRecord] {
        availableApplications.filter(Self.isBrowser)
    }

    public private(set) var settings: CommandPaletteSettings

    private let commandSource: @MainActor () -> [CommandDescriptor]
    private let applicationCatalog: any ApplicationCataloging
    private let spotlight: any SpotlightFileSearching
    private let workspace: PaletteWorkspace
    private let calculator: CalculatorEngine
    private let history: PaletteHistoryStore
    private var catalogApplications: [ApplicationRecord] = []
    private var applications: [ApplicationRecord] = []
    private var staticLocalResults: [PaletteResult] = []
    private var staticLocalResultsDirty = true
    private var localResults: [PaletteResult] = []
    private var fileResults: [PaletteResult] = []
    private var generation = 0
    private var localTask: Task<Void, Never>?
    private var fileTask: Task<Void, Never>?
    private var catalogTask: Task<Void, Never>?
    private let performanceLog = OSLog(subsystem: "app.dropthings", category: "command-palette-performance")

    public init(
        settings: CommandPaletteSettings,
        commandSource: @escaping @MainActor () -> [CommandDescriptor],
        applicationCatalog: any ApplicationCataloging,
        spotlight: any SpotlightFileSearching,
        workspace: PaletteWorkspace,
        calculator: CalculatorEngine = CalculatorEngine(),
        history: PaletteHistoryStore
    ) {
        self.settings = settings
        self.commandSource = commandSource
        self.applicationCatalog = applicationCatalog
        self.spotlight = spotlight
        self.workspace = workspace
        self.calculator = calculator
        self.history = history
    }

    deinit {
        localTask?.cancel()
        fileTask?.cancel()
        catalogTask?.cancel()
    }

    public func start() {
        loadApplicationCatalog()
        scheduleSearch(rebuildStaticResults: true)
    }

    public func stop() {
        generation += 1
        localTask?.cancel()
        fileTask?.cancel()
        catalogTask?.cancel()
        loadingProviders = []
        diagnostics = [:]
        actionError = nil
    }

    public func prepareForPresentation() {
        actionError = nil
        query = ""
        refreshLocalResults(generation: generation)
        loadApplicationCatalog()
    }

    public func clearActionError() {
        actionError = nil
    }

    public func updateSettings(_ settings: CommandPaletteSettings, refreshCatalog: Bool = false) {
        self.settings = settings
        if !settings.applicationsEnabled { diagnostics[.applications] = nil }
        if !settings.filesEnabled { diagnostics[.files] = nil }
        applyApplicationVisibility()
        staticLocalResultsDirty = true
        if refreshCatalog { loadApplicationCatalog(force: true) }
        else { scheduleSearch(rebuildStaticResults: true) }
    }

    @discardableResult
    public func execute(_ action: PaletteAction, for result: PaletteResult) async -> Bool {
        actionError = nil
        do {
            try await action.perform()
            if result.kind != .webSearch && result.kind != .systemSearch {
                history.recordSuccessfulAction(resultID: result.id)
            }
            return true
        } catch is CancellationError {
            return false
        } catch {
            actionError = error.localizedDescription
            return false
        }
    }

    public func clearHistory() {
        history.clear()
        scheduleSearch()
    }

    /// Re-reads module commands after the registry changes while the panel is
    /// visible, removing commands from modules that were just disabled.
    public func refreshCommands() {
        scheduleSearch(rebuildStaticResults: true)
    }

    public func refreshApplicationCatalog() {
        loadApplicationCatalog(force: true)
    }

    private func loadApplicationCatalog(force: Bool = false) {
        catalogTask?.cancel()
        catalogTask = Task { [weak self] in
            guard let self else { return }
            if force { await applicationCatalog.invalidate() }
            loadingProviders.insert(.applications)
            let locations = settings.applicationLocations.map { URL(fileURLWithPath: $0, isDirectory: true) }
            let records = await applicationCatalog.applications(in: locations)
            guard !Task.isCancelled else { return }
            let excludedApplicationPaths = settings.applicationExcludedPaths
            let visibleRecords = records.filter { record in
                !excludedApplicationPaths.contains { excluded in
                    let path = URL(fileURLWithPath: excluded).standardizedFileURL.path
                    return record.url.standardizedFileURL.path == path || record.url.standardizedFileURL.path.hasPrefix(path + "/")
                }
            }
            catalogApplications = visibleRecords
            applyApplicationVisibility()
            loadingProviders.remove(.applications)
            if !settings.applicationsEnabled {
                diagnostics[.applications] = nil
            } else if applications.isEmpty, settings.applicationVisibility == .selected, !visibleRecords.isEmpty {
                diagnostics[.applications] = PaletteProviderDiagnostic(
                    provider: .applications,
                    message: "No applications are selected. Choose apps in Command Palette settings."
                )
            } else if applications.isEmpty {
                diagnostics[.applications] = PaletteProviderDiagnostic(
                    provider: .applications,
                    message: "No launchable applications were found in the configured locations."
                )
            } else {
                diagnostics[.applications] = nil
            }
            scheduleSearch(rebuildStaticResults: true)
        }
    }

    private func applyApplicationVisibility() {
        guard settings.applicationVisibility == .selected else {
            applications = catalogApplications
            return
        }
        let selected = Set(settings.selectedApplicationIDs + settings.pinnedApplicationIDs)
        applications = catalogApplications.filter { selected.contains($0.id) }
    }

    private func scheduleSearch(rebuildStaticResults: Bool = false) {
        if rebuildStaticResults { staticLocalResultsDirty = true }
        generation += 1
        let currentGeneration = generation
        actionError = nil
        localTask?.cancel()
        fileTask?.cancel()
        fileResults = []
        refreshLocalResults(generation: currentGeneration)
        scheduleFileSearch(generation: currentGeneration)
    }

    private func refreshLocalResults(generation currentGeneration: Int) {
        let startedAt = DispatchTime.now().uptimeNanoseconds
        let query = query
        let settings = settings
        let apps = applications
        let commands = commandSource()
        let catalogApps = catalogApplications
        let historyScores = history.scores()
        let cachedStaticResults = staticLocalResults
        let shouldRebuildStaticResults = staticLocalResultsDirty
        let context = PaletteLocalProviderContext(
            query: query,
            settings: settings,
            applications: apps,
            catalogApplications: catalogApps,
            commands: commands,
            calculator: calculator,
            workspace: workspace,
            togglePinnedApplication: { [weak self] in self?.togglePinnedApplication($0) }
        )
        localTask = Task { [weak self] in
            let snapshot = await Task.detached(priority: .userInitiated) {
                let staticResults: [PaletteResult]
                if shouldRebuildStaticResults {
                    let staticProviders: [any PaletteLocalSearchProviding] = [
                        ApplicationPaletteProvider(), CommandResultProvider()
                    ]
                    staticResults = staticProviders.flatMap { $0.results(in: context) }
                } else {
                    staticResults = cachedStaticResults
                }
                let dynamicProviders: [any PaletteLocalSearchProviding] = [
                    CalculatorResultProvider(), WebResultProvider(), SystemSearchResultProvider()
                ]
                let built = staticResults + dynamicProviders.flatMap { $0.results(in: context) }
                let grouped = Dictionary(grouping: built, by: Self.provider(for:))
                let capped = grouped.values.flatMap {
                    PaletteRanker.rank(
                        $0,
                        query: query,
                        historyScores: historyScores,
                        limit: settings.maximumResultsPerProvider
                    ).map(\.result)
                }
                let ranked = PaletteRanker.rank(
                    capped,
                    query: query,
                    historyScores: historyScores,
                    limit: settings.maximumResultsPerProvider * 5
                )
                return LocalSearchSnapshot(ranked: ranked, staticResults: staticResults)
            }.value
            guard let self, !Task.isCancelled, currentGeneration == generation else { return }
            if shouldRebuildStaticResults {
                staticLocalResults = snapshot.staticResults
                staticLocalResultsDirty = false
            }
            localResults = snapshot.ranked.map(\.result)
            let elapsedMilliseconds = Double(DispatchTime.now().uptimeNanoseconds - startedAt) / 1_000_000
            os_signpost(
                .event,
                log: performanceLog,
                name: "Local Results",
                "generation=%{public}d count=%{public}d duration_ms=%{public}.3f",
                currentGeneration,
                snapshot.ranked.count,
                elapsedMilliseconds
            )
            publishMerged(query: query, historyScores: historyScores)
        }
    }

    private func scheduleFileSearch(generation currentGeneration: Int) {
        let startedAt = DispatchTime.now().uptimeNanoseconds
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard settings.filesEnabled, trimmed.count >= 2 else {
            loadingProviders.remove(.files)
            return
        }
        loadingProviders.insert(.files)
        let settings = settings
        fileTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(120))
                guard let self, !Task.isCancelled else { return }
                let records = try await spotlight.search(
                    query: trimmed,
                    includeContents: settings.fileContentSearchEnabled,
                    includeHidden: settings.includeHiddenFiles,
                    excludedPaths: settings.excludedPaths,
                    maximumResults: settings.maximumResultsPerProvider
                )
                guard !Task.isCancelled, currentGeneration == generation else { return }
                fileResults = await Task.detached(priority: .userInitiated) {
                    PaletteFileResultFactory.results(for: records, workspace: self.workspace)
                }.value
                let elapsedMilliseconds = Double(DispatchTime.now().uptimeNanoseconds - startedAt) / 1_000_000
                os_signpost(
                    .event,
                    log: performanceLog,
                    name: "Spotlight Results",
                    "generation=%{public}d count=%{public}d duration_ms=%{public}.3f",
                    currentGeneration,
                    records.count,
                    elapsedMilliseconds
                )
                diagnostics[.files] = nil
                loadingProviders.remove(.files)
                publishMerged(query: trimmed, historyScores: history.scores())
            } catch is CancellationError {
                if currentGeneration == self?.generation { self?.loadingProviders.remove(.files) }
            } catch {
                guard let self, currentGeneration == generation else { return }
                fileResults = []
                diagnostics[.files] = PaletteProviderDiagnostic(provider: .files, message: error.localizedDescription)
                loadingProviders.remove(.files)
                publishMerged(query: trimmed, historyScores: history.scores())
            }
        }
    }

    private func publishMerged(query: String, historyScores: [String: Double]) {
        var unique: [String: PaletteResult] = [:]
        for result in localResults + fileResults where unique[result.id] == nil { unique[result.id] = result }
        results = PaletteRanker.rank(
            Array(unique.values),
            query: query,
            historyScores: historyScores,
            limit: settings.maximumResultsPerProvider * 5
        )
    }

    nonisolated private static func provider(for result: PaletteResult) -> PaletteProviderID {
        switch result.kind {
        case .application: return .applications
        case .command, .systemAction: return .commands
        case .calculation: return .calculator
        case .file, .folder: return .files
        case .webSearch, .systemSearch: return .web
        }
    }

    private func togglePinnedApplication(_ id: String) {
        var updated = settings
        if let index = updated.pinnedApplicationIDs.firstIndex(of: id) {
            updated.pinnedApplicationIDs.remove(at: index)
        } else {
            updated.pinnedApplicationIDs.append(id)
        }
        settingsDidChange?(updated.sanitized())
    }

    nonisolated private static func isBrowser(_ application: ApplicationRecord) -> Bool {
        let knownBundleIDs: Set<String> = [
            "com.apple.Safari", "com.google.Chrome", "com.microsoft.edgemac",
            "org.mozilla.firefox", "com.brave.Browser", "company.thebrowser.Browser",
            "com.operasoftware.Opera", "com.vivaldi.Vivaldi"
        ]
        if let id = application.bundleIdentifier, knownBundleIDs.contains(id) { return true }
        let name = application.name.lowercased()
        return ["safari", "chrome", "edge", "firefox", "brave", "arc", "opera", "vivaldi"].contains { name.contains($0) }
    }

}
