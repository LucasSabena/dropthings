import AppKit
import CoreGraphics
import SwiftUI

/// Live magnifier feed for the native `NSColorSampler`. Captures a small
/// region around the cursor on every mouse move and reports the center
/// pixel so a SwiftUI loupe can render zoom + RGB without needing
/// Screen Recording permission (the capture is read-only and uses the same
/// public `CGWindowListCreateImage` API the old overlay used).
public final class ColorSamplerLoupe: @unchecked Sendable {
    public struct Sample: Sendable, Equatable {
        public let image: CGImage?
        public let centerRGB: PixelSampler.RGB?
        public let location: CGPoint

        public init(image: CGImage?, centerRGB: PixelSampler.RGB?, location: CGPoint) {
            self.image = image
            self.centerRGB = centerRGB
            self.location = location
        }
    }

    private let monitor: MousePositionMonitor
    private let lock = NSLock()
    private var latest: Sample?
    private let regionSize: CGFloat
    private var mapper: ScreenCoordinateMapper?

    public init(regionSize: CGFloat = 96, onUpdate: @escaping @MainActor (Sample) -> Void) {
        self.regionSize = regionSize
        self.mapper = nil
        let monitor = MousePositionMonitor(interval: 1.0 / 60.0)
        self.monitor = monitor
        monitor.handler = { [weak self] location in
            guard let self else { return }
            let sample = self.capture(around: location)
            self.lock.lock()
            self.latest = sample
            self.lock.unlock()
            onUpdate(sample)
        }
    }

    public func start() {
        mapper = ScreenCoordinateMapper.current()
        monitor.start()
    }

    public func stop() {
        monitor.stop()
    }

    private func capture(around location: CGPoint) -> Sample {
        let screenImage = ScreenCapture.region(around: location, size: regionSize)
        var rgb: PixelSampler.RGB?
        if let image = screenImage {
            let mapper = ScreenCoordinateMapper.current()
            let imagePoint = mapper.imagePoint(forAppKitPoint: location)
            rgb = PixelSampler.sample(at: imagePoint, in: image)
        }
        return Sample(image: screenImage, centerRGB: rgb, location: location)
    }
}
