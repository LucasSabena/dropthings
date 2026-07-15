import Foundation
import UniformTypeIdentifiers
import DropThingsMediaConverterKit

/// Lightweight, synchronous media-kind classification for intake/drop. Uses the
/// file's concrete UTType (resolved from the file itself, not just the ext) so
/// a renamed file still classifies correctly. This never infers *capability* —
/// that stays with `MediaCapabilityManifest` — it only decides the broad family.
enum MediaKindClassifier {
    static func kind(of url: URL) -> MediaKind {
        switch url.pathExtension.lowercased() {
        case "mkv", "webm", "avi", "mp4", "mov", "m4v", "mpeg", "mpg", "ts":
            return .video
        case "opus", "ogg", "oga", "flac", "mp3", "m4a", "aac", "wav", "aif", "aiff", "wma":
            return .audio
        default:
            break
        }
        let type: UTType
        if let resolved = (try? url.resourceValues(forKeys: [.contentTypeKey]))?.contentType {
            type = resolved
        } else if let ext = UTType(filenameExtension: url.pathExtension) {
            type = ext
        } else {
            return .image
        }
        if type.conforms(to: .image) { return .image }
        if type.conforms(to: .movie) || type.conforms(to: .audiovisualContent) { return .video }
        if type.conforms(to: .audio) { return .audio }
        // Unknown content type defaults to image so the native path at least
        // attempts a probe; the pipeline will report a clear failure if it
        // cannot read it.
        return .image
    }

    static func label(for kind: MediaKind) -> String {
        switch kind {
        case .image: return "image"
        case .audio: return "audio"
        case .video: return "video"
        }
    }
}
