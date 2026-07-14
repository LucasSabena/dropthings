import SwiftUI

/// Canonical DropThings spacing and radius scale. Product UI must reuse these values.
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
    public static let md: CGFloat = 8
    public static let lg: CGFloat = 12
}

public enum DTSize {
    public static let sidebarWidth: CGFloat = 224
    public static let settingsMinWidth: CGFloat = 900
    public static let settingsMinHeight: CGFloat = 620
    public static let contentMaxWidth: CGFloat = 720
    public static let moduleHeaderIcon: CGFloat = 48
    public static let sidebarIcon: CGFloat = 18
    public static let iconButton: CGFloat = 28
    public static let permissionIcon: CGFloat = 36
    public static let utilityIcon: CGFloat = 40
    public static let statusDot: CGFloat = 7
    public static let permissionSheetWidth: CGFloat = 460
    public static let aboutIcon: CGFloat = 64
    public static let previewSmall: CGFloat = 36
    public static let previewMedium: CGFloat = 64
    public static let previewLarge: CGFloat = 120
    public static let colorFeedbackWidth: CGFloat = 220
    public static let colorFeedbackHeight: CGFloat = 64
    public static let shelfInspectorWidth: CGFloat = 288
    public static let markdownViewerWidth: CGFloat = 960
    public static let markdownViewerHeight: CGFloat = 640
    public static let moduleMenuBarWidth: CGFloat = 480
    public static let moduleMenuBarHeight: CGFloat = 520
    public static let moduleMenuBarFooterHeight: CGFloat = 44
    public static let compactMessageWidth: CGFloat = 300
}
