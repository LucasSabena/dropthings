import Foundation
import SwiftUI
import AppKit
import DropThingsCore
import DropThingsDesignSystem
import DropThingsPlatform
import DropThingsMediaConverterKit

/// Media Converter: local batch conversion, resizing, compression and
/// optimization. Native ImageIO handles images and the isolated, bundled
/// FFmpeg helper handles supported audio and video formats.
public final class MediaConverterModule: DropThingsModule {
    public let id = ModuleID.mediaConverter
    public let name = "Media Converter"
    public let summary = "Convert, resize and compress images, audio and video locally."
    public let releaseStage: ModuleReleaseStage = .beta
    public let requiredPermissions: [SystemPermission] = []

    @Published public private(set) var state: ModuleState = .off
    @Published public private(set) var settings: MediaConverterSettings
    @Published public private(set) var ffmpegAvailable: Bool = false
    @Published public private(set) var ffmpegReason: String?

    public let queue = MediaConverterQueue()

    private let settingsStore: SettingsStore
    private let probeAdapter: MediaProbing
    private let imageEncoder: ImageEncoding
    private let securityScope: SecurityScoping
    private let diskSpace: DiskSpaceChecking
    private let ffmpegResolver: FFmpegResolving
    private let manifest: MediaCapabilityManifest
    private let engineClient: MediaConverterEngineClient?
    private let fileActionRegistry: FileActionRegistry?
    private var pipeline: MediaConverterPipeline?
    private lazy var windowController = MediaConverterWindowController(module: self)
    private var health = RecoverableFailureHealth()
    private let logger = ModuleLogger(subsystem: "app.dropthings", category: "media-converter")

    var canConvert: Bool { state.isActive && pipeline != nil }

    /// Production initializer. Uses the native backend adapters and the XPC
    /// helper client for audio/video.
    public init(settings: SettingsStore, fileActionRegistry: FileActionRegistry? = nil) {
        self.settingsStore = settings
        self.settings = settings.loadMediaConverterSettings()
        self.probeAdapter = NativeMediaProbe()
        self.imageEncoder = NativeImageEncoder()
        self.securityScope = SystemSecurityScope()
        self.diskSpace = SystemDiskSpace()
        self.ffmpegResolver = BundledFFmpegResolver()
        self.manifest = .shipped
        self.engineClient = XPCMediaConverterEngineClient()
        self.fileActionRegistry = fileActionRegistry
    }

    /// Test initializer with injected adapters.
    internal init(
        settings: SettingsStore,
        probeAdapter: MediaProbing,
        imageEncoder: ImageEncoding,
        securityScope: SecurityScoping,
        diskSpace: DiskSpaceChecking,
        ffmpegResolver: FFmpegResolving,
        engineClient: MediaConverterEngineClient? = nil,
        fileActionRegistry: FileActionRegistry? = nil,
        manifest: MediaCapabilityManifest = .shipped
    ) {
        self.settingsStore = settings
        self.settings = settings.loadMediaConverterSettings()
        self.probeAdapter = probeAdapter
        self.imageEncoder = imageEncoder
        self.securityScope = securityScope
        self.diskSpace = diskSpace
        self.ffmpegResolver = ffmpegResolver
        self.manifest = manifest
        self.engineClient = engineClient
        self.fileActionRegistry = fileActionRegistry
    }

    public func start() async throws {
        // Resolve FFmpeg availability up front so the capability manifest is
        // truthful about what the user can pick (stop-condition: "do not expose
        // a setting the chosen backend ignores").
        refreshFFmpegAvailability()
        if ffmpegAvailable, let engineClient {
            ffmpegAvailable = await engineClient.ffmpegIsAvailable()
            if !ffmpegAvailable {
                ffmpegReason = "The isolated media engine could not load its bundled FFmpeg tools."
            }
        }
        let config = MediaConverterPipeline.Configuration(
            manifest: manifest,
            ffmpegAvailable: ffmpegAvailable
        )
        pipeline = MediaConverterPipeline(
            configuration: config,
            probeAdapter: probeAdapter,
            imageEncoder: imageEncoder,
            securityScope: securityScope,
            diskSpace: diskSpace,
            engineClient: ffmpegAvailable ? engineClient : nil
        )
        state = .running
        publishFileActions()
        logger.info("Media Converter ready (ffmpeg=\(self.ffmpegAvailable))")
    }

    public func stop() async {
        fileActionRegistry?.unregisterProducer(id.rawValue)
        for item in queue.items where !item.phase.isTerminal {
            pipeline?.cancel(item.id)
            queue.setPhase(.cancelled, for: item.id)
        }
        engineClient?.invalidate()
        pipeline = nil
        windowController.hide()
        state = .off
        logger.info("Media Converter stopped")
    }

    // MARK: - Menu bar / Command Palette surface

    public var primaryAction: ModulePrimaryAction? {
        ModulePrimaryAction(
            title: "Open Media Converter",
            iconName: "arrow.triangle.2.circlepath",
            action: { [weak self] in
                Task { @MainActor in self?.openSurface() }
            }
        )
    }

