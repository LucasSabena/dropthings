import SwiftUI
import DropThingsCore
import DropThingsDesignSystem
import DropThingsPlatform

struct MenuBarCleanerSettingsView: View {
    @ObservedObject var module: MenuBarCleanerModule

    var body: some View {
        SettingsSection(
            title: "Menu Bar Cleaner",
            caption: "Hide menu bar icons you do not need. Click the reveal button in the menu bar to show them again."
        ) {
            VStack(alignment: .leading, spacing: DTSpace.md) {
                actionRow
                revealStatusRow
                itemsList
                if let err = module.lastRefreshError {
                    InlineAlert(style: .warning, message: err)
                }
            }
        }
    }

    private var actionRow: some View {
        HStack {
            Button {
                module.refresh()
            } label: {
                Label("Refresh menu bar", systemImage: "arrow.clockwise")
            }
            .controlSize(.regular)

            Spacer()

            if !module.hiddenIds.isEmpty {
                Button("Show all") {
                    module.showAll()
                }
                .controlSize(.small)
            }
        }
    }

    private var revealStatusRow: some View {
        HStack(spacing: DTSpace.sm) {
            Image(systemName: module.isRevealing ? "eye" : "eye.slash")
                .foregroundStyle(DTColor.accent)
            Text(revealStatusText)
                .font(DTTypography.caption)
                .foregroundStyle(DTColor.textSecondary)
            Spacer()
            Button {
                module.toggleReveal()
            } label: {
                Text(module.isRevealing ? "Re-hide items" : "Reveal all now")
            }
            .controlSize(.small)
            .disabled(module.hiddenIds.isEmpty)
        }
    }

    private var revealStatusText: String {
        if module.isRevealing {
            return "All items are temporarily visible. Click the menu bar chevron or this button to re-hide."
        }
        let count = module.hiddenIds.count
        if count == 0 {
            return "Nothing is hidden. Toggle items off below or install a few menu bar apps."
        }
        return "\(count) item\(count == 1 ? "" : "s") hidden. Click the menu bar chevron to reveal."
    }

    @ViewBuilder
    private var itemsList: some View {
        if module.discoveredItems.isEmpty {
            Text(emptyMessage)
                .font(DTTypography.caption)
                .foregroundStyle(DTColor.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            VStack(spacing: 0) {
                ForEach(module.discoveredItems) { item in
                    itemRow(item)
                    if item.id != module.discoveredItems.last?.id {
                        Divider()
                    }
                }
            }
        }
    }

    private var emptyMessage: String {
        switch module.state {
        case .needsPermission:
            return "Grant Accessibility to enumerate menu bar items."
        case .failed(let reason, _):
            return reason
        case .degraded(let reason):
            return reason
        default:
            return "Click Refresh menu bar to detect items."
        }
    }

    private func itemRow(_ item: MenuBarItem) -> some View {
        HStack(spacing: DTSpace.sm) {
            Image(systemName: module.hiddenIds.contains(item.id) ? "eye.slash" : "menubar.rectangle")
                .foregroundStyle(DTColor.accent)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 0) {
                Text(item.title)
                    .font(DTTypography.body)
                    .lineLimit(1)
                if let bundleId = item.ownerBundleId {
                    Text(bundleId)
                        .font(DTTypography.caption)
                        .foregroundStyle(DTColor.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            Spacer()
            Toggle("", isOn: Binding(
                get: { !module.hiddenIds.contains(item.id) },
                set: { isVisible in module.setHidden(item.id, hidden: !isVisible) }
            ))
            .labelsHidden()
        }
        .padding(.vertical, DTSpace.xs)
    }
}

