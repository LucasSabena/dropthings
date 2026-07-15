import XCTest
@testable import DropThingsMediaConverterKit

/// Tests that FFmpeg argument construction is injection-safe. Paths with
/// spaces, quotes, newlines and leading dashes must never be interpreted as
/// options because they ride as their own argv tokens — and the builder must
/// never produce a shell string (QUALITY.md: "FFmpeg arguments are arrays").
final class FFmpegArgumentBuilderTests: XCTestCase {

    private func makeRequest(format: MediaFormatID, source: URL) -> MediaConversionRequest {
        MediaConversionRequest(
            source: source,
            outputDirectory: URL(fileURLWithPath: "/tmp/out"),
            outputFormat: format,
            resize: .none,
            noUpscale: false,
            quality: 80,
            metadata: .stripNonessential,
            conflict: .suffix
        )
    }

    func testAudioArgumentsContainInputPathAsOwnToken() {
        let hostile = URL(fileURLWithPath: "/Library/Cool Music/track -final.mp3")
        let request = makeRequest(format: .m4aAAC, source: hostile)
        let args = FFmpegArgumentBuilder.audioArguments(for: request)
        XCTAssertNotNil(args)
        // The source path must be a standalone array element, never glued to -i.
        XCTAssertTrue(args!.contains(hostile.path))
        let iIndex = args!.firstIndex(of: "-i")!
        XCTAssertEqual(args![iIndex + 1], hostile.path)
    }

    func testLeadingDashInPathStaysAsOwnToken() {
        // A file literally named "-flag.mp3" must not be parsed as an option.
        let hostile = URL(fileURLWithPath: "/tmp/-flag.mp3")
        let request = makeRequest(format: .flac, source: hostile)
        let args = FFmpegArgumentBuilder.audioArguments(for: request)!
        XCTAssertEqual(args[args.firstIndex(of: "-i")! + 1], "/tmp/-flag.mp3")
    }

    func testNewlineInPathStaysAsOwnToken() {
        let hostile = URL(fileURLWithPath: "/tmp/a\nb.mp3")
        let request = makeRequest(format: .wav, source: hostile)
        let args = FFmpegArgumentBuilder.audioArguments(for: request)!
        XCTAssertEqual(args[args.firstIndex(of: "-i")! + 1], "/tmp/a\nb.mp3")
    }

    func testQuoteInPathStaysAsOwnToken() {
        let hostile = URL(fileURLWithPath: "/tmp/\"quoted\".flac")
        let request = makeRequest(format: .flac, source: hostile)
        let args = FFmpegArgumentBuilder.audioArguments(for: request)!
        XCTAssertEqual(args[args.firstIndex(of: "-i")! + 1], "/tmp/\"quoted\".flac")
    }

    func testAppendingOutputKeepsPathAsToken() {
        let out = URL(fileURLWithPath: "/tmp/out/weird name; rm -rf.mov")
        let base = FFmpegArgumentBuilder.videoArguments(for: makeRequest(format: .mp4H264, source: URL(fileURLWithPath: "/tmp/in.mov")))!
        let combined = FFmpegArgumentBuilder.appending(output: out, to: base)
        XCTAssertEqual(combined.last, out.path)
    }

    func testVideoUsesVideoToolboxEncoder() {
        let args = FFmpegArgumentBuilder.videoArguments(for: makeRequest(format: .mp4H264, source: URL(fileURLWithPath: "/tmp/in.mov")))!
        // Must use the LGPL hardware encoder, never libx264 (GPL).
        XCTAssertTrue(args.contains("h264_videotoolbox"))
        XCTAssertFalse(args.contains("libx264"))
    }

    func testMP3NotSupportedReturnsNil() {
        // The pinned FFmpeg has no libmp3lame; the builder must not emit args.
        let request = makeRequest(format: .mp3, source: URL(fileURLWithPath: "/tmp/x.wav"))
        XCTAssertNil(FFmpegArgumentBuilder.audioArguments(for: request))
    }

    func testOpusExplicitlyEnablesBundledExperimentalEncoder() {
        let args = FFmpegArgumentBuilder.audioArguments(for: makeRequest(format: .opus, source: URL(fileURLWithPath: "/tmp/x.wav")))!
        XCTAssertTrue(args.contains("experimental"))
    }

    func testTranscriptionNormalizationForcesWhisperPCMShape() {
        let request = MediaConversionRequest(
            source: URL(fileURLWithPath: "/tmp/source.webm"),
            outputDirectory: URL(fileURLWithPath: "/tmp"),
            outputFormat: .wav,
            audioSampleRate: 16_000,
            audioChannels: 1,
            metadata: .stripNonessential
        )
        let args = FFmpegArgumentBuilder.audioArguments(for: request)!
        XCTAssertEqual(args[args.firstIndex(of: "-ar")! + 1], "16000")
        XCTAssertEqual(args[args.firstIndex(of: "-ac")! + 1], "1")
        XCTAssertTrue(args.contains("pcm_s16le"))
    }

    func testNonAudioRequestReturnsNilForAudioBuilder() {
        let request = makeRequest(format: .png, source: URL(fileURLWithPath: "/tmp/x.png"))
        XCTAssertNil(FFmpegArgumentBuilder.audioArguments(for: request))
    }

    func testNonVideoRequestReturnsNilForVideoBuilder() {
        let request = makeRequest(format: .png, source: URL(fileURLWithPath: "/tmp/x.png"))
        XCTAssertNil(FFmpegArgumentBuilder.videoArguments(for: request))
    }

    func testNoShellStringIsProduced() {
        // The builder must return [String], never a joined shell command.
        let request = makeRequest(format: .m4aAAC, source: URL(fileURLWithPath: "/tmp/x.mp3"))
        let args = FFmpegArgumentBuilder.audioArguments(for: request)!
        for arg in args {
            XCTAssertFalse(arg.contains("&&") || arg.contains(";"),
                           "Argument token must not contain shell operators: \(arg)")
        }
    }
}
