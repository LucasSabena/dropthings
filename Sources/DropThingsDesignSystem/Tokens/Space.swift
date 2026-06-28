import SwiftUI

/// Spacing scale. Mirrors `docs/design-system.md` and `design-tokens.json`.
public enum DTSpace {
    public static let xxs: CGFloat = 2
    public static let xs: CGFloat = 4
    public static let sm: CGFloat = 8
    public static let md: CGFloat = 12
    public static let lg: CGFloat = 16
    public static let xl: CGFloat = 24
    public static let xxl: CGFloat = 32
}

public enum DTRadius {
    public static let xs: CGFloat = 3
    public static let sm: CGFloat = 4
    public static let md: CGFloat = 6
    public static let lg: CGFloat = 8
}

public enum DTSize {
    public static let sidebarWidth: CGFloat = 220
    public static let settingsMinWidth: CGFloat = 760
    public static let settingsMinHeight: CGFloat = 520
    public static let iconButton: CGFloat = 28
}
