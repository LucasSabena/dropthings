import CoreGraphics
import DropThingsPlatform

public enum ScrollCaptureState: Equatable, Sendable {
    case idle, selecting, priming, capturing(Int), aligning, stitching, finishing, cancelled, partial(reason: String), failed(reason: String)
}

public struct ScrollCaptureResult: @unchecked Sendable {
    public let image: CGImage
    public let isPartial: Bool
    public let frameCount: Int
}

/// Serial coordinator for scrolling. It deliberately stops at the first weak
/// seam and returns the valid prefix rather than inventing a composite.
@MainActor
public final class ScrollCaptureCoordinator {
    public private(set) var state: ScrollCaptureState = .idle
    private var cancelled = false
    public init() {}
    public func cancel() { cancelled = true }

    public func capture(region: CGRect, service: any ScreenCaptureService, driver: any ScrollDriver, maximumFrames: Int = 30, step: Int32 = -640, onState: @escaping @Sendable (ScrollCaptureState) -> Void = { _ in }) async throws -> ScrollCaptureResult {
        func update(_ state: ScrollCaptureState) { self.state = state; onState(state) }
        cancelled = false; update(.priming)
        var frames: [CGImage] = []
        for index in 0..<maximumFrames {
            if cancelled { break }
            update(.capturing(index + 1))
            let frame = try await service.capture(.region(region)).image
            if let previous = frames.last {
                update(.aligning)
                guard let alignment = FrameAligner.align(previous: previous, next: frame) else { break }
                // An overlap equal to the full frame means the target did not
                // move. Treat it as a safe end rather than a successful stitch.
                guard alignment.overlap < frame.height - 2 else { break }
            }
            frames.append(frame)
            try driver.scroll(at: CGPoint(x: region.midX, y: region.midY), deltaY: step)
            try await Task.sleep(nanoseconds: 180_000_000)
        }
        guard !frames.isEmpty else { update(.failed(reason: "No frames were captured.")); throw ScreenCaptureError.captureFailed }
        update(.stitching)
        guard let stitched = FrameAligner.stitch(frames) else { update(.failed(reason: "Frames could not be aligned.")); throw ScreenCaptureError.captureFailed }
        let partial = cancelled || stitched.partial || frames.count == 1
        update(partial ? .partial(reason: cancelled ? "Capture stopped by user." : "Stopped before a trustworthy next seam.") : .finishing)
        return ScrollCaptureResult(image: stitched.image, isPartial: partial, frameCount: frames.count)
    }
}
