import AppKit
import SwiftUI
import DropThingsDesignSystem

/// Short, non-interactive confirmation shown after a successful pick or a
/// history swatch copy. Sampling stays entirely native; this panel appears
/// only after the click, so it cannot compete with the system magnifier.
@MainActor
final class ColorCopyFeedbackWindowController {
    private var panel: NSPanel?
    private var dismissalTask: Task<Void, Never>?

    func show(color: NSColor, value: String, near point: CGPoint) {
        let panel = panel ?? makePanel()
        self.panel = panel
        dismissalTask?.cancel()

        let root = AnyView(
            HStack(spacing: DTSpace.md) {
                RoundedRectangle(cornerRadius: DTRadius.md, style: .continuous)
                    .fill(Color(nsColor: color))
                    .frame(width: DTSize.previewSmall, height: DTSize.previewSmall)
                    .overlay(
                        RoundedRectangle(cornerRadius: DTRadius.md, style: .continuous)
                            .strokeBorder(DTColor.border, lineWidth: 0.5)
                    )
                VStack(alignment: .leading, spacing: DTSpace.xxs) {
                    Label("Copied", systemImage: "checkmark.circle.fill")
                        .font(DTTypography.body.weight(.semibold))
                        .foregroundStyle(DTColor.success)
                    Text(value)
                        .font(DTTypography.monospacedBody)
                        .foregroundStyle(DTColor.textPrimary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(DTSpace.md)
            .frame(width: DTSize.colorFeedbackWidth, height: DTSize.colorFeedbackHeight)
            .background(DTColor.surface.opacity(0.96))
            .clipShape(RoundedRectangle(cornerRadius: DTRadius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DTRadius.lg, style: .continuous)
                    .strokeBorder(DTColor.border, lineWidth: 0.5)
            )
        )
        (panel.contentView as? NSHostingView<AnyView>)?.rootView = root
        panel.setFrameOrigin(Self.panelOrigin(
            cursor: point,
            panelSize: panel.frame.size,
            visibleFrame: Self.visibleFrame(containing: point)
        ))
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            panel.animator().alphaValue = 1
        }

        dismissalTask = Task { [weak self, weak panel] in
            try? await Task.sleep(for: .seconds(1.4))
            guard !Task.isCancelled, let panel else { return }
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.18
                panel.animator().alphaValue = 0
            }, completionHandler: { [weak self, weak panel] in
                Task { @MainActor in
                    panel?.orderOut(nil)
                    self?.dismissalTask = nil
                }
            })
        }
    }

    func hide() {
        dismissalTask?.cancel()
        dismissalTask = nil
        panel?.orderOut(nil)
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(
                origin: .zero,
                size: NSSize(width: DTSize.colorFeedbackWidth, height: DTSize.colorFeedbackHeight)
            ),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.isReleasedWhenClosed = false
        panel.contentView = NSHostingView(rootView: AnyView(EmptyView()))
        return panel
    }

    static func panelOrigin(cursor: CGPoint, panelSize: CGSize, visibleFrame: CGRect) -> CGPoint {
        let offset = DTSpace.lg
        var x = cursor.x + offset
        var y = cursor.y - panelSize.height - offset
        if x + panelSize.width > visibleFrame.maxX {
            x = cursor.x - panelSize.width - offset
        }
        if y < visibleFrame.minY {
            y = cursor.y + offset
        }
        return CGPoint(
            x: min(max(x, visibleFrame.minX), visibleFrame.maxX - panelSize.width),
            y: min(max(y, visibleFrame.minY), visibleFrame.maxY - panelSize.height)
        )
    }

    private static func visibleFrame(containing point: CGPoint) -> CGRect {
        NSScreen.screens.first(where: { $0.frame.contains(point) })?.visibleFrame
            ?? NSScreen.main?.visibleFrame
            ?? .zero
    }
}
