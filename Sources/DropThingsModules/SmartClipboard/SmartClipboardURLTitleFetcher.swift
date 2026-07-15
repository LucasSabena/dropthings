import Foundation

/// Protocol for fetching an HTML page title. Default implementation hits the
/// network only when the user explicitly triggers the "Fetch page title"
/// action. Tests inject a deterministic fake.
public protocol SmartClipboardURLTitleFetching: Sendable {
    /// Returns the page `<title>`, or `nil` when none is found. Throws on
    /// transport errors so the caller can surface a precise message.
    func fetchTitle(url: URL) async throws -> String?
}

/// Network-backed fetcher. Uses `URLSession` with a short timeout and parses
/// only the `<title>` tag so we never render untrusted HTML.
public struct SystemURLTitleFetcher: SmartClipboardURLTitleFetching {
    public init() {}

    public func fetchTitle(url: URL) async throws -> String? {
        guard let scheme = url.scheme?.lowercased(), scheme == "https" || scheme == "http" else {
            throw URLError(.unsupportedURL)
        }
        var request = URLRequest(url: url, timeoutInterval: 8)
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X) DropThings/SmartClipboard",
            forHTTPHeaderField: "User-Agent"
        )
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        if let http = response as? HTTPURLResponse, !(200..<400).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
        let maximumBytes = 1_048_576
        var data = Data()
        data.reserveCapacity(min(response.expectedContentLength > 0 ? Int(response.expectedContentLength) : 16_384, maximumBytes))
        for try await byte in bytes {
            guard data.count < maximumBytes else { throw URLError(.dataLengthExceedsMaximum) }
            data.append(byte)
        }
        guard let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
            return nil
        }
        return Self.firstTitle(in: html)
    }

    /// Extract the first `<title>…</title>` content. Case-insensitive, ignores
    /// attributes on the tag, and trims whitespace. Pure so it can be tested
    /// without the network.
    public static func firstTitle(in html: String) -> String? {
        guard let openRange = html.range(of: "<title", options: .caseInsensitive) else { return nil }
        let afterOpen = html[openRange.upperBound...]
        guard let closeBracket = afterOpen.firstIndex(of: ">") else { return nil }
        let inner = html[html.index(after: closeBracket)...]
        guard let closeRange = inner.range(of: "</title>", options: .caseInsensitive) else { return nil }
        let title = String(inner[..<closeRange.lowerBound])
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
