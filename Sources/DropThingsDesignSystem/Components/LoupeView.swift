import SwiftUI
import CoreGraphics

/// A magnifier that shows an 8x zoom of a `CGImage` with a 1-pixel
/// center grid and the RGB value of the pixel under the crosshair.
/// Designed for the Color Picker: the module captures a small region
/// around the cursor on every `mouseMoved` and passes it here.
public struct LoupeView: View {
    public let image: CGImage?
    public let zoom: CGFloat
    public let sampledRGB: PixelSample?

    public init(image: CGImage?, zoom: CGFloat = 8, sampledRGB: PixelSample? = nil) {
        self.image = image
        self.zoom = zoom
        self.sampledRGB = sampledRGB
    }

    public var body: some View {
        VStack(spacing: DTSpace.xxs) {
            magnifier
            if let rgb = sampledRGB {
                Text(rgb.hex)
                    .font(DTTypography.caption.monospaced())
                    .foregroundStyle(DTColor.textPrimary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    private var magnifier: some View {
        ZStack {
            if let image {
                Image(decorative: image, scale: 1.0, orientation: .up)
                    .resizable()
                    .scaledToFill()
                    .frame(width: diameter, height: diameter)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(DTColor.surfaceRaised)
                    .frame(width: diameter, height: diameter)
            }
            Circle()
                .strokeBorder(DTColor.border, lineWidth: 1)
                .frame(width: diameter, height: diameter)
            // Center crosshair.
            Crosshair()
                .stroke(DTColor.danger, lineWidth: 1)
                .frame(width: crosshairLength, height: crosshairLength)
        }
        .frame(width: diameter, height: diameter)
    }

    private var diameter: CGFloat { 140 }
    private var crosshairLength: CGFloat { 16 }

    private var accessibilityDescription: String {
        if let rgb = sampledRGB {
            return "Magnifier showing 8x zoom. Center color \(rgb.hex)."
        }
        return "Magnifier showing 8x zoom."
    }
}

private struct Crosshair: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        // Vertical line.
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        // Horizontal line.
        p.move(to: CGPoint(x: rect.minX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return p
    }
}

/// One sampled pixel value the loupe displays. Kept here to avoid
/// pulling `PixelSampler.RGB` (Platform) into DesignSystem call sites
/// that don't need the full type.
public struct PixelSample: Equatable, Sendable {
    public let r: Int
    public let g: Int
    public let b: Int

    public init(r: Int, g: Int, b: Int) {
        self.r = r
        self.g = g
        self.b = b
    }

    public var hex: String {
        String(format: "#%02X%02X%02X", r, g, b)
    }
}