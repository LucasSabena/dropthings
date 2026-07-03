import Foundation

/// A named spacer that DropThings installs in the menu bar. Overflow dividers
/// widen when collapsed so the icons parked to their left slide off-screen;
/// visual dividers keep the same size and act as group separators.
public struct MenuBarCleanerDivider: Sendable, Equatable, Codable, Identifiable {
    public let id: UUID
    public var name: String
    public var symbolName: String
    public var expandedLength: CGFloat
    public var collapsedLength: CGFloat
    /// When `true`, this divider expands on collapse and hides the icons to
    /// its left. The main divider is always an overflow divider.
    public var isOverflow: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        symbolName: String = "line.vertical",
        expandedLength: CGFloat = 18,
        collapsedLength: CGFloat = 500,
        isOverflow: Bool = false
    ) {
        self.id = id
        self.name = name
        self.symbolName = symbolName
        self.expandedLength = expandedLength
        self.collapsedLength = collapsedLength
        self.isOverflow = isOverflow
    }

    public static let defaultMain = MenuBarCleanerDivider(
        id: Self.mainID,
        name: "Main overflow",
        symbolName: "line.vertical",
        expandedLength: 18,
        collapsedLength: 500,
        isOverflow: true
    )

    public static let mainID = UUID(uuidString: "00000000-0000-0000-0000-000000000100")!
}
