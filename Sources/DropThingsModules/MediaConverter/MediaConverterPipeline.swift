import Foundation
import DropThingsCore
import DropThingsMediaConverterKit
import DropThingsPlatform

/// Runs a single conversion job through the full pipeline:
///
/// `intake → security scope → probe → preset validation → conflict/disk
/// preflight → encode → re-probe → finalize → result → cleanup`
///
/// Off the main actor: long work runs here, progress reports are throttled by
/// the queue. Cancellation is explicit and idempotent; cleanup only touches
/// resources provably owned by this job (ARCHITECTURE.md).
public actor MediaConverterPipeline {
    public struct Configuration: Sendable {
        public let manifest: MediaCapabilityManifest
        public let ffmpegAvailable: Bool
        public init(manifest: MediaCapabilityManifest = .shipped, ffmpegAvailable: Bool) {
            self.manifest = manifest
            self.ffmpegAvailable = ffmpegAvailable
        }
    }

    private let probeAdapter: MediaProbing
    private let imageEncoder: ImageEncoding
    private let securityScope: SecurityScoping
    private let diskSpace: DiskSpaceChecking
    private let configuration: Configuration
    /// XPC client for the isolated FFmpeg helper. `nil` when audio/video are
    /// unavailable (helper missing or FFmpeg not packaged); audio/video
    /// requests then fail with a typed error rather than silently no-op'ing.
    private let engineClient: MediaConverterEngineClient?
    private let logger = ModuleLogger(subsystem: "app.dropthings", category: "media-converter.pipeline")

    /// Cancellation flags keyed by job id. An actor-protected dictionary keeps
    /// cancellation explicit and avoids a global mutable flag.
    private var cancelled: Set<UUID> = []

    public init(
        configuration: Configuration,
        probeAdapter: MediaProbing,
        imageEncoder: ImageEncoding,
        securityScope: SecurityScoping,
        diskSpace: DiskSpaceChecking,
        engineClient: MediaConverterEngineClient? = nil
    ) {
        self.configuration = configuration
        self.probeAdapter = probeAdapter
        self.imageEncoder = imageEncoder
        self.securityScope = securityScope
        self.diskSpace = diskSpace
        self.engineClient = engineClient
    }

    /// Run one job. `onPhase` is invoked on the main actor (the queue passes
    /// its bound closure) so the UI updates without the pipeline knowing SwiftUI.
    public func run(
        _ request: MediaConversionRequest,
        jobID: UUID,
        onPhase: @escaping @Sendable (MediaItemPhase) -> Void
    ) async -> Result<URL, MediaConverterError> {
        defer { cancelled.remove(jobID) }
        onPhase(.pending)

        // 1. Security scope.
        let accessing = securityScope.startAccessing(request.source)
        defer {
            if accessing { securityScope.endAccess(request.source) }
        }

        // 2. Probe.
        if isCancelled(jobID) { onPhase(.cancelled); return .failure(.cancelled) }
        onPhase(.probing)
        let probe: MediaProbeResult
        switch await inspectMedia(url: request.source) {
        case .success(let result): probe = result
        case .failure(let error): onPhase(.failed(reason: error.errorDescription ?? "Probe failed")); return .failure(error)
        }

        // 3. Validate against the capability manifest.
        if isCancelled(jobID) { onPhase(.cancelled); return .failure(.cancelled) }
        onPhase(.validating)
        guard configuration.manifest.canEncode(request.outputFormat, ffmpegAvailable: configuration.ffmpegAvailable) else {
            let error = MediaConverterError.unsupportedConversion(reason: "This output format isn't available in this build.")
            onPhase(.failed(reason: error.errorDescription ?? "Unsupported")); return .failure(error)
        }
        // The source kind must match the backend's domain.
        let compatible: Bool
        switch request.outputFormat.kind {
        case .image: compatible = probe.kind == .image
        case .video: compatible = probe.kind == .video
        case .audio: compatible = probe.kind == .audio || probe.kind == .video
        case nil: compatible = false
        }
        if !compatible {
            let error = MediaConverterError.unsupportedConversion(reason: "The source type doesn't match this output format.")
            onPhase(.failed(reason: error.errorDescription ?? "Unsupported")); return .failure(error)
        }

        // Resolve non-overwriting conflict policies before spending time and
        // memory on an encode. Suffix mode is resolved by the selected backend.
        let proposedOutput = OutputNaming.proposedURL(
            for: request.source,
            format: request.outputFormat,
            in: request.outputDirectory
        )
        if FileManager.default.fileExists(atPath: proposedOutput.path) {
            switch request.conflict {
            case .skip:
                onPhase(.skipped(reason: "An output with this name already exists."))
                return .failure(.skippedExistingOutput)
            case .fail:
                let error = MediaConverterError.finalizationFailed(
                    reason: "An output with this name already exists."
                )
                onPhase(.failed(reason: error.errorDescription ?? "Output exists"))
                return .failure(error)
            case .suffix:
                break
            }
        }

        // 4. Disk preflight (rough estimate: require at least the source size).
        if isCancelled(jobID) { onPhase(.cancelled); return .failure(.cancelled) }
        let available = diskSpace.availableBytes(on: request.outputDirectory)
        if available > 0 && probe.fileSize > 0 && available < probe.fileSize {
            let error = MediaConverterError.insufficientDiskSpace(requiredBytes: probe.fileSize, availableBytes: available)
            onPhase(.failed(reason: error.errorDescription ?? "Disk full")); return .failure(error)
        }

        // 5. Encode through ImageIO or the isolated FFmpeg helper.
        if isCancelled(jobID) { onPhase(.cancelled); return .failure(.cancelled) }
        onPhase(.encoding(progress: 0))
        let encodeResult: Result<URL, MediaConverterError>
        if request.outputFormat.kind == .image {
            encodeResult = await imageEncoder.encode(request, source: probe)
        } else {
            // Audio/video route through the isolated FFmpeg helper over XPC.
            encodeResult = await transcodeViaHelper(request: request, jobID: jobID)
        }

        switch encodeResult {
        case .success(let output):
            if isCancelled(jobID) {
                try? FileManager.default.removeItem(at: output)
                onPhase(.cancelled)
                return .failure(.cancelled)
            }
            // 6. Re-probe the output before declaring success. Defense in depth:
            // the encoder already finalized, but we independently verify the
            // output is a real, readable file of the right kind.
            onPhase(.reprobing)
            switch await inspectMedia(url: output) {
            case .success(let reprobe):
                guard reprobe.kind == request.outputFormat.kind else {
                    try? FileManager.default.removeItem(at: output)
                    let error = MediaConverterError.outputReprobeFailed(reason: "The output kind didn't match.")
                    onPhase(.failed(reason: error.errorDescription ?? "Re-probe failed"))
                    return .failure(error)
                }
                let sizeDelta = reprobe.fileSize - probe.fileSize
                onPhase(.completed(destination: output, sizeDelta: sizeDelta))
                return .success(output)
            case .failure(let error):
                try? FileManager.default.removeItem(at: output)
                onPhase(.failed(reason: error.errorDescription ?? "Re-probe failed"))
                return .failure(error)
            }
        case .failure(let error):
            if error == .cancelled || isCancelled(jobID) {
                onPhase(.cancelled)
                return .failure(.cancelled)
            }
            onPhase(.failed(reason: error.errorDescription ?? "Encode failed"))
            return .failure(error)
        }
    }

    // MARK: - FFmpeg helper path (audio/video)

    /// Native frameworks are quickest for images and Apple media. FFprobe is
    /// the authoritative fallback for containers such as Opus/Ogg, MKV and
    /// WebM that UTType/AVFoundation often classify as generic data.
    private func inspectMedia(url: URL) async -> Result<MediaProbeResult, MediaConverterError> {
        let native = await probeAdapter.probe(url: url)
        if case .success = native { return native }
        guard configuration.ffmpegAvailable, let engineClient else { return native }
        do {
            return .success(try await engineClient.probe(url))
        } catch let error as MediaConverterError {
            return .failure(error)
        } catch {
            return .failure(.probeFailed(reason: error.localizedDescription))
        }
    }

    /// Route an audio/video request to the isolated FFmpeg helper. Resolves a
    /// staging output URL inside the destination directory, asks the helper to
    /// transcode, and returns the final URL on success. Partial output is
    /// cleaned up by the helper; a final re-probe still happens upstream.
    private func transcodeViaHelper(
        request: MediaConversionRequest,
        jobID: UUID
    ) async -> Result<URL, MediaConverterError> {
        guard let engineClient else {
            return .failure(.ffmpegBackendUnavailable)
        }
        // Resolve the output URL with the conflict policy. The helper writes to
        // this exact path (no staging indirection on the host side because the
        // conflict resolution already produced a unique name).
        let proposed = OutputNaming.proposedURL(for: request.source, format: request.outputFormat, in: request.outputDirectory)
        let exists: (URL) -> Bool = { FileManager.default.fileExists(atPath: $0.path) }
        guard let resolved = OutputNaming.resolve(proposed, conflict: request.conflict, exists: exists) else {
            return .failure(.finalizationFailed(reason: "An output with this name already exists."))
        }
        do {
            let result = try await engineClient.transcode(
                request,
                outputURL: resolved,
                requestID: jobID
            )
            // Verify the output exists and is non-empty before declaring success.
            let attrs = try FileManager.default.attributesOfItem(atPath: result.outputURL.path)
            let bytes = (attrs[.size] as? Int64) ?? Int64((attrs[.size] as? Int) ?? 0)
            guard bytes > 0 else {
                try? FileManager.default.removeItem(at: result.outputURL)
                return .failure(.outputReprobeFailed(reason: "The output was empty."))
            }
            return .success(result.outputURL)
        } catch let error as MediaConverterError {
            return .failure(error)
        } catch let error as MediaConverterEngineClientError {
            return .failure(.helperFailure(reason: error.errorDescription ?? "Helper error"))
        } catch {
            return .failure(.helperFailure(reason: error.localizedDescription))
        }
    }

    // MARK: - Cancellation

    public nonisolated func cancel(_ jobID: UUID) {
        Task { await cancelJob(jobID) }
    }

    /// Test-only entry to flip the cancellation flag before running the job.
    /// Internal so tests in the same module can reach it without exposing it
    /// in the public API.
    internal func markCancelled(_ jobID: UUID) {
        cancelled.insert(jobID)
    }

    private func cancelJob(_ jobID: UUID) async {
        cancelled.insert(jobID)
        try? await engineClient?.cancel(jobID)
    }

    private func isCancelled(_ jobID: UUID) -> Bool {
        cancelled.contains(jobID)
    }
}
