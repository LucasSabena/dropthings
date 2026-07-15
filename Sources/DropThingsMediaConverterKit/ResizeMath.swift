import Foundation

/// Pure resize math. No AppKit/CoreGraphics types — the kit stays Foundation
/// only. The platform adapter applies the result to a real image buffer.
public enum ResizeMath {
    /// Compute the output dimensions for `policy` given the source dimensions,
    /// honoring `noUpscale`. Returns `nil` when the source or policy is empty.
    public static func targetDimensions(
        source: MediaDimensions,
        policy: ResizePolicy,
        noUpscale: Bool
    ) -> MediaDimensions? {
        guard source.isNonEmpty else { return nil }
        switch policy {
        case .none:
            return source

        case .maxEdge(let edge):
            guard edge > 0 else { return nil }
            let scale = Double(edge) / Double(source.longestEdge)
            return applyScale(source: source, scale: scale, noUpscale: noUpscale)

        case .percentage(let percent):
            guard percent > 0 else { return nil }
            let scale = Double(percent) / 100.0
            return applyScale(source: source, scale: scale, noUpscale: noUpscale)

        case .exact(let width, let height, let mode):
            guard width > 0, height > 0 else { return nil }
            switch mode {
            case .stretch:
                let out = MediaDimensions(width: width, height: height)
                if noUpscale { return capped(source: source, target: out) }
                return out
            case .fit:
                return fitCover(source: source, boxWidth: width, boxHeight: height, cover: false, noUpscale: noUpscale)
            case .fill:
                return fitCover(source: source, boxWidth: width, boxHeight: height, cover: true, noUpscale: noUpscale)
            }
        }
    }

    private static func applyScale(source: MediaDimensions, scale: Double, noUpscale: Bool) -> MediaDimensions {
        let effectiveScale: Double
        if noUpscale && scale > 1 {
            effectiveScale = 1
        } else if scale < 0 {
            effectiveScale = 0
        } else {
            effectiveScale = scale
        }
        let width = max(1, Int((Double(source.width) * effectiveScale).rounded()))
        let height = max(1, Int((Double(source.height) * effectiveScale).rounded()))
        return MediaDimensions(width: width, height: height)
    }

    private static func capped(source: MediaDimensions, target: MediaDimensions) -> MediaDimensions {
        // Don't exceed the source on either axis when noUpscale is on.
        let width = min(target.width, source.width)
        let height = min(target.height, source.height)
        return MediaDimensions(width: width, height: height)
    }

    /// `cover = true` fills the box (scale to the larger factor, then the
    /// adapter crops); `cover = false` fits inside (scale to the smaller factor).
    private static func fitCover(
        source: MediaDimensions,
        boxWidth: Int,
        boxHeight: Int,
        cover: Bool,
        noUpscale: Bool
    ) -> MediaDimensions {
        let sourceAspect = Double(source.width) / Double(max(1, source.height))
        let boxAspect = Double(boxWidth) / Double(max(1, boxHeight))
        let scale: Double
        if cover {
            scale = sourceAspect > boxAspect
                ? Double(boxHeight) / Double(source.height)
                : Double(boxWidth) / Double(source.width)
        } else {
            scale = sourceAspect > boxAspect
                ? Double(boxWidth) / Double(source.width)
                : Double(boxHeight) / Double(source.height)
        }
        return applyScale(source: source, scale: scale, noUpscale: noUpscale)
    }
}
