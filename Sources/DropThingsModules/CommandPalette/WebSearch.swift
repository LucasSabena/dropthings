import Foundation

public enum WebSearchEngine: String, Codable, CaseIterable, Sendable {
    case google
    case bing
    case duckDuckGo
    case brave
    case kagi

    public var displayName: String {
        switch self {
        case .google: return "Google"
        case .bing: return "Bing"
        case .duckDuckGo: return "DuckDuckGo"
        case .brave: return "Brave Search"
        case .kagi: return "Kagi"
        }
    }

    public func searchURL(for query: String) -> URL? {
        var components: URLComponents
        let itemName: String
        switch self {
        case .google: components = URLComponents(string: "https://www.google.com/search")!; itemName = "q"
        case .bing: components = URLComponents(string: "https://www.bing.com/search")!; itemName = "q"
        case .duckDuckGo: components = URLComponents(string: "https://duckduckgo.com/")!; itemName = "q"
        case .brave: components = URLComponents(string: "https://search.brave.com/search")!; itemName = "q"
        case .kagi: components = URLComponents(string: "https://kagi.com/search")!; itemName = "q"
        }
        components.queryItems = [URLQueryItem(name: itemName, value: query)]
        return components.url
    }
}
