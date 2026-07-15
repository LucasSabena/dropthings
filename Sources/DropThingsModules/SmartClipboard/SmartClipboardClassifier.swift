import Foundation

/// Content-aware classification of a pasteboard snapshot. Deterministic, local,
/// and free of side effects so it can be unit-tested without a running app.
///
/// Ambiguous strings retain `.text` so general text actions always remain
/// available (a hard product invariant). Specialized kinds (`.url`, `.json`,
/// `.color`) are only returned when the content unambiguously parses.
public enum SmartClipboardKind: Sendable, Equatable, Hashable {
    case text
    case url
    case json
    case color
    case files
    case image

    /// Human label shown in the panel header and the "Treat As" menu.
    public var label: String {
        switch self {
        case .text: return "Text"
        case .url: return "URL"
        case .json: return "JSON"
        case .color: return "Color"
        case .files: return "Files"
        case .image: return "Image"
        }
    }

    public var systemImage: String {
        switch self {
        case .text: return "text.alignleft"
        case .url: return "link"
        case .json: return "curlybraces"
        case .color: return "paintpalette"
        case .files: return "doc.on.doc"
        case .image: return "photo"
        }
    }
}

/// Pure classifier. No AppKit, no pasteboard, no I/O. The module feeds it a
/// snapshot's text payload and gets the most specific kind that parses.
public enum SmartClipboardClassifier {
    /// `true` when `string` parses as a JSON object or array. Rejects plain
    /// numbers, bare strings, and whitespace-only input so `"hello"` stays text.
    public static func isJSON(_ string: String) -> Bool {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first, let last = trimmed.last else { return false }
        // Object or array only; a bare number/string is not "JSON" for our
        // purposes since the text actions already cover it.
        guard (first == "{" && last == "}") || (first == "[" && last == "]") else { return false }
        guard let data = string.data(using: .utf8) else { return false }
        guard let object = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) else {
            return false
        }
        return object is [Any] || object is [String: Any]
    }

    /// `true` when `string` is a single absolute URL with a scheme. Bare
    /// filenames and relative paths stay text.
    public static func isURL(_ string: String) -> Bool {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.contains("\n") == false else { return false }
        guard let url = URL(string: trimmed), let scheme = url.scheme, scheme.count >= 2 else {
            return false
        }
        // Reject schemes that are almost certainly not URLs (`file:` handled by
        // the files kind at the snapshot level, not here).
        return scheme.lowercased() != "file"
    }

    /// Parse a color string. Supports HEX (3/4/6/8), `rgb()`, `rgba()`,
    /// `hsl()`, `hsla()`, and CSS named colors. Returns `nil` for anything
    /// else so the caller keeps general text actions.
    public static func parseColor(_ string: String) -> SmartClipboardColor? {
        SmartClipboardColor.parse(string)
    }

    /// The most specific kind for a text payload. Ambiguous content stays
    /// `.text`; the caller may still force a kind via "Treat As".
    public static func classify(text: String?) -> SmartClipboardKind {
        guard let text, !text.isEmpty else { return .text }
        if isURL(text) { return .url }
        if isJSON(text) { return .json }
        if parseColor(text) != nil { return .color }
        return .text
    }

    /// The most specific kind for a full snapshot. Files and images win over
    /// their co-published text representations, matching Clipboard History's
    /// priority.
    public static func classify(
        text: String?,
        fileURLs: [URL],
        imageData: Data?,
        colorHex: String?
    ) -> SmartClipboardKind {
        if !fileURLs.isEmpty { return .files }
        if imageData != nil { return .image }
        if colorHex != nil { return .color }
        return classify(text: text)
    }
}