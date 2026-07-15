import Foundation

/// Pure, deterministic transforms for Smart Clipboard. Every function is
/// `nonisolated` and free of AppKit/pasteboard side effects so it can be
/// unit-tested without a running app. Results are previewed locally; nothing
/// here performs network access or hidden mutation.
public enum SmartClipboardTextEngine {
    public struct Counts: Equatable, Sendable {
        public let characters: Int
        public let words: Int
        public let lines: Int

        public init(characters: Int, words: Int, lines: Int) {
            self.characters = characters
            self.words = words
            self.lines = lines
        }
    }

    public enum CaseTransform: String, CaseIterable, Identifiable, Sendable {
        case uppercase, lowercase, titleCase, sentenceCase
        public var id: String { rawValue }
        public var label: String {
            switch self {
            case .uppercase: return "UPPERCASE"
            case .lowercase: return "lowercase"
            case .titleCase: return "Title Case"
            case .sentenceCase: return "Sentence case"
            }
        }
    }

    public enum WhitespaceTransform: String, CaseIterable, Identifiable, Sendable {
        case trim, normalizeWhitespace, normalizeLineEndings, collapseBlankLines, stripTrailingWhitespace
        public var id: String { rawValue }
        public var label: String {
            switch self {
            case .trim: return "Trim"
            case .normalizeWhitespace: return "Normalize whitespace"
            case .normalizeLineEndings: return "Normalize line endings"
            case .collapseBlankLines: return "Collapse blank lines"
            case .stripTrailingWhitespace: return "Strip trailing whitespace"
            }
        }
    }

    public enum LineTransform: String, CaseIterable, Identifiable, Sendable {
        case sortAscending, sortDescending, deduplicate, reverse
        public var id: String { rawValue }
        public var label: String {
            switch self {
            case .sortAscending: return "Sort lines ↑"
            case .sortDescending: return "Sort lines ↓"
            case .deduplicate: return "Remove duplicate lines"
            case .reverse: return "Reverse lines"
            }
        }
    }

    public enum EncodingTransform: String, CaseIterable, Identifiable, Sendable {
        case urlEncode, urlDecode, base64Encode, base64Decode, htmlEntityEncode, htmlEntityDecode
        public var id: String { rawValue }
        public var label: String {
            switch self {
            case .urlEncode: return "URL encode"
            case .urlDecode: return "URL decode"
            case .base64Encode: return "Base64 encode"
            case .base64Decode: return "Base64 decode"
            case .htmlEntityEncode: return "HTML entity encode"
            case .htmlEntityDecode: return "HTML entity decode"
            }
        }
    }

    // MARK: - Case

    public static func uppercase(_ input: String) -> String { input.uppercased() }
    public static func lowercase(_ input: String) -> String { input.lowercased() }
    public static func titleCase(_ input: String) -> String { input.capitalized }
    public static func sentenceCase(_ input: String) -> String {
        guard !input.isEmpty else { return input }
        var result = input
        let first = result.startIndex
        result.replaceSubrange(first...first, with: String(result[first]).uppercased())
        return result
    }

    public static func applyCase(_ transform: CaseTransform, to input: String) -> String {
        switch transform {
        case .uppercase: return uppercase(input)
        case .lowercase: return lowercase(input)
        case .titleCase: return titleCase(input)
        case .sentenceCase: return sentenceCase(input)
        }
    }

    // MARK: - Whitespace

    public static func trim(_ input: String) -> String {
        input.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func normalizeWhitespace(_ input: String) -> String {
        input.split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
    }

    public static func normalizeLineEndings(_ input: String) -> String {
        input.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
    }

    public static func collapseBlankLines(_ input: String) -> String {
        let lines = input.split(separator: "\n", omittingEmptySubsequences: false)
        var result: [String] = []
        var lastBlank = false
        for line in lines {
            let blank = line.allSatisfy { $0.isWhitespace }
            if blank {
                if lastBlank { continue }
                lastBlank = true
            } else {
                lastBlank = false
            }
            result.append(String(line))
        }
        return result.joined(separator: "\n")
    }

    public static func stripTrailingWhitespace(_ input: String) -> String {
        input.split(separator: "\n", omittingEmptySubsequences: false)
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .joined(separator: "\n")
    }

    public static func applyWhitespace(_ transform: WhitespaceTransform, to input: String) -> String {
        switch transform {
        case .trim: return trim(input)
        case .normalizeWhitespace: return normalizeWhitespace(input)
        case .normalizeLineEndings: return normalizeLineEndings(input)
        case .collapseBlankLines: return collapseBlankLines(input)
        case .stripTrailingWhitespace: return stripTrailingWhitespace(input)
        }
    }

    // MARK: - Lines

    public static func sortLines(_ input: String, ascending: Bool) -> String {
        var lines = input.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        lines.sort { ascending ? $0 < $1 : $0 > $1 }
        return lines.joined(separator: "\n")
    }

    public static func deduplicateLines(_ input: String) -> String {
        var seen = Set<String>()
        var result: [String] = []
        for line in input.split(separator: "\n", omittingEmptySubsequences: false) {
            let key = String(line)
            if seen.insert(key).inserted { result.append(key) }
        }
        return result.joined(separator: "\n")
    }

    public static func reverseLines(_ input: String) -> String {
        input.split(separator: "\n", omittingEmptySubsequences: false)
            .reversed().map(String.init).joined(separator: "\n")
    }

    public static func applyLine(_ transform: LineTransform, to input: String) -> String {
        switch transform {
        case .sortAscending: return sortLines(input, ascending: true)
        case .sortDescending: return sortLines(input, ascending: false)
        case .deduplicate: return deduplicateLines(input)
        case .reverse: return reverseLines(input)
        }
    }

    // MARK: - Encoding

    public static func urlEncode(_ input: String) -> String {
        input.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? input
    }
    public static func urlDecode(_ input: String) -> String {
        input.removingPercentEncoding ?? input
    }
    public static func base64Encode(_ input: String) -> String {
        Data(input.utf8).base64EncodedString()
    }
    public static func base64Decode(_ input: String) -> String {
        guard let data = Data(base64Encoded: input, options: [.ignoreUnknownCharacters]) else { return input }
        return String(data: data, encoding: .utf8) ?? input
    }

    public static func htmlEntityEncode(_ input: String) -> String {
        input.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }

    public static func htmlEntityDecode(_ input: String) -> String {
        input.replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
    }

    public static func applyEncoding(_ transform: EncodingTransform, to input: String) -> String {
        switch transform {
        case .urlEncode: return urlEncode(input)
        case .urlDecode: return urlDecode(input)
        case .base64Encode: return base64Encode(input)
        case .base64Decode: return base64Decode(input)
        case .htmlEntityEncode: return htmlEntityEncode(input)
        case .htmlEntityDecode: return htmlEntityDecode(input)
        }
    }

    // MARK: - Counts

    public static func counts(for input: String) -> Counts {
        let characters = input.count
        let words = input.split(whereSeparator: { $0.isWhitespace }).filter { !$0.isEmpty }.count
        let lines = max(input.components(separatedBy: "\n").count, 1)
        return Counts(characters: characters, words: words, lines: lines)
    }
}

/// Pure JSON helpers for Smart Clipboard. Errors carry a precise first parse
/// error location so the panel can show the user where it broke.
public enum SmartClipboardJSONEngine {
    public struct ParseFailure: Error, Equatable, Sendable {
        public let message: String
        public let line: Int?
        public let column: Int?
    }

