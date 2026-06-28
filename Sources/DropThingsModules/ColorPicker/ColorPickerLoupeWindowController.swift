import AppKit
import SwiftUI
import DropThingsDesignSystem
import DropThingsPlatform

/// Floating circular panel that follows the cursor while the native color
/// sampler is open. Lives in the module because it is specific to the color
/// picker picking experience; the visual piece is the shared `LoupeView`.
final class ColorPickerLoupeWindowController {
    private var panel: NSPanel?
    private let offset: CGSize

    init(offset: CGSize = CGSize(width: 90, height: 90)) {
        self.offset = offset
    }

    func show(sample: LoupeViewSample) {
        if panel == nil {
            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 160, height: 180),
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.level = .statusBar
            panel.collectionBehavior = [.canJoinAllSpaces, .stationary]
            panel.backgroundColor = NSColor.clear
            panel.isOpaque = false
            panel.hasShadow = true
            panel.isReleasedWhenClosed = false
            panel.contentView = NSHostingView(rootView: AnyView(EmptyView()))
            self.panel = panel
        }
        update(sample: sample)
        panel?.orderFrontRegardless()
    }

    func update(sample: LoupeViewSample) {
        guard let panel else { return }
        let point = sample.location
        // Position the loupe to the bottom-right of the cursor so it does
        // not cover the pixel being inspected.
        let screenHeight = NSScreen.main?.frame.height ?? 1080
        let x = point.x + offset.width
        let y = screenHeight - point.y - offset.height - panel.frame.height
        panel.setFrameOrigin(NSPoint(x: x, y: y))

        let root = AnyView(
            LoupeView(
                image: sample.image,
                zoom: sample.zoom,
                sampledRGB: sample.rgb
            )
            .frame(width: 160, height: 180)
            .background(DTColor.surface.opacity(0.92))
            .clipShape(RoundedRectangle(cornerRadius: DTRadius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DTRadius.lg, style: .continuous)
                    .strokeBorder(DTColor.border, lineWidth: 0.5)
            )
        )
        (panel.contentView as? NSHostingView<AnyView>)?.rootView = root
    }

    func hide() {
        panel?.orderOut(nil)
    }
}

/// Bridge type so `LoupeView` (DesignSystem) does not need to know about
/// `PixelSampler.RGB` or `ColorSamplerLoupe.Sample`.
struct LoupeViewSample {
    let image: CGImage?
    let zoom: CGFloat
    let rgb: PixelSample?
    let location: CGPoint
}
