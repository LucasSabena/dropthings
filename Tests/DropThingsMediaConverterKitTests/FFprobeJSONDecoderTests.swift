import Foundation
import Testing
@testable import DropThingsMediaConverterKit

@Suite("FFprobe JSON decoder")
struct FFprobeJSONDecoderTests {
    @Test("Audio-only files are classified as audio")
    func audioOnly() throws {
        let data = Data(#"{"streams":[{"codec_type":"audio","sample_rate":"48000","channels":2}],"format":{"duration":"2.5","size":"1200"}}"#.utf8)
        let result = try FFprobeJSONDecoder.decode(data, sourceURL: URL(fileURLWithPath: "/tmp/audio.m4a"))
        #expect(result.kind == .audio)
        #expect(result.sampleRate == 48_000)
        #expect(result.channelCount == 2)
        #expect(result.dimensions == nil)
    }

    @Test("Video wins when a file also contains audio")
    func videoWithAudio() throws {
        let data = Data(#"{"streams":[{"codec_type":"audio"},{"codec_type":"video","width":1920,"height":1080,"avg_frame_rate":"30000/1001","pix_fmt":"yuv420p"}],"format":{"size":"42"}}"#.utf8)
        let result = try FFprobeJSONDecoder.decode(data, sourceURL: URL(fileURLWithPath: "/tmp/video.mp4"))
        #expect(result.kind == .video)
        #expect(result.dimensions == MediaDimensions(width: 1920, height: 1080))
        #expect(result.frameRate != nil && abs(result.frameRate! - 29.97) < 0.01)
    }

    @Test("A payload without media streams fails")
    func noStreams() {
        #expect(throws: MediaConverterError.self) {
            try FFprobeJSONDecoder.decode(Data(#"{"streams":[]}"#.utf8), sourceURL: URL(fileURLWithPath: "/tmp/nope"))
        }
    }
}
