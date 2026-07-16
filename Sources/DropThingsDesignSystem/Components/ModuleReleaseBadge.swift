import SwiftUI
import DropThingsCore

public struct ModuleReleaseBadge: View {
    private let stage: ModuleReleaseStage

    public init(stage: ModuleReleaseStage) {
        self.stage = stage
    }

    public var body: some View {
        if stage == .beta {
            Text(stage.label.uppercased())
                .font(DTTypography.badgeLabel)
                .foregroundStyle(DTColor.warning)
                .padding(.horizontal, DTSpace.xs)
                .padding(.vertical, DTSpace.xxs)
                .background(DTColor.warning.opacity(0.12))
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(DTColor.warning.opacity(0.35)))
                .accessibilityLabel("Beta module")
        }
    }
}
