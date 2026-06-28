import SwiftUI

/// Grouped container used inside module detail pages. Title + optional
/// caption + content. Use instead of nested card stacks.
public struct SettingsSection<Content: View>: View {
    public let title: String
    public let caption: String?
    public let content: () -> Content

    public init(title: String, caption: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.caption = caption
        self.content = content
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DTSpace.sm) {
            VStack(alignment: .leading, spacing: DTSpace.xxs) {
                Text(title)
                    .font(DTTypography.sectionTitle)
                    .foregroundStyle(DTColor.textPrimary)
                if let caption {
                    Text(caption)
                        .font(DTTypography.caption)
                        .foregroundStyle(DTColor.textSecondary)
                }
            }
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(DTSpace.md)
                .background(DTColor.surface)
                .clipShape(RoundedRectangle(cornerRadius: DTRadius.md, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: DTRadius.md, style: .continuous)
                        .strokeBorder(DTColor.border, lineWidth: 0.5)
                )
        }
    }
}
