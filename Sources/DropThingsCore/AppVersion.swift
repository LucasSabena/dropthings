import Foundation

/// Numeric app version comparison for release tags such as `0.1.2` or
/// `v0.1.2`. This intentionally ignores build metadata and prerelease labels
/// because DropThings only publishes stable GitHub releases for users.
public struct AppVersion: Comparable, Hashable, Sendable {
    public let rawValue: String
    private let components: [Int]

    public init(_ rawValue: String) {
        self.rawValue = rawValue
        self.components = Self.normalizedComponents(from: rawValue)
    }

    public static func == (lhs: AppVersion, rhs: AppVersion) -> Bool {
        compare(lhs.components, rhs.components) == .orderedSame
    }

    public static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        compare(lhs.components, rhs.components) == .orderedAscending
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(components)
    }

    private static func normalizedComponents(from rawValue: String) -> [Int] {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let withoutPrefix = trimmed.drop { $0 == "v" || $0 == "V" }
        let core = withoutPrefix
            .split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false)[0]
            .split(separator: "+", maxSplits: 1, omittingEmptySubsequences: false)[0]
        var values = core
            .split(separator: ".", omittingEmptySubsequences: false)
            .map { component -> Int in
                let digits = component.prefix { $0.isNumber }
                return Int(digits) ?? 0
            }
        while values.count > 1, values.last == 0 {
            values.removeLast()
        }
        return values.isEmpty ? [0] : values
    }

    private static func compare(_ lhs: [Int], _ rhs: [Int]) -> ComparisonResult {
        let count = max(lhs.count, rhs.count)
        for index in 0..<count {
            let left = index < lhs.count ? lhs[index] : 0
            let right = index < rhs.count ? rhs[index] : 0
            if left < right { return .orderedAscending }
            if left > right { return .orderedDescending }
        }
        return .orderedSame
    }
}
