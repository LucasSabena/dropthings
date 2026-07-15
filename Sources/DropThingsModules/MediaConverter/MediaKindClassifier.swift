import Foundation
import UniformTypeIdentifiers
import DropThingsMediaConverterKit

/// Lightweight, synchronous media-kind classification for intake/drop. Uses the
/// file's concrete UTType (resolved from the file itself, not just the ext) so
/// a renamed file still classifies correctly. This never infers *capability* —
/// that stays with `MediaCapabilityManifest` — it only decides the broad family.
enum MediaKindClassifier {
    static func kind(of url: URL) -> MediaKind {
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
}
