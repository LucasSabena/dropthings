import Foundation
import AppKit
import DropThingsCore

/// One content-aware action Smart Clipboard can perform on the current
/// snapshot. Actions are deterministic and previewable: they produce a string
/// (or pasteboard-ready payload) the user sees before committing.
///
/// Actions are intentionally value types so the panel can list them without
/// touching AppKit and the module can apply them in isolation.
public struct SmartClipboardAction: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let systemImage: String
    /// `true` when the action needs Accessibility to paste the result back into
    /// the previous app. Copy-only actions stay `false`.
    public let requiresAccessibility: Bool

    /// Discriminator. The module applies each case via the engine.
    public enum Body: Hashable, Sendable {
        case textCase(SmartClipboardTextEngine.CaseTransform)
        case textWhitespace(SmartClipboardTextEngine.WhitespaceTransform)
        case textLines(SmartClipboardTextEngine.LineTransform)
        case textEncoding(SmartClipboardTextEngine.EncodingTransform)
        case textCounts
        case jsonValidate
        case jsonPretty(sortKeys: Bool)
        case jsonMinify(sortKeys: Bool)
        case urlNormalize
        case urlMarkdownLink
        case urlStripTracking
        case urlTitleFetch
        case colorFormat(SmartClipboardColorFormat)
        case filesReveal
        case filesCopyNames
        case filesCopyPaths
        case filesInfo
        case filesSaveRepresentation
        case filesAction(FileActionRef)
    }

    public let body: Body

    public init(id: String, title: String, systemImage: String, body: Body, requiresAccessibility: Bool = false) {
        self.id = id
        self.title = title
        self.systemImage = systemImage
        self.body = body
        self.requiresAccessibility = requiresAccessibility
    }
}

/// Output formats for a parsed color, preserving alpha where relevant.
public enum SmartClipboardColorFormat: String, CaseIterable, Identifiable, Codable, Sendable {
    case hex, rgb, hsl, css, swiftUIColor
    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .hex: return "HEX"
        case .rgb: return "RGB"
        case .hsl: return "HSL"
        case .css: return "CSS"
        case .swiftUIColor: return "SwiftUI Color"
        }
    }
    public var systemImage: String {
        switch self {
        case .hex: return "number"
        case .rgb: return "slider.horizontal.3"
        case .hsl: return "circle.lefthalf.filled"
        case .css: return "curlybraces"
        case .swiftUIColor: return "swift"
        }
    }
}

/// A reference to an action published by another module through Core's
/// `FileActionRegistry`. Smart Clipboard never imports the producer module; it
/// only carries the opaque id and label so it can ask Core to run it.
public typealias FileActionRef = FileActionRefShim

/// Pure builder of the ordered action list for a given kind. The module owns
/// the live `FileActionRegistry` snapshot (Phase 3) and merges it here.
public enum SmartClipboardActionRegistry {
    /// Actions for a text payload, in display order. Ambiguous text that the
    /// user forced to `.text` via "Treat As" also gets this list.
    public static func textActions() -> [SmartClipboardAction] {
        var actions: [SmartClipboardAction] = []
        for transform in SmartClipboardTextEngine.CaseTransform.allCases {
            actions.append(SmartClipboardAction(
                id: "text.case.\(transform.rawValue)",
                title: transform.label,
                systemImage: "textformat",
                body: .textCase(transform)
            ))
        }
        for transform in SmartClipboardTextEngine.WhitespaceTransform.allCases {
            actions.append(SmartClipboardAction(
                id: "text.ws.\(transform.rawValue)",
                title: transform.label,
                systemImage: "ruler",
                body: .textWhitespace(transform)
            ))
        }
        for transform in SmartClipboardTextEngine.LineTransform.allCases {
            actions.append(SmartClipboardAction(
                id: "text.lines.\(transform.rawValue)",
                title: transform.label,
                systemImage: "arrow.up.arrow.down",
                body: .textLines(transform)
            ))
        }
        for transform in SmartClipboardTextEngine.EncodingTransform.allCases {
            actions.append(SmartClipboardAction(
                id: "text.encoding.\(transform.rawValue)",
                title: transform.label,
                systemImage: "link",
                body: .textEncoding(transform)
            ))
        }
        actions.append(SmartClipboardAction(
            id: "text.counts",
            title: "Counts",
            systemImage: "info.circle",
            body: .textCounts
        ))
        return actions
    }

