import SwiftUI

public enum InlineAlertStyle {
    case info
    case warning
    case error
    case success
}

/// Compact one-line message used inside module detail pages. Not a banner —
/// keep copy short and action-oriented.
public struct InlineAlert: View {
    public let style: InlineAlertStyle
    public let message: String

    public init(style: InlineAlertStyle, message: String) {
        self.style = style
        self.message = message
    }

    public var body: some View {
        HStack(alignment: .top, spacing: DTSpace.sm) {
            Image(systemName: iconName)
                .foregroundStyle(color)
            Text(message)
                .font(DTTypography.caption)
                .foregroundStyle(DTColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(DTSpace.sm)
        .background(color.opacity(0.12))
        .overlay(
            RoundedRectangle(cornerRadius: DTRadius.sm, style: .continuous)
                .strokeBorder(color.opacity(0.4), lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: DTRadius.sm, style: .continuous))
    }

    private var iconName: String {
        switch style {
        case .info: return "info.circle"
        case .warning: return "exclamationmark.triangle"
        case .error: return "xmark.octagon"
        case .success: return "checkmark.circle"
        }
    }

    private var color: Color {
        switch style {
        case .info: return DTColor.accent
        case .warning: return DTColor.warning
        case .error: return DTColor.danger
        case .success: return DTColor.success
        }
    }
}
