import Foundation

public enum PaletteRanker {
    public static func rank(
        _ results: [PaletteResult],
        query: String,
        historyScores: [String: Double] = [:],
        limit: Int = 80
    ) -> [RankedPaletteResult] {
        let normalizedQuery = normalize(query).trimmingCharacters(in: .whitespacesAndNewlines)
        let queryTokens = PaletteSearchText.tokens(normalizedQuery)
        let compactQuery = normalizedQuery.replacingOccurrences(of: " ", with: "")
        return results.compactMap { result -> RankedPaletteResult? in
            let match: Double
            if normalizedQuery.isEmpty {
                match = 0
            } else {
                let scores = result.searchCandidates.map {
                    matchScore(query: normalizedQuery, queryTokens: queryTokens, compactQuery: compactQuery, candidate: $0)
                }
                guard let best = scores.max(), best > 0 else { return nil }
                match = best
            }
            let history = min(max(historyScores[result.id] ?? 0, 0), 180)
            let total = result.providerPriority + result.providerRelevance + match + history
            return RankedPaletteResult(result: result, score: total)
        }
        .sorted {
            if $0.score != $1.score { return $0.score > $1.score }
            if $0.result.normalizedTitle != $1.result.normalizedTitle {
                return $0.result.normalizedTitle < $1.result.normalizedTitle
            }
            return $0.id < $1.id
        }
        .prefix(max(0, limit))
        .map { $0 }
    }

    public static func normalize(_ value: String) -> String {
        PaletteSearchText.normalize(value)
    }

    public static func matchScore(query: String, candidate: String) -> Double {
        let queryTokens = PaletteSearchText.tokens(query)
        return matchScore(
            query: query,
            queryTokens: queryTokens,
            compactQuery: query.replacingOccurrences(of: " ", with: ""),
            candidate: PaletteSearchCandidate(candidate)
        )
    }

    private static func matchScore(
        query: String,
        queryTokens: [String],
        compactQuery: String,
        candidate: PaletteSearchCandidate
    ) -> Double {
        let candidateText = candidate.text
        guard !query.isEmpty, !candidateText.isEmpty else { return 0 }
        if candidateText == query { return 1_000 }
        if candidateText.hasPrefix(query) { return 820 - Double(candidateText.count - query.count) * 0.1 }
        if !queryTokens.isEmpty,
           queryTokens.allSatisfy({ token in candidate.tokens.contains(where: { $0.hasPrefix(token) }) }) {
            return 650 + Double(queryTokens.count * 15)
        }
        if candidate.initials.hasPrefix(compactQuery) { return 590 }
        if let range = candidateText.range(of: query) {
            return 480 - Double(candidateText.distance(from: candidateText.startIndex, to: range.lowerBound))
        }
        return fuzzyScore(query: compactQuery, candidate: candidateText)
    }

    private static func fuzzyScore(query: String, candidate: String) -> Double {
        var candidateIndex = candidate.startIndex
        var gap = 0
        var matched = 0
        var previousMatch: String.Index?
        for character in query {
            guard let found = candidate[candidateIndex...].firstIndex(of: character) else { return 0 }
            if let previousMatch {
                gap += candidate.distance(from: candidate.index(after: previousMatch), to: found)
            } else {
                gap += candidate.distance(from: candidate.startIndex, to: found)
            }
            matched += 1
            previousMatch = found
            candidateIndex = candidate.index(after: found)
        }
        guard matched == query.count else { return 0 }
        return max(1, 330 - Double(gap * 9) - Double(candidate.count - query.count))
    }
}
