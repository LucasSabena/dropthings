import Foundation

public enum PaletteResultKind: String, Codable, CaseIterable, Sendable {
    case application
    case command
    case file
    case folder
    case calculation
    case systemAction
    case webSearch

    public var displayName: String {
        switch self {
        case .application: return "Application"
        case .command: return "Command"
        case .file: return "File"
        case .folder: return "Folder"
        case .calculation: return "Calculation"
        case .systemAction: return "System action"
        case .webSearch: return "Web search"
        }
    }
}

public enum PaletteIcon: Hashable, Sendable {
    case system(String)
    case file(URL, isDirectory: Bool)
    case application(URL)
}

public enum PaletteActionRole: String, Sendable {
    case primary
    case alternate
    case copy
    case preview
}

public struct PaletteAction: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let symbolName: String
    public let shortcutHint: String?
    public let role: PaletteActionRole
    public let perform: @MainActor @Sendable () async throws -> Void

    public init(
        id: String,
        title: String,
        symbolName: String,
        shortcutHint: String? = nil,
        role: PaletteActionRole = .alternate,
        perform: @escaping @MainActor @Sendable () async throws -> Void
    ) {
        self.id = id
        self.title = title
        self.symbolName = symbolName
        self.shortcutHint = shortcutHint
        self.role = role
        self.perform = perform
    }
}

public struct PaletteResult: Identifiable, Sendable {
    public let id: String
    public let kind: PaletteResultKind
    public let title: String
    public let subtitle: String?
    public let aliases: [String]
    public let icon: PaletteIcon
    public let providerPriority: Double
    public let providerRelevance: Double
    public let actions: [PaletteAction]
    let searchCandidates: [PaletteSearchCandidate]
    let normalizedTitle: String

    public init(
        id: String,
        kind: PaletteResultKind,
        title: String,
        subtitle: String? = nil,
        aliases: [String] = [],
        icon: PaletteIcon,
        providerPriority: Double,
        providerRelevance: Double = 0,
        actions: [PaletteAction]
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.subtitle = subtitle
        self.aliases = aliases
        self.icon = icon
        self.providerPriority = providerPriority
        self.providerRelevance = providerRelevance
        self.actions = actions
        let candidateValues = [title, subtitle ?? ""] + aliases
        self.searchCandidates = candidateValues.filter { !$0.isEmpty }.map(PaletteSearchCandidate.init)
        self.normalizedTitle = PaletteSearchText.normalize(title)
    }

    public var primaryAction: PaletteAction? {
        actions.first(where: { $0.role == .primary }) ?? actions.first
    }
}

struct PaletteSearchCandidate: Sendable {
    let text: String
    let tokens: [String]
    let initials: String

    init(_ source: String) {
        text = PaletteSearchText.normalize(source)
        tokens = PaletteSearchText.tokens(text)
        initials = String(tokens.compactMap(\.first))
    }
}

enum PaletteSearchText {
    static func normalize(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
    }

    static func tokens(_ value: String) -> [String] {
        value.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
    }
}

public struct RankedPaletteResult: Identifiable, Sendable {
    public let result: PaletteResult
    public let score: Double
    public var id: String { result.id }
}
