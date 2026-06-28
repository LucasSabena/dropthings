import AppKit
import CoreGraphics
import os

/// Polls `NSEvent.mouseLocation` at a fixed interval and forwards the result
/// to a handler on the main actor. No event tap, no Accessibility
/// permission — the system exposes mouse position freely. The handler is
/// called on the main thread, so consumers do not need to dispatch.
public final class MousePositionMonitor: @unchecked Sendable {
    public typealias Handler = @MainActor (CGPoint) -> Void

    private let interval: TimeInterval
    private let handler: Handler
    private let lock = NSLock()
    private var timer: Timer?
    private var sampleCount: Int = 0
    private let logger = Logger(subsystem: "app.dropthings", category: "mouse-monitor")

    public init(interval: TimeInterval = 1.0 / 60.0, handler: @escaping Handler) {
        self.interval = interval
        self.handler = handler
    }

    deinit {
        stop()
    }

    public func start() {
        lock.lock()
        defer { lock.unlock() }
        guard timer == nil else { return }
        sampleCount = 0

        let interval = self.interval
        let handler = self.handler
        let logger = self.logger

        let newTimer = Timer(timeInterval: interval, repeats: true) { _ in
            let location = NSEvent.mouseLocation
            Task { @MainActor in
                handler(location)
            }
        }
        newTimer.tolerance = interval * 0.5
        RunLoop.main.add(newTimer, forMode: .common)
        timer = newTimer
        logger.notice("Mouse position monitor STARTED at \(interval, privacy: .public)s interval")
    }

    public func stop() {
        lock.lock()
        defer { lock.unlock() }
        guard timer != nil else { return }
        timer?.invalidate()
        timer = nil
        logger.notice("Mouse position monitor STOPPED")
    }

    public var isRunning: Bool {
        lock.lock()
        defer { lock.unlock() }
        return timer != nil
    }
}
