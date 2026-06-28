import SwiftUI
import AppKit

/// Semantic colors mapped to AppKit semantic colors so they follow Light /
/// Dark / Increase Contrast / Reduce Transparency automatically. Brand-tinted
/// assets (Accent / Success / Warning / Danger) can be added later inside the
/// App target if we need them; for Phase 0 we rely on macOS system colors
/// which already match platform expectations.
public enum DTColor {
    public static var accent: Color {
        Color(nsColor: .controlAccentColor)
    }

    public static var background: Color {
        Color(nsColor: .windowBackgroundColor)
    }

    public static var surface: Color {
        Color(nsColor: .controlBackgroundColor)
    }

    public static var surfaceRaised: Color {
        Color(nsColor: .textBackgroundColor)
    }

    public static var border: Color {
        Color(nsColor: .separatorColor)
    }

    public static var textPrimary: Color {
        Color(nsColor: .labelColor)
    }

    public static var textSecondary: Color {
        Color(nsColor: .secondaryLabelColor)
    }

    public static var success: Color {
        Color(nsColor: .systemGreen)
    }

    public static var warning: Color {
        Color(nsColor: .systemOrange)
    }

    public static var danger: Color {
        Color(nsColor: .systemRed)
    }
}