    public static func urlActions(canFetchTitle: Bool) -> [SmartClipboardAction] {
        var actions: [SmartClipboardAction] = [
            SmartClipboardAction(
                id: "url.normalize",
                title: "Normalize",
                systemImage: "wand.and.stars",
                body: .urlNormalize
            ),
            SmartClipboardAction(
                id: "url.markdown",
                title: "Copy Markdown link",
                systemImage: "link",
                body: .urlMarkdownLink
            ),
            SmartClipboardAction(
                id: "url.strip-tracking",
                title: "Remove tracking parameters",
                systemImage: "hand.raised",
                body: .urlStripTracking
            )
        ]
        if canFetchTitle {
            actions.append(SmartClipboardAction(
                id: "url.fetch-title",
                title: "Fetch page title",
                systemImage: "network",
                body: .urlTitleFetch
            ))
        }
        return actions
    }

    public static func jsonActions() -> [SmartClipboardAction] {
        [
            SmartClipboardAction(id: "json.validate", title: "Validate", systemImage: "checkmark.seal", body: .jsonValidate),
            SmartClipboardAction(id: "json.pretty", title: "Pretty print", systemImage: "curlybraces", body: .jsonPretty(sortKeys: false)),
            SmartClipboardAction(id: "json.pretty-sorted", title: "Pretty print (sorted keys)", systemImage: "curlybraces", body: .jsonPretty(sortKeys: true)),
            SmartClipboardAction(id: "json.minify", title: "Minify", systemImage: "curlybraces.square", body: .jsonMinify(sortKeys: false)),
            SmartClipboardAction(id: "json.minify-sorted", title: "Minify (sorted keys)", systemImage: "curlybraces.square", body: .jsonMinify(sortKeys: true))
        ]
    }

    public static func colorActions() -> [SmartClipboardAction] {
        SmartClipboardColorFormat.allCases.map { format in
            SmartClipboardAction(
                id: "color.format.\(format.rawValue)",
                title: format.label,
                systemImage: format.systemImage,
                body: .colorFormat(format)
            )
        }
    }

    public static func filesActions(fileActions: [FileActionRef]) -> [SmartClipboardAction] {
        var actions: [SmartClipboardAction] = [
            SmartClipboardAction(id: "files.reveal", title: "Reveal in Finder", systemImage: "magnifyingglass", body: .filesReveal),
            SmartClipboardAction(id: "files.copy-names", title: "Copy file names", systemImage: "doc.on.doc", body: .filesCopyNames),
            SmartClipboardAction(id: "files.copy-paths", title: "Copy file paths", systemImage: "link", body: .filesCopyPaths),
            SmartClipboardAction(id: "files.info", title: "Size & dimensions", systemImage: "info.circle", body: .filesInfo)
        ]
        for ref in fileActions {
            actions.append(SmartClipboardAction(
                id: "files.action.\(ref.id)",
                title: ref.title,
                systemImage: ref.systemImage,
                body: .filesAction(ref)
            ))
        }
        return actions
    }

    public static func imageActions() -> [SmartClipboardAction] {
        [
            SmartClipboardAction(id: "image.info", title: "Dimensions & size", systemImage: "info.circle", body: .filesInfo),
            SmartClipboardAction(id: "image.save", title: "Save to file", systemImage: "square.and.arrow.down", body: .filesSaveRepresentation)
        ]
    }

    /// Ordered actions for a kind, optionally merged with live file actions.
    public static func actions(
        for kind: SmartClipboardKind,
        fileActions: [FileActionRef] = [],
        canFetchTitle: Bool = false
    ) -> [SmartClipboardAction] {
        switch kind {
        case .text: return textActions()
        case .url: return urlActions(canFetchTitle: canFetchTitle)
        case .json: return jsonActions()
        case .color: return colorActions()
        case .files: return filesActions(fileActions: fileActions)
        case .image: return imageActions()
        }
    }
}