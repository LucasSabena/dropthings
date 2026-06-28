import AppKit
import CoreGraphics

/// Wraps `CGEvent.tapCreate` for the scroll-control use case. The tap is
/// always a session-level, default tap on `scrollWheel` events; everything
/// else (keyboard, mouse buttons) is left alone. The tap runs on the main
/// run loop and dispatches into a transformer the caller provides.
///
/// Lifecycle: `start(transformer:)` installs the tap and adds its source to
/// the main run loop. `stop()` tears it down. Calling `start` twice is a
/// no-op; calling `stop` without `start` is a no-op. The deinit defensively
/// calls `stop`.
///
/// Timeout recovery: macOS disables a tap if its callback takes too long. We
/// observe `tapDisabledByTimeout` events, surface `isTimedOut`, and
/// re-enable the tap automatically so a brief stall does not silently kill
/// scroll control.
public final class EventTapClient: @unchecked Sendable {
    public enum TapError: Error, Equatable {
        case creationFailed
    }

    public typealias Transformer = (ScrollEventInput) -> ScrollEventDecision?

    private let lock = NSLock()
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var transformer: Transformer?
    private var _isTimedOut: Bool = false

    public init() {}

    deinit {
        stop()
    }

    public func start(transformer: @escaping Transformer) throws {
        lock.lock()
        defer { lock.unlock() }
        guard tap == nil else { return }
        self.transformer = transformer
        self._isTimedOut = false

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        let eventMask: CGEventMask = CGEventMask(1 << CGEventType.scrollWheel.rawValue)

        let callback: CGEventTapCallBack = { _, type, event, userInfo in
            guard let userInfo else {
                return Unmanaged.passUnretained(event)
            }

            let client = Unmanaged<EventTapClient>.fromOpaque(userInfo).takeUnretainedValue()

            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                client.handleDisabled()
                return Unmanaged.passUnretained(event)
            }

            guard type == .scrollWheel else { return Unmanaged.passUnretained(event) }

            let input = ScrollEventInput.from(event: event)
            guard let decision = client.runTransformer(input: input),
                  decision.didMutate else {
                return Unmanaged.passUnretained(event)
            }
            decision.apply(to: event)
            return Unmanaged.passUnretained(event)
        }

        guard let newTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: callback,
            userInfo: selfPtr
        ) else {
            self.transformer = nil
            throw TapError.creationFailed
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, newTap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: newTap, enable: true)

        self.tap = newTap
        self.runLoopSource = source
    }

    public func stop() {
        lock.lock()
        defer { lock.unlock() }
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
            self.tap = nil
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
            self.runLoopSource = nil
        }
        self.transformer = nil
    }

    public var isActive: Bool {
        lock.lock()
        defer { lock.unlock() }
        return tap != nil
    }

    public var isTimedOut: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _isTimedOut
    }

    private func handleDisabled() {
        lock.lock()
        _isTimedOut = true
        let tap = self.tap
        lock.unlock()
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: true)
        }
    }

    private func runTransformer(input: ScrollEventInput) -> ScrollEventDecision? {
        lock.lock()
        let t = transformer
        lock.unlock()
        return t?(input)
    }
}
