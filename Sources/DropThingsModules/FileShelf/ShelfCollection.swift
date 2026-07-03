import Foundation

/// A named group of shelf items. The shelf holds an ordered list of
/// collections; one is active at a time (the one the user is looking at).
/// Identity is a stable UUID string so renaming a collection never breaks
/// references or persistence.
public struct ShelfCollection: Identifiable, Hashable, Sendable, Codable {
    public static let defaultName = "Shelf"

    public let id: String
    public var name: String
    public var items: [FileShelfItem]
    public let createdAt: Date

    public init(
        id: String = UUID().uuidString,
        name: String = ShelfCollection.defaultName,
        items: [FileShelfItem] = [],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.items = items
        self.createdAt = createdAt
    }

    /// A freshly-named collection for the "+" action in the tab bar.
    public static func newDefault(existingNames: [String]) -> ShelfCollection {
        ShelfCollection(name: Self.uniqueDefaultName(existingNames: existingNames))
    }

    /// "Shelf", "Shelf 2", "Shelf 3" … picking the first unused candidate so
    /// the user never sees two identically-named defaults.
    static func uniqueDefaultName(existingNames: [String]) -> String {
        let taken = Set(existingNames)
        if !taken.contains(defaultName) { return defaultName }
        var index = 2
        while taken.contains("\(defaultName) \(index)") {
            index += 1
        }
        return "\(defaultName) \(index)"
    }
}
