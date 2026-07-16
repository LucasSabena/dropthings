import AppKit
import Combine
import SwiftUI
import UniformTypeIdentifiers
import DropThingsCore
import DropThingsDesignSystem
import DropThingsPlatform
import DropThingsTranscriptionKit

@MainActor
public final class LocalTranscriptionModule: DropThingsModule {
    public let id = ModuleID.localTranscription
    public let name = "Local Transcription"
    public let summary = "Transcribe audio and video locally into timestamped text."
    public let releaseStage: ModuleReleaseStage = .beta
    public let requiredPermissions: [SystemPermission] = []

    @Published public private(set) var state: ModuleState = .off
    @Published public private(set) var settings: LocalTranscriptionSettings
    @Published public private(set) var queue: [TranscriptionQueueItem] = []
    @Published public private(set) var installedModels: Set<TranscriptionModelID> = []
    @Published public private(set) var modelOperation: TranscriptionModelID?
    @Published public private(set) var notice: String?
    @Published public private(set) var broadMediaAvailable = false

    private let settingsStore: SettingsStore
    private let client: any LocalTranscriptionClient
    private let modelManager: TranscriptionModelManager
    private let mediaNormalizer: TranscriptionMediaNormalizer
    private lazy var windowController = LocalTranscriptionWindowController(module: self)
    private var queueTask: Task<Void, Never>?
    private var modelTask: Task<Void, Never>?
    private var modelOperationToken: UUID?
    private var activeJobID: UUID?
    private let logger = ModuleLogger(subsystem: "app.dropthings", category: "local-transcription")

    var isProcessing: Bool { activeJobID != nil }
    var canProcess: Bool { state.isActive }
    var hasWaitingItems: Bool { queue.contains { $0.status == .waiting } }
    var hasFinishedItems: Bool {
        queue.contains {
            switch $0.status {
            case .completed, .failed, .cancelled: true
            case .waiting, .active: false
            }
        }
    }

    public init(
        settings: SettingsStore,
        client: (any LocalTranscriptionClient)? = nil,
        modelManager: TranscriptionModelManager? = nil,
        mediaNormalizer: TranscriptionMediaNormalizer? = nil
    ) {
        settingsStore = settings
        self.settings = settings.loadLocalTranscriptionSettings()
        self.client = client ?? XPCTranscriptionClient()
        self.modelManager = modelManager ?? TranscriptionModelManager()
        self.mediaNormalizer = mediaNormalizer ?? TranscriptionMediaNormalizer()
    }

    public var primaryAction: ModulePrimaryAction? {
        ModulePrimaryAction(title: "Open Local Transcription", iconName: iconName) { [weak self] in
            Task { @MainActor in self?.openWorkspace() }
        }
    }

    public var commands: [CommandDescriptor] {
        [CommandDescriptor(
            id: "local-transcription.open",
            title: "Open Local Transcription",
            subtitle: "Transcribe audio or video offline",
            iconName: iconName
        ) { [weak self] in
            Task { @MainActor in self?.openWorkspace() }
        }]
    }

    public func start() async throws {
        guard state != .running else { return }
        installedModels = await modelManager.installedModelIDs()
        broadMediaAvailable = await mediaNormalizer.isAvailable()
        switch await client.availability() {
        case .available:
            state = .running
        case .unavailable(let reason):
            state = .unavailable(reason: reason)
        }
    }

    public func stop() async {
        queueTask?.cancel()
        modelOperationToken = nil
        modelTask?.cancel()
        if let activeJobID {
            await client.cancel(jobID: activeJobID)
            await mediaNormalizer.cancel(jobID: activeJobID)
        }
        queueTask = nil
        modelTask = nil
        modelOperation = nil
        activeJobID = nil
        windowController.hide()
        state = .off
    }

    public func makeSettingsView() -> AnyView {
        AnyView(LocalTranscriptionSettingsView(module: self))
    }

