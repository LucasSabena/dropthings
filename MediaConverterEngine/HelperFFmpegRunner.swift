import Foundation
import DropThingsMediaConverterKit

/// Owns every FFmpeg process so cancellation can terminate the exact request.
final class HelperFFmpegRunner: @unchecked Sendable {
    static let shared = HelperFFmpegRunner()

    private let lock = NSLock()
    private var active: [UUID: Process] = [:]
    private var cancelled: Set<UUID> = []

    static func ffmpegURL() -> URL? { executable(named: "ffmpeg") }
    static func ffprobeURL() -> URL? { executable(named: "ffprobe") }

    func cancel(_ requestID: UUID) {
        let process = lock.withLock { () -> Process? in
            cancelled.insert(requestID)
            return active[requestID]
        }
        if process?.isRunning == true { process?.terminate() }
    }

    func transcode(requestID: UUID, request: MediaConversionRequest, outputURL: URL) async throws -> Int64 {
        guard let executable = Self.ffmpegURL() else { throw MediaConverterError.ffmpegBackendUnavailable }
        guard let kind = request.outputFormat.kind else {
            throw MediaConverterError.unsupportedConversion(reason: "Unknown output format.")
        }
        let base: [String]?
        switch kind {
        case .audio: base = FFmpegArgumentBuilder.audioArguments(for: request)
        case .video: base = FFmpegArgumentBuilder.videoArguments(for: request)
        case .image: base = nil
        }
        guard let base else {
            throw MediaConverterError.unsupportedConversion(reason: "This format is not handled by FFmpeg.")
        }

        try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        do {
            let status = try await run(
                executable: executable,
                arguments: FFmpegArgumentBuilder.appending(output: outputURL, to: base),
                requestID: requestID
            )
            guard status == 0 else {
                try? FileManager.default.removeItem(at: outputURL)
                if isCancelled(requestID) { throw MediaConverterError.cancelled }
                throw MediaConverterError.helperFailure(reason: "Conversion failed (exit \(status)).")
            }
            let attributes = try FileManager.default.attributesOfItem(atPath: outputURL.path)
            return (attributes[.size] as? NSNumber)?.int64Value ?? 0
        } catch {
            try? FileManager.default.removeItem(at: outputURL)
            throw error
        }
    }

    func probe(url: URL) async throws -> Data {
        guard let executable = Self.ffprobeURL() else { throw MediaConverterError.ffmpegBackendUnavailable }
        let output = FileManager.default.temporaryDirectory.appendingPathComponent("dropthings-ffprobe-\(UUID().uuidString).json")
        FileManager.default.createFile(atPath: output.path, contents: nil)
        defer { try? FileManager.default.removeItem(at: output) }
        let handle = try FileHandle(forWritingTo: output)
        defer { try? handle.close() }

        let process = Process()
        process.executableURL = executable
        process.arguments = ["-v", "error", "-print_format", "json", "-show_format", "-show_streams", "--", url.path]
        process.standardOutput = handle
        process.standardError = FileHandle.nullDevice
        let status = try await wait(for: process)
        guard status == 0 else {
            throw MediaConverterError.probeFailed(reason: "ffprobe exited with \(status).")
        }
        return try Data(contentsOf: output)
    }

    private func run(executable: URL, arguments: [String], requestID: UUID) async throws -> Int32 {
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        let alreadyCancelled = lock.withLock { () -> Bool in
            active[requestID] = process
            return cancelled.contains(requestID)
        }
        defer {
            lock.withLock {
                active[requestID] = nil
                cancelled.remove(requestID)
            }
        }
        if alreadyCancelled { throw MediaConverterError.cancelled }

        return try await withTaskCancellationHandler {
            let status = try await wait(for: process)
            if self.isCancelled(requestID) { throw MediaConverterError.cancelled }
            return status
        } onCancel: {
            self.cancel(requestID)
        }
    }

    private func wait(for process: Process) async throws -> Int32 {
        try await withCheckedThrowingContinuation { continuation in
            let gate = ProcessContinuationGate(continuation)
            process.terminationHandler = { process in gate.succeed(process.terminationStatus) }
            do { try process.run() } catch { gate.fail(error) }
        }
    }

    private func isCancelled(_ requestID: UUID) -> Bool {
        lock.withLock { cancelled.contains(requestID) }
    }

    private static func executable(named name: String) -> URL? {
        let candidate = Bundle.main.bundleURL
            .appendingPathComponent("Contents/SharedSupport/FFmpeg/\(name)")
        return FileManager.default.isExecutableFile(atPath: candidate.path) ? candidate : nil
    }
}

private final class ProcessContinuationGate: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Int32, Error>?

    init(_ continuation: CheckedContinuation<Int32, Error>) { self.continuation = continuation }
    func succeed(_ value: Int32) { take()?.resume(returning: value) }
    func fail(_ error: Error) { take()?.resume(throwing: error) }

    private func take() -> CheckedContinuation<Int32, Error>? {
        lock.withLock {
            defer { continuation = nil }
            return continuation
        }
    }
}
