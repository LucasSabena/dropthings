import SwiftUI
import DropThingsCore

/// One permission inside a module detail page. Shows the human name, why it
/// is needed, current state, and action buttons to either trigger the
/// system's native prompt (for Accessibility and Screen Recording) or open
/// System Settings manually.
public struct PermissionRow: View {
    public let permission: SystemPermission
    public let state: SystemPermissionState
    public let onOpenSettings: () -> Void
    public let onRequest: () -> Void

    public init(
        permission: SystemPermission,
        state: SystemPermissionState,
        onOpenSettings: @escaping () -> Void,
        onRequest: @escaping () -> Void = {}
    ) {
        self.permission = permission
        self.state = state
        self.onOpenSettings = onOpenSettings
        self.onRequest = onRequest
    }

    public var body: some View {
        HStack(alignment: .center, spacing: DTSpace.md) {
            Image(systemName: permission.iconName)
                .font(DTTypography.moduleIcon)
                .foregroundStyle(state == .granted ? DTColor.success : DTColor.accent)
                .frame(width: DTSize.permissionIcon, height: DTSize.permissionIcon)
                .background(DTColor.surfaceRaised)
                .clipShape(RoundedRectangle(cornerRadius: DTRadius.md, style: .continuous))

            VStack(alignment: .leading, spacing: DTSpace.xxs) {
                Text(permission.displayName)
                    .font(DTTypography.body.weight(.semibold))
                    .foregroundStyle(DTColor.textPrimary)
                Text(permission.reason)
                    .font(DTTypography.caption)
                    .foregroundStyle(DTColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: DTSpace.md)

            VStack(alignment: .trailing, spacing: DTSpace.xs) {
                stateLabel
                if state != .granted {
                    HStack(spacing: DTSpace.xs) {
                        if permission.supportsSystemPrompt && state == .notDetermined {
                            Button("Continue", action: onRequest)
                                .controlSize(.small)
                                .buttonStyle(.borderedProminent)
                        } else {
                            Button("Open System Settings", action: onOpenSettings)
                                .controlSize(.small)
                        }
                    }
                }
            }
        }
        .padding(.vertical, DTSpace.sm)
    }

    private var stateLabel: some View {
        Label(state.displayName, systemImage: state == .granted ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
            .font(DTTypography.caption.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, DTSpace.sm)
            .padding(.vertical, DTSpace.xxs)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
    }

    private var color: Color {
        switch state {
        case .granted: return DTColor.success
        case .denied: return DTColor.danger
        case .notDetermined: return DTColor.warning
        case .unknown: return DTColor.textSecondary
        }
    }

}
