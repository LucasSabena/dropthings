import SwiftUI

/// Typography preset names that map to the values in `docs/design-tokens.json`.
/// Use these instead of raw `Font.system(...)` so we can change the scale in
/// one place.
public enum DTTypography {
    /// Settings window title (≈ 20 pt semibold).
    public static var windowTitle: Font {
        .system(size: 20, weight: .semibold)
    }

    /// Section title (≈ 13 pt semibold).
    public static var sectionTitle: Font {
        .system(size: 13, weight: .semibold)
    }

    /// Body (≈ 13 pt regular).
    public static var body: Font {
        .system(size: 13, weight: .regular)
    }

    /// Caption / help (≈ 11 pt regular).
    public static var caption: Font {
        .system(size: 11, weight: .regular)
    }

    public static var monospacedBody: Font {
        .system(size: 12, weight: .regular, design: .monospaced)
    }

    /// Large glyph used as an empty-state tray illustration (≈ 28 pt).
    public static var emptyStateGlyph: Font {
        .system(size: 28)
    }

    /// Small badge/icon overlay (≈ 9–10 pt semibold). Used for pin
    /// indicators and `xmark` remove buttons that sit on top of a row.
    public static var badgeLabel: Font {
        .system(size: 9, weight: .semibold)
    }

    public static var badgeButton: Font {
        .system(size: 10, weight: .semibold)
    }

    /// Module list row icon (≈ 16 pt medium). Used in the sidebar and the
    /// module detail header so the icon size stays consistent without a
    /// one-off literal at every call site.
    public static var moduleIcon: Font {
        .system(size: 16, weight: .medium)
    }

    /// Module detail header icon (≈ 28 pt medium). Sits next to the
    /// module name in the detail pane.
    public static var moduleHeaderIcon: Font {
        .system(size: 28, weight: .medium)
    }
}
