import Foundation

/// Persistent named text snippet. Separate from clipboard history: these are
/// user-curated pieces of text invoked on demand from the snippets picker or
/// the Command Palette.
public struct Snippet: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public var title: String
    public var content: String
    public var keyword: String?

    public init(
        id: UUID = UUID(),
        title: String,
        content: String,
        keyword: String? = nil
    ) {
        self.id = id
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.content = content
        self.keyword = Self.normalizedKeyword(keyword)
    }

    enum CodingKeys: String, CodingKey {
        case id, title, content, keyword
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        self.content = try container.decodeIfPresent(String.self, forKey: .content) ?? ""
        self.keyword = try container.decodeIfPresent(String.self, forKey: .keyword)
    }

    /// A snippet is considered empty when it has no title and no usable
    /// content. Empty snippets are dropped on save so the picker never shows
    /// blank rows.
    public var isEmpty: Bool {
        title.isEmpty && content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// One-line preview for lists and the Command Palette subtitle.
    public var contentPreview: String {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let singleLine = trimmed.replacingOccurrences(of: "\n", with: " ")
        if singleLine.count > 120 {
            return String(singleLine.prefix(120)) + "…"
        }
        return singleLine
    }

    public static func normalizedKeyword(_ keyword: String?) -> String? {
        guard let keyword else { return nil }
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let collapsed = trimmed.components(separatedBy: .whitespacesAndNewlines).joined()
        return collapsed.lowercased()
    }
}
