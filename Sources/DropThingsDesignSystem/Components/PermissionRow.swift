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
        HStack(alignment: .top, spacing: DTSpace.md) {
            VStack(alignment: .leading, spacing: DTSpace.xxs) {
                Text(permission.displayName)
                    .font(DTTypography.body.weight(.semibold))
                    .foregroundStyle(DTColor.textPrimary)
                Text(permission.reason)
                    .font(DTTypography.caption)
                    .foregroundStyle(DTColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                if showsManualInstructions {
                    Text(manualInstructions)
                        .font(DTTypography.caption)
                        .foregroundStyle(DTColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: DTSpace.md)

            VStack(alignment: .trailing, spacing: DTSpace.xs) {
                stateLabel
                HStack(spacing: DTSpace.xs) {
                    if permission.supportsSystemPrompt {
                        Button("Request Access") { onRequest() }
                            .controlSize(.small)
                            .disabled(state == .granted)
                    }
                    Button(permission.supportsSystemPrompt ? "Open Settings…" : "Open Settings…",
                           action: onOpenSettings)
                        .controlSize(.small)
                        .disabled(state == .unknown)
                }
            }
        }
        .padding(.vertical, DTSpace.xs)
    }

    private var stateLabel: some View {
        Text(label)
            .font(DTTypography.caption.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, DTSpace.sm)
            .padding(.vertical, DTSpace.xxs)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
    }

    private var label: String {
        switch state {
        case .granted: return "Granted"
        case .denied: return "Denied"
        case .notDetermined: return "Not granted"
        case .unknown: return "Unknown"
        }
    }

    private var color: Color {
        switch state {
        case .granted: return DTColor.success
        case .denied: return DTColor.danger
        case .notDetermined: return DTColor.warning
        case .unknown: return DTColor.textSecondary
        }
    }

    private var showsManualInstructions: Bool {
        permission == .accessibility && state == .notDetermined
    }

    private var manualInstructions: String {
        "If the prompt does not appear: System Settings → Privacy & Security → Accessibility → + → choose DropThings.app."
    }
}

private extension SystemPermission {
    /// `true` when macOS exposes a system-level prompt API we can trigger
    /// programmatically. Accessibility uses `AXIsProcessTrustedWithOptions`
    /// and Screen Recording uses `CGRequestScreenCaptureAccess`; the others
    /// only expose a System Settings pane.
    var supportsSystemPrompt: Bool {
        switch self {
        case .accessibility, .screenRecording: return true
        case .fullDiskAccess, .automation: return false
        }
    }
}