    public func openWorkspace() {
        windowController.show()
    }

    public func chooseAudioFiles() {
        let panel = NSOpenPanel()
        panel.title = "Choose Audio or Video"
        // Do not gate by extension: FFmpeg supports many containers/codecs
        // that Launch Services reports as generic data. Intake stays broad and
        // the isolated decoder returns a precise error for non-media files.
        panel.allowedContentTypes = [.item]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK else { return }
        addFiles(panel.urls)
    }

    public func addFiles(_ urls: [URL]) {
        let existing = Set(queue.map(\.sourceURL))
        let additions = urls.filter { !existing.contains($0) }.map { TranscriptionQueueItem(sourceURL: $0) }
        queue.append(contentsOf: additions)
        notice = nil
    }

    public func removeQueueItem(id: UUID) {
        guard activeJobID != id else { return }
        queue.removeAll { $0.id == id }
    }

    public func clearFinished() {
        queue.removeAll {
            switch $0.status {
            case .completed, .failed, .cancelled: true
            case .waiting, .active: false
            }
        }
    }

    public func retryQueueItem(id: UUID) {
        guard let index = queue.firstIndex(where: { $0.id == id }) else { return }
        switch queue[index].status {
        case .failed, .cancelled:
            queue[index].status = .waiting
            notice = nil
        case .waiting, .active, .completed:
            break
        }
    }

    public func startQueue() {
        guard queueTask == nil else { return }
        guard canProcess else {
            notice = "Enable Local Transcription before starting the queue."
            return
        }
        guard installedModels.contains(settings.selectedModel) else {
            notice = "Install the selected model before starting the queue."
            return
        }
        queueTask = Task { [weak self] in
            await self?.runQueue()
        }
    }

    public func cancelActiveJob() {
        guard let activeJobID else { return }
        queueTask?.cancel()
        Task {
            await client.cancel(jobID: activeJobID)
            await mediaNormalizer.cancel(jobID: activeJobID)
        }
    }

    public func updateSettings(_ mutate: (inout LocalTranscriptionSettings) -> Void) {
        mutate(&settings)
        settings.sanitize()
        settingsStore.saveLocalTranscriptionSettings(settings)
    }

    public func downloadModel(_ id: TranscriptionModelID) {
        guard modelOperation == nil else { return }
        let operationToken = UUID()
        modelOperationToken = operationToken
        modelOperation = id
        notice = "Downloading \(CuratedTranscriptionModels.descriptor(for: id).displayName)… Audio is not uploaded."
        modelTask = Task {
            do {
                try await modelManager.download(id)
                guard modelOperationToken == operationToken else { return }
                installedModels = await modelManager.installedModelIDs()
                guard modelOperationToken == operationToken else { return }
                notice = "The model was downloaded and verified."
            } catch {
                guard modelOperationToken == operationToken else { return }
                notice = error.localizedDescription
            }
            guard modelOperationToken == operationToken else { return }
            modelOperationToken = nil
            modelOperation = nil
            modelTask = nil
        }
    }

    public func importModel(_ id: TranscriptionModelID) {
        guard modelOperation == nil else { return }
        let panel = NSOpenPanel()
        panel.title = "Import Verified \(CuratedTranscriptionModels.descriptor(for: id).displayName) Model"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let source = panel.url else { return }
        let operationToken = UUID()
        modelOperationToken = operationToken
        modelOperation = id
        modelTask = Task {
            do {
                try await modelManager.importModel(from: source, as: id)
                guard modelOperationToken == operationToken else { return }
                installedModels = await modelManager.installedModelIDs()
                guard modelOperationToken == operationToken else { return }
                notice = "The imported model was verified."
            } catch {
                guard modelOperationToken == operationToken else { return }
                notice = error.localizedDescription
            }
            guard modelOperationToken == operationToken else { return }
            modelOperationToken = nil
            modelOperation = nil
            modelTask = nil
        }
    }

