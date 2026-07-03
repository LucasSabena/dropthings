import Foundation

/// Pure ordering for shelf items so the view, the selection range logic,
/// and the anchor semantics all agree on what "display order" means.
/// Pinned items come first, then by `addedAt` ascending (oldest first).
enum ShelfDisplayOrder {
    static func sort(_ items: [FileShelfItem]) -> [FileShelfItem] {
        items.sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned { return lhs.isPinned }
            return lhs.addedAt < rhs.addedAt
        }
    }
}