    public var commands: [CommandDescriptor] {
        [
            CommandDescriptor(
                id: "media-converter.open",
                title: "Open Media Converter",
                subtitle: "Convert media locally",
                iconName: "arrow.triangle.2.circlepath",
                action: { [weak self] in
                    Task { @MainActor in self?.openSurface() }
                }
            )
        ]
    }

    private func openSurface() {
        windowController.show()
    }

    // MARK: - Conversion entry point

    /// Enqueue a set of sources for conversion with the given typed request
    /// template. Returns the IDs assigned to the new queue items.
    @discardableResult
    public func enqueueConversion(
        sources: [URL],
        requestTemplate: (URL) -> MediaConversionRequest
    ) -> [UUID] {
        let ids = queue.enqueue(sources)
        guard let pipeline else {
            for id in ids { queue.setPhase(.failed(reason: "Media Converter is not running."), for: id) }
            return ids
        }
        for (source, id) in zip(sources, ids) {
            let request = requestTemplate(source)
            Task { [weak pipeline, weak self] in
                guard let pipeline else { return }
                let result = await pipeline.run(request, jobID: id) { [weak self] phase in
                    Task { @MainActor [weak self] in
                        self?.queue.acceptPipelinePhase(phase, for: id)
                    }
                }
                if case .failure(let error) = result, error != .skippedExistingOutput {
                    self?.logger.warning("Conversion failed: \(error.diagnosticCategory)")
                }
            }
        }
        return ids
    }

    public func cancel(jobID: UUID) {
        queue.setPhase(.cancelled, for: jobID)
        pipeline?.cancel(jobID)
    }

    public func reject(sources: [URL], reason: String) {
        for id in queue.enqueue(sources) {
            queue.setPhase(.failed(reason: reason), for: id)
        }
    }

    // MARK: - Cross-module file actions

    /// Publish a "Convert with Media Converter" action so other surfaces
    /// (Smart Clipboard, Command Palette context) can hand files to this module
    /// without importing it. Actions vanish on stop (PRODUCT.md: "Actions
    /// disappear safely when a target module is disabled or absent").
    private func publishFileActions() {
        guard let fileActionRegistry else { return }
        let descriptor = FileActionRegistry.Descriptor(
            id: "\(id.rawValue).convert",
            title: "Convert with Media Converter",
            systemImage: "arrow.triangle.2.circlepath",
            producerID: id.rawValue,
            isAvailable: { { [weak self] in
                // `isAvailable` is called from main-actor consumers; hop there
                // to read module state safely.
                MainActor.assumeIsolated { self?.state.isActive ?? false }
            } }
        )
        let handler = FileActionRegistry.ActionHandler(
            id: "\(id.rawValue).convert",
            run: { [weak self] urls in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    let outputDir = self.settings.outputDirectory ?? urls.first?.deletingLastPathComponent() ?? URL(fileURLWithPath: NSTemporaryDirectory())
                    self.enqueueConversion(sources: urls) { source in
                        let kind = MediaKindClassifier.kind(of: source)
                        let format: MediaFormatID
                        switch kind {
                        case .image: format = .jpeg
                        case .audio: format = .m4aAAC
                        case .video: format = .mp4H264
                        }
                        return MediaConversionRequest(
                            source: source, outputDirectory: outputDir,
                            outputFormat: format, resize: .none,
                            noUpscale: self.settings.noUpscaleByDefault,
                            quality: 82, metadata: self.settings.metadata,
                            conflict: self.settings.conflict
                        )
                    }
                }
            }
        )
        fileActionRegistry.register(descriptor, handler: handler)
    }

    // MARK: - Settings mutations

    public func setDefaultPreset(_ preset: MediaPresetID) {
        var copy = settings
        copy.defaultPreset = preset
        applySettings(copy)
    }

    public func setConflict(_ policy: ConflictPolicy) {
        var copy = settings
        copy.conflict = policy
        applySettings(copy)
    }

    public func setMetadata(_ policy: MetadataPolicy) {
        var copy = settings
        copy.metadata = policy
        applySettings(copy)
    }

    public func setOutputDirectory(_ url: URL?) {
        var copy = settings
        copy.outputDirectory = url
        applySettings(copy)
    }

    public func setStartInAdvanced(_ enabled: Bool) {
        var copy = settings
        copy.startInAdvancedMode = enabled
        applySettings(copy)
    }

    public func setNoUpscaleDefault(_ enabled: Bool) {
        var copy = settings
        copy.noUpscaleByDefault = enabled
        applySettings(copy)
    }

    private func applySettings(_ new: MediaConverterSettings) {
        settings = new
        settingsStore.saveMediaConverterSettings(settings)
    }

    private func refreshFFmpegAvailability() {
        switch ffmpegResolver.resolve() {
        case .available:
            ffmpegAvailable = true
            ffmpegReason = nil
        case .unavailable(let reason):
            ffmpegAvailable = false
            ffmpegReason = reason
        }
    }

    public func makeSettingsView() -> AnyView {
        AnyView(MediaConverterSettingsView(module: self))
    }
}