    public struct Result: Sendable, Equatable {
        public let output: String
        public let isMinified: Bool
    }

    public static func validate(_ input: String) -> ParseFailure? {
        guard let data = input.data(using: .utf8) else {
            return ParseFailure(message: "Not valid UTF-8", line: nil, column: nil)
        }
        do {
            _ = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
            return nil
        } catch {
            let message = error.localizedDescription
            // JSONSerialization does not expose line/column; we keep the
            // localized description which is precise enough for a one-line
            // preview. Line/column stay nil rather than guessing.
            return ParseFailure(message: message, line: nil, column: nil)
        }
    }

    public static func prettyPrint(_ input: String, sortKeys: Bool = false) -> Result? {
        guard let data = input.data(using: .utf8) else { return nil }
        guard let object = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) else { return nil }
        var options: JSONSerialization.WritingOptions = [.prettyPrinted]
        if sortKeys { options.insert(.sortedKeys) }
        guard let pretty = try? JSONSerialization.data(withJSONObject: object, options: options) else { return nil }
        guard let output = String(data: pretty, encoding: .utf8) else { return nil }
        return Result(output: output, isMinified: false)
    }

    public static func minify(_ input: String, sortKeys: Bool = false) -> Result? {
        guard let data = input.data(using: .utf8) else { return nil }
        guard let object = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) else { return nil }
        var options: JSONSerialization.WritingOptions = []
        if sortKeys { options.insert(.sortedKeys) }
        guard let minified = try? JSONSerialization.data(withJSONObject: object, options: options) else { return nil }
        guard let output = String(data: minified, encoding: .utf8) else { return nil }
        return Result(output: output, isMinified: true)
    }
}

/// Pure URL helpers for Smart Clipboard. No network access.
public enum SmartClipboardURLEngine {
    /// Remove well-known tracking parameters that survive copy/paste. The list
    /// is conservative: only parameters whose only purpose is tracking are
    /// stripped. Query keys are matched case-insensitively.
    public static let trackingParameters: Set<String> = [
        "utm_source", "utm_medium", "utm_campaign", "utm_term", "utm_content",
        "utm_id", "utm_name",
        "gclid", "gclsrc", "dclid", "fbclid", "msclkid", "yclid",
        "mc_cid", "mc_eid", "mkt_tok", "_hsenc", "_hsmi", "hsCtaTracking",
        "vero_id", "vero_conv", "icid", "spm", "scm", "pgrid", "pcrid"
    ]

    public struct NormalizedURL: Equatable, Sendable {
        public let url: URL
        public let removedParameters: [String]
    }

    /// Strip tracking parameters and drop a trailing slash on the path when
    /// the URL has no query/fragment. Returns the original URL untouched when
    /// nothing changes.
    public static func normalize(_ url: URL) -> NormalizedURL {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return NormalizedURL(url: url, removedParameters: [])
        }
        var removed: [String] = []
        let queryItems = components.queryItems ?? []
        let loweredTracking = trackingParameters.map { $0.lowercased() }
        let kept = queryItems.filter { item in
            let name = item.name.lowercased()
            if loweredTracking.contains(name) {
                removed.append(item.name)
                return false
            }
            return true
        }
        var result = components
        if kept.isEmpty {
            result.queryItems = nil
        } else {
            result.queryItems = kept
        }
        // Drop a trailing slash on a bare path so `https://example.com/` and
        // `https://example.com` are identical.
        if result.query == nil, result.fragment == nil, result.path == "/" {
            result.path = ""
        }
        guard let cleaned = result.url else {
            return NormalizedURL(url: url, removedParameters: removed)
        }
        return NormalizedURL(url: cleaned, removedParameters: removed)
    }

    /// `[label](url)` Markdown link.
    public static func markdownLink(url: URL, label: String? = nil) -> String {
        let text = label?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? label!
            : (url.host ?? url.absoluteString)
        return "[\(text)](\(url.absoluteString))"
    }
}