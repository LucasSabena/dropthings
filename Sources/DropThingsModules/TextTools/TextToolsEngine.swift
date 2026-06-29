import Foundation

/// Pure text transformations used by the Text Tools module. Every function is
/// `nonisolated` and free of AppKit / pasteboard side effects so it can be
/// unit-tested without a running app.
public enum TextToolsEngine {
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

    public enum Transform: String, CaseIterable, Identifiable, Sendable {
        case uppercase
        case lowercase
        case titleCase
        case camelCase
        case snakeCase
        case urlEncode
        case urlDecode
        case jsonPretty
        case jsonMinify
        case base64Encode
        case base64Decode
        case sortLines
        case removeDuplicateLines

        public var id: String { rawValue }

        public var label: String {
            switch self {
            case .uppercase: return "Uppercase"
            case .lowercase: return "Lowercase"
            case .titleCase: return "Title Case"
            case .camelCase: return "camelCase"
            case .snakeCase: return "snake_case"
            case .urlEncode: return "URL Encode"
            case .urlDecode: return "URL Decode"
            case .jsonPretty: return "JSON Pretty"
            case .jsonMinify: return "JSON Minify"
            case .base64Encode: return "Base64 Encode"
            case .base64Decode: return "Base64 Decode"
            case .sortLines: return "Sort Lines"
            case .removeDuplicateLines: return "Remove Duplicates"
            }
        }

        public var systemImage: String {
            switch self {
            case .uppercase: return "textformat.uppercase"
            case .lowercase: return "textformat.lowercase"
            case .titleCase: return "textformat.title"
            case .camelCase: return "textformat.abc"
            case .snakeCase: return "textformat.abc.dottedunderline"
            case .urlEncode: return "link"
            case .urlDecode: return "link.badge.plus"
            case .jsonPretty: return "curlybraces"
            case .jsonMinify: return "curlybraces.square"
            case .base64Encode: return "number"
            case .base64Decode: return "number.square"
            case .sortLines: return "arrow.up.arrow.down"
            case .removeDuplicateLines: return "line.3.horizontal.decrease"
            }
        }
    }

    // MARK: - Case conversion

    public static func uppercase(_ input: String) -> String {
        input.uppercased()
    }

    public static func lowercase(_ input: String) -> String {
        input.lowercased()
    }

    public static func titleCase(_ input: String) -> String {
        input.capitalized
    }

    /// Converts arbitrary text into `camelCase`. Words are split on whitespace,
    /// underscores, hyphens, and dots. Empty input stays empty.
    public static func camelCase(_ input: String) -> String {
        let words = words(from: input)
        guard let first = words.first else { return "" }
        let rest = words.dropFirst().map { $0.capitalized }
        return first.lowercased() + rest.joined()
    }

    /// Converts arbitrary text into `snake_case`. Words are split on whitespace,
    /// underscores, hyphens, dots, and camel-case boundaries. Empty input stays empty.
    public static func snakeCase(_ input: String) -> String {
        let words = words(from: input, preserveCamelBoundaries: true)
        return words.map { $0.lowercased() }.joined(separator: "_")
    }

    // MARK: - URL encoding

    public static func urlEncode(_ input: String) -> String {
        input.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? input
    }

    public static func urlDecode(_ input: String) -> String {
        input.removingPercentEncoding ?? input
    }

    // MARK: - JSON formatting

    public static func jsonPretty(_ input: String) -> String {
        guard let data = input.data(using: .utf8) else { return input }
        do {
            let object = try JSONSerialization.jsonObject(with: data)
            let pretty = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
            return String(data: pretty, encoding: .utf8) ?? input
        } catch {
            return input
        }
    }

    public static func jsonMinify(_ input: String) -> String {
        guard let data = input.data(using: .utf8) else { return input }
        do {
            let object = try JSONSerialization.jsonObject(with: data)
            let minified = try JSONSerialization.data(withJSONObject: object)
            return String(data: minified, encoding: .utf8) ?? input
        } catch {
            return input
        }
    }

    // MARK: - Base64

    public static func base64Encode(_ input: String) -> String {
        Data(input.utf8).base64EncodedString()
    }

    public static func base64Decode(_ input: String) -> String {
        guard let data = Data(base64Encoded: input, options: [.ignoreUnknownCharacters]) else {
            return input
        }
        return String(data: data, encoding: .utf8) ?? input
    }

    // MARK: - Line operations

    public static func sortLines(_ input: String) -> String {
        let lines = input.split(separator: "\n", omittingEmptySubsequences: false)
        return lines.sorted().joined(separator: "\n")
    }

    public static func removeDuplicateLines(_ input: String) -> String {
        let lines = input.split(separator: "\n", omittingEmptySubsequences: false)
        var seen = Set<String>()
        var result: [String] = []
        for line in lines {
            let key = String(line)
            if seen.insert(key).inserted {
                result.append(key)
            }
        }
        return result.joined(separator: "\n")
    }

    // MARK: - Counts

    public static func counts(for input: String) -> Counts {
        let characters = input.count
        let words = input.split(whereSeparator: \.isWhitespace).filter { !$0.isEmpty }.count
        let lines = max(input.components(separatedBy: "\n").count, 1)
        return Counts(characters: characters, words: words, lines: lines)
    }

    // MARK: - Dispatch

    /// Applies the selected transform. Returns the original input when the
    /// transform cannot be performed (e.g. invalid JSON or Base64).
    public static func apply(_ transform: Transform, to input: String) -> String {
        switch transform {
        case .uppercase: return uppercase(input)
        case .lowercase: return lowercase(input)
        case .titleCase: return titleCase(input)
        case .camelCase: return camelCase(input)
        case .snakeCase: return snakeCase(input)
        case .urlEncode: return urlEncode(input)
        case .urlDecode: return urlDecode(input)
        case .jsonPretty: return jsonPretty(input)
        case .jsonMinify: return jsonMinify(input)
        case .base64Encode: return base64Encode(input)
        case .base64Decode: return base64Decode(input)
        case .sortLines: return sortLines(input)
        case .removeDuplicateLines: return removeDuplicateLines(input)
        }
    }

    // MARK: - Internal helpers

    /// Splits text into words. When `preserveCamelBoundaries` is `true`,
    /// uppercase letters that start a new word are split into separate tokens
    /// so `snakeCase` can insert underscores at camel boundaries.
    nonisolated static func words(from input: String, preserveCamelBoundaries: Bool = false) -> [String] {
        let separators = CharacterSet.whitespacesAndNewlines.union(.init(charactersIn: "_-.,/|:"))
        var tokens = input.components(separatedBy: separators).filter { !$0.isEmpty }

        guard preserveCamelBoundaries else { return tokens }

        var result: [String] = []
        for token in tokens {
            result.append(contentsOf: camelSplit(token))
        }
        return result.filter { !$0.isEmpty }
    }

    nonisolated static func camelSplit(_ input: String) -> [String] {
        var words: [String] = []
        var current = ""
        var previousWasUpper = false

        for character in input {
            let isUpper = character.isUppercase
            if isUpper {
                // Start a new word when we hit an uppercase letter, unless the
                // previous character was also uppercase (acronyms like "URL").
                if !current.isEmpty && !previousWasUpper {
                    words.append(current)
                    current = ""
                }
            }
            current.append(character)
            previousWasUpper = isUpper
        }
        if !current.isEmpty {
            words.append(current)
        }
        return words
    }
}