    public func deleteModel(_ id: TranscriptionModelID) {
        guard modelOperation == nil else { return }
        let operationToken = UUID()
        modelOperationToken = operationToken
        modelOperation = id
        modelTask = Task {
            do {
                try await modelManager.delete(id)
                guard modelOperationToken == operationToken else { return }
                installedModels = await modelManager.installedModelIDs()
                guard modelOperationToken == operationToken else { return }
                notice = "The model was removed."
            } catch {
                guard modelOperationToken == operationToken else { return }
                notice = error.localizedDescription
            }
            guard modelOperationToken == operationToken else { return }
            modelOperationToken = nil
            modelOperation = nil
            modelTask = nil
        }
    }

    private func runQueue() async {
        defer {
            activeJobID = nil
            queueTask = nil
        }
        while let item = queue.first(where: { $0.status == .waiting }) {
            if Task.isCancelled { break }
            activeJobID = item.id
            setStatus(.active(.init(phase: .inspect)), for: item.id)
            do {
                let snapshot = settings
                let outputs = try await process(item, settings: snapshot)
                setStatus(.completed(outputURLs: outputs), for: item.id)
                logger.notice("Transcription job \(item.id.uuidString) completed")
            } catch is CancellationError {
                setStatus(.cancelled, for: item.id)
            } catch TranscriptionClientError.cancelled {
                setStatus(.cancelled, for: item.id)
            } catch {
                setStatus(.failed(message: error.localizedDescription), for: item.id)
                logger.error("Transcription job \(item.id.uuidString) failed with \(String(describing: type(of: error)))")
            }
            activeJobID = nil
        }
    }

    private func process(
        _ item: TranscriptionQueueItem,
        settings snapshot: LocalTranscriptionSettings
    ) async throws -> [URL] {
        let modelID = snapshot.selectedModel
        let transcriptionInput: URL
        do {
            _ = try WAVInspector.inspect(url: item.sourceURL)
            transcriptionInput = item.sourceURL
        } catch {
            guard broadMediaAvailable else {
                throw TranscriptionClientError.invalidRequest(
                    "This file needs the bundled media decoder. Rebuild or reinstall DropThings with FFmpeg included."
                )
            }
            setStatus(.active(.init(phase: .normalize)), for: item.id)
            transcriptionInput = try await mediaNormalizer.normalize(source: item.sourceURL, jobID: item.id)
        }
        defer { mediaNormalizer.removeTemporaryFiles(for: item.id) }
        let modelURL = try await modelManager.acquire(modelID)
        do {
            let request = TranscriptionRequest(
                jobID: item.id,
                inputURL: transcriptionInput,
                modelURL: modelURL,
                language: snapshot.language,
                mode: snapshot.mode,
                initialPrompt: snapshot.initialPrompt
            )
            let document = try await client.transcribe(request) { [weak self] progress in
                Task { @MainActor in self?.setProgress(progress, for: item.id) }
            }
            try Task.checkCancellation()
            await modelManager.release(modelID)
            let outputDirectory = item.sourceURL.deletingLastPathComponent()
            let baseName = item.sourceURL.deletingPathExtension().lastPathComponent + " Transcript"
            return try TranscriptExporter.writeUnique(
                document,
                formats: snapshot.outputFormats,
                directory: outputDirectory,
                baseName: baseName
            )
        } catch {
            await modelManager.release(modelID)
            throw error
        }
    }

    private func setStatus(_ status: TranscriptionQueueItem.Status, for id: UUID) {
        guard let index = queue.firstIndex(where: { $0.id == id }) else { return }
        queue[index].status = status
    }

    private func setProgress(_ progress: TranscriptionProgress, for id: UUID) {
        guard activeJobID == id,
              let index = queue.firstIndex(where: { $0.id == id }) else { return }
        switch queue[index].status {
        case .waiting, .active:
            queue[index].status = .active(progress)
        case .completed, .failed, .cancelled:
            break
        }
    }

}
