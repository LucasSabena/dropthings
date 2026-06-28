import SwiftUI
import DropThingsCore

/// Tiny status badge used in module rows and headers. The label text comes
/// from `ModuleState.shortLabel`; color follows the severity of the state.
public struct ModuleStatusPill: View {
    public let state: ModuleState

    public init(state: ModuleState) {
        self.state = state
    }

    public var body: some View {
        Text(state.shortLabel)
            .font(DTTypography.caption.weight(.semibold))
            .foregroundStyle(foreground)
            .padding(.horizontal, DTSpace.sm)
            .padding(.vertical, DTSpace.xxs)
            .background(background)
            .clipShape(Capsule())
            .overlay(
                Capsule().strokeBorder(borderColor, lineWidth: 0.5)
            )
            .accessibilityLabel("Status: \(state.shortLabel)")
    }

    private var background: Color {
        switch state {
        case .running: return DTColor.success.opacity(0.15)
        case .off: return DTColor.surfaceRaised
        case .starting: return DTColor.accent.opacity(0.15)
        case .needsPermission: return DTColor.warning.opacity(0.18)
        case .unavailable, .degraded: return DTColor.textSecondary.opacity(0.18)
        case .failed: return DTColor.danger.opacity(0.18)
        }
    }

    private var foreground: Color {
        switch state {
        case .running: return DTColor.success
        case .off: return DTColor.textSecondary
        case .starting: return DTColor.accent
        case .needsPermission: return DTColor.warning
        case .unavailable, .degraded: return DTColor.textSecondary
        case .failed: return DTColor.danger
        }
    }

    private var borderColor: Color {
        foreground.opacity(0.35)
    }
}
