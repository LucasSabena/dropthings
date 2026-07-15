import SwiftUI
import DropThingsCore
import DropThingsDesignSystem
import DropThingsMediaConverterKit

/// Live list of queued conversions. Each row shows phase, progress, and on
/// completion exposes Reveal/Open/Copy Path and the size delta. State is never
/// color-only: every phase has a label.
struct MediaQueueList: View {
    @ObservedObject var module: MediaConverterModule

    var body: some View {
        VStack(alignment: .leading, spacing: DTSpace.sm) {
            HStack {
                Text("Queue")
                    .font(DTTypography.sectionTitle)
                    .foregroundStyle(DTColor.textPrimary)
                Spacer()
                Button("Clear") { module.queue.clearCompleted() }
                    .font(DTTypography.caption)
            }

            ForEach(module.queue.items) { item in
                MediaQueueRow(item: item) {
                    module.cancel(jobID: item.id)
                }
            }
        }
    }
}

private struct MediaQueueRow: View {
    let item: MediaQueueItem
    let onCancel: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: DTSpace.sm) {
            Image(systemName: phaseIcon)
                .foregroundStyle(phaseColor)
                .frame(width: DTSize.utilityIcon, height: DTSize.utilityIcon)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: DTSpace.xxs) {
                Text(item.displayName)
                    .font(DTTypography.body)
                    .foregroundStyle(DTColor.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Text(phaseText)
                    .font(DTTypography.caption)
                    .foregroundStyle(DTColor.textSecondary)

                if let progress = item.phase.progress {
                    ProgressView(value: progress)
                        .progressViewStyle(.linear)
                        .tint(DTColor.accent)
                }
            }

            Spacer()

            actions
        }
        .padding(DTSpace.sm)
        .background(DTColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: DTRadius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DTRadius.md, style: .continuous)
                .strokeBorder(DTColor.border, lineWidth: 0.5)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.displayName), \(phaseText)")
    }

    @ViewBuilder
    private var actions: some View {
        switch item.phase {
        case .completed(let destination, _):
            HStack(spacing: DTSpace.xs) {
                Button { NSWorkspace.shared.activateFileViewerSelecting([destination]) } label: {
                    Image(systemName: "folder")
                }
                .accessibilityLabel("Reveal in Finder")
                Button { NSWorkspace.shared.open(destination) } label: {
                    Image(systemName: "doc")
                }
                .accessibilityLabel("Open")
            }
            .buttonStyle(.borderless)
        case .pending, .probing, .validating, .encoding, .reprobing, .finalizing:
            Button("Cancel", action: onCancel)
                .font(DTTypography.caption)
                .accessibilityLabel("Cancel \(item.displayName)")
        case .failed, .skipped, .cancelled:
            EmptyView()
        }
    }

    private var phaseIcon: String {
        switch item.phase {
        case .pending: return "clock"
        case .probing, .validating, .reprobing: return "magnifyingglass"
        case .encoding, .finalizing: return "gearshape"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "exclamationmark.triangle.fill"
        case .skipped: return "forward.fill"
        case .cancelled: return "stop.fill"
        }
    }

    private var phaseColor: Color {
        switch item.phase {
        case .completed: return DTColor.success
        case .failed: return DTColor.danger
        case .skipped, .cancelled: return DTColor.textSecondary
        default: return DTColor.textSecondary
        }
    }

    private var phaseText: String {
        switch item.phase {
        case .completed(_, let sizeDelta):
            return "Done — \(formatDelta(sizeDelta))"
        case .failed(let reason): return reason
        case .skipped(let reason): return "Skipped: \(reason)"
        case .encoding(let progress): return "Converting… \(Int(progress * 100))%"
        default: return item.phase.shortLabel
        }
    }

    private func formatDelta(_ delta: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        if delta < 0 { return "\(formatter.string(fromByteCount: abs(delta))) smaller" }
        if delta > 0 { return "\(formatter.string(fromByteCount: delta)) larger" }
        return "same size"
    }
}
