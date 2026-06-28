import SwiftUI
import DropThingsCore

/// Compact row used in the module sidebar. Icon + name + status pill +
/// enable toggle, on a single line. Keep this dense; this is the most
/// repeated element in the app.
public struct ModuleRow: View {
    public let module: any DropThingsModule
    public let state: ModuleState
    public let isEnabled: Bool
    public let onToggle: (Bool) -> Void

    public init(
        module: any DropThingsModule,
        state: ModuleState,
        isEnabled: Bool,
        onToggle: @escaping (Bool) -> Void
    ) {
        self.module = module
        self.state = state
        self.isEnabled = isEnabled
        self.onToggle = onToggle
    }

    public var body: some View {
        HStack(spacing: DTSpace.md) {
            Image(systemName: module.iconName)
                .font(DTTypography.moduleIcon)
                .foregroundStyle(DTColor.accent)
                .frame(width: DTSize.iconButton, height: DTSize.iconButton)
                .background(DTColor.surfaceRaised)
                .clipShape(RoundedRectangle(cornerRadius: DTRadius.md, style: .continuous))

            VStack(alignment: .leading, spacing: DTSpace.xxs) {
                Text(module.name)
                    .font(DTTypography.body.weight(.semibold))
                    .foregroundStyle(DTColor.textPrimary)
                Text(module.summary)
                    .font(DTTypography.caption)
                    .foregroundStyle(DTColor.textSecondary)
                    .lineLimit(2)
            }

            Spacer(minLength: DTSpace.sm)

            VStack(alignment: .trailing, spacing: DTSpace.xs) {
                ModuleStatusPill(state: state)
                Toggle("", isOn: Binding(get: { isEnabled }, set: onToggle))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .disabled(!canEnable)
            }
        }
        .padding(.horizontal, DTSpace.md)
        .padding(.vertical, DTSpace.sm)
        .background(DTColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: DTRadius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DTRadius.md, style: .continuous)
                .strokeBorder(DTColor.border, lineWidth: 0.5)
        )
    }

    private var canEnable: Bool {
        if case .unavailable = state { return false }
        return true
    }
}
