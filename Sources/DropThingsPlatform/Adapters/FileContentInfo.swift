import Foundation
import UniformTypeIdentifiers

/// A small, shared classification of an on-disk URL. Clipboard History and
/// File Shelf both need to distinguish folders, images, videos, and ordinary
/// documents; keeping that decision in Platform prevents the modules from
/// drifting into different answers for the same file.
public struct FileContentInfo: Equatable, Sendable {
    public enum Kind: String, Equatable, Sendable, CaseIterable {
        case folder
        case image
        case video
        case audio
        case pdf
        case archive
        case text
        case application
        case file

        public var systemImageName: String {
            switch self {
            case .folder: return "folder.fill"
            case .image: return "photo"
            case .video: return "film"
            case .audio: return "waveform"
            case .pdf: return "doc.richtext"
            case .archive: return "archivebox"
            case .text: return "doc.text"
            case .application: return "app"
            case .file: return "doc"
            }
        }

        public var displayName: String {
            switch self {
            case .folder: return "Folder"
            case .image: return "Image"
            case .video: return "Video"
            case .audio: return "Audio"
            case .pdf: return "PDF"
            case .archive: return "Archive"
            case .text: return "Text file"
            case .application: return "Application"
            case .file: return "File"
            }
        }
    }

    public let url: URL
    public let kind: Kind
    public let contentTypeIdentifier: String?
    public let byteCount: Int64?
    public let modifiedAt: Date?

    public init(
        url: URL,
        kind: Kind,
        contentTypeIdentifier: String? = nil,
        byteCount: Int64? = nil,
        modifiedAt: Date? = nil
    ) {
        self.url = url
        self.kind = kind
        self.contentTypeIdentifier = contentTypeIdentifier
        self.byteCount = byteCount
        self.modifiedAt = modifiedAt
    }

    public static func inspect(_ url: URL, fileManager: FileManager = .default) -> FileContentInfo {
        let keys: Set<URLResourceKey> = [
            .isDirectoryKey,
            .contentTypeKey,
            .fileSizeKey,
            .contentModificationDateKey
        ]
        let values = try? url.resourceValues(forKeys: keys)
        let type = values?.contentType ?? UTType(filenameExtension: url.pathExtension)
        let attributes = try? fileManager.attributesOfItem(atPath: url.path)
        let attributeType = attributes?[.type] as? FileAttributeType
        let isDirectory = values?.isDirectory ?? (attributeType == .typeDirectory)

        let kind: Kind
        if isDirectory == true {
            kind = .folder
        } else if type?.conforms(to: .image) == true {
            kind = .image
        } else if type?.conforms(to: .movie) == true || type?.conforms(to: .video) == true {
            kind = .video
        } else if type?.conforms(to: .audio) == true {
            kind = .audio
        } else if type?.conforms(to: .pdf) == true {
            kind = .pdf
        } else if type?.conforms(to: .archive) == true {
            kind = .archive
        } else if type?.conforms(to: .plainText) == true || type?.conforms(to: .sourceCode) == true {
            kind = .text
        } else if type?.conforms(to: .application) == true {
            kind = .application
        } else {
            kind = .file
        }

        return FileContentInfo(
            url: url,
            kind: kind,
            contentTypeIdentifier: type?.identifier,
            byteCount: values?.fileSize.map(Int64.init),
            modifiedAt: values?.contentModificationDate
        )
    }
}
