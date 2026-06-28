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
}
