import Foundation
import DropThingsTranscriptionKit
import whisper

public final class WhisperTranscriptionEngine: @unchecked Sendable {
    private let lock = NSLock()
    private var tokens: [UUID: CancellationToken] = [:]

    public init() {}

    public var version: String {
        String(cString: whisper_version())
    }

    /// Registers the job before it enters the serial inference queue so an
    /// immediate host cancellation cannot race ahead of token creation.
    public func prepare(jobID: UUID) {
        lock.withLock {
            if tokens[jobID] == nil { tokens[jobID] = CancellationToken() }
        }
    }

    public func cancel(jobID: UUID) {
        lock.withLock { tokens[jobID]?.cancel() }
    }

    public func transcribe(_ request: TranscriptionRequest) throws -> TranscriptDocument {
        guard request.protocolVersion == TranscriptionProtocol.currentVersion else {
            throw TranscriptionContractError.unsupportedProtocol(request.protocolVersion)
        }
        let token = lock.withLock { () -> CancellationToken in
            if let existing = tokens[request.jobID] { return existing }
            let created = CancellationToken()
            tokens[request.jobID] = created
            return created
        }
        defer { lock.withLock { tokens[request.jobID] = nil } }
        if token.isCancelled { throw TranscriptionClientError.cancelled }
        let facts = try WAVInspector.inspect(url: request.inputURL)
        let samples = try WAVPCMDecoder.decodeMonoPCM16(url: request.inputURL)
        if token.isCancelled { throw TranscriptionClientError.cancelled }

        var contextParameters = whisper_context_default_params()
        contextParameters.use_gpu = true
        guard let context = request.modelURL.path.withCString({
            whisper_init_from_file_with_params($0, contextParameters)
        }) else {
            throw TranscriptionClientError.helperFailed("The verified model could not be loaded.")
        }
        defer { whisper_free(context) }
        if token.isCancelled { throw TranscriptionClientError.cancelled }

        var parameters = whisper_full_default_params(WHISPER_SAMPLING_GREEDY)
        parameters.n_threads = Int32(min(max(ProcessInfo.processInfo.activeProcessorCount - 1, 1), 8))
        parameters.translate = request.mode == .translateToEnglish
        parameters.print_special = false
        parameters.print_progress = false
        parameters.print_realtime = false
        parameters.print_timestamps = false
        parameters.abort_callback = { userData in
            guard let userData else { return false }
            return Unmanaged<CancellationToken>.fromOpaque(userData).takeUnretainedValue().isCancelled
        }
        parameters.abort_callback_user_data = Unmanaged.passUnretained(token).toOpaque()

        let language = request.language.whisperArgument ?? "auto"
        let prompt = request.initialPrompt ?? ""
        let status = language.withCString { languagePointer in
            prompt.withCString { promptPointer in
                parameters.language = languagePointer
                parameters.initial_prompt = request.initialPrompt == nil ? nil : promptPointer
                return samples.withUnsafeBufferPointer { buffer in
                    whisper_full(context, parameters, buffer.baseAddress, Int32(buffer.count))
                }
            }
        }
        if token.isCancelled { throw TranscriptionClientError.cancelled }
        guard status == 0 else {
            throw TranscriptionClientError.helperFailed("The local engine stopped with code \(status).")
        }

        let count = whisper_full_n_segments(context)
        var segments: [TranscriptSegment] = []
        segments.reserveCapacity(Int(count))
        for index in 0..<count {
            segments.append(TranscriptSegment(
                startMilliseconds: whisper_full_get_segment_t0(context, index) * 10,
                endMilliseconds: whisper_full_get_segment_t1(context, index) * 10,
                text: String(cString: whisper_full_get_segment_text(context, index))
            ))
        }
        let languageID = whisper_full_lang_id(context)
        let detectedLanguage = languageID >= 0 ? String(cString: whisper_lang_str(languageID)) : nil
        return try TranscriptDocument(
            jobID: request.jobID,
            sourceFileName: request.inputURL.lastPathComponent,
            language: detectedLanguage,
            durationMilliseconds: max(facts.durationMilliseconds, segments.last?.endMilliseconds ?? 0),
            segments: segments
        )
    }
}

private final class CancellationToken: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false

    var isCancelled: Bool { lock.withLock { cancelled } }
    func cancel() { lock.withLock { cancelled = true } }
}
