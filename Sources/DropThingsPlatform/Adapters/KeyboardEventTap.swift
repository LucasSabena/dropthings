import CoreGraphics
import Foundation

/// Owns a session event tap that can temporarily suppress keyboard input.
/// The lock state is protected here rather than read from a SwiftUI object so
/// the event callback never crosses actor boundaries on a hot path.
public protocol KeyboardEventTapping: AnyObject {
    func start() throws
    func stop()
    func setLocked(_ locked: Bool)
    var isActive: Bool { get }
}

public final class KeyboardEventTap: KeyboardEventTapping, @unchecked Sendable {
    public enum TapError: Error, Equatable { case creationFailed }

    private let lock = NSLock()
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var locked = false

    public init() {}

    deinit { stop() }

    public func start() throws {
        lock.lock()
        defer { lock.unlock() }
        guard tap == nil else { return }

        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
            | CGEventMask(1 << CGEventType.keyUp.rawValue)
            | CGEventMask(1 << CGEventType.flagsChanged.rawValue)
        let pointer = Unmanaged.passUnretained(self).toOpaque()
        let callback: CGEventTapCallBack = { _, type, event, userInfo in
            guard let userInfo else { return Unmanaged.passUnretained(event) }
            let tap = Unmanaged<KeyboardEventTap>.fromOpaque(userInfo).takeUnretainedValue()
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                tap.enable()
                return Unmanaged.passUnretained(event)
            }
            return tap.shouldBlock ? nil : Unmanaged.passUnretained(event)
        }

        guard let newTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: pointer
        ) else {
            throw TapError.creationFailed
        }
        let newSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, newTap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), newSource, .commonModes)
        CGEvent.tapEnable(tap: newTap, enable: true)
        tap = newTap
        source = newSource
    }

    public func stop() {
        lock.lock()
        defer { lock.unlock() }
        locked = false
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
            self.tap = nil
        }
        if let source {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            self.source = nil
        }
    }

    public func setLocked(_ locked: Bool) {
        lock.lock()
        self.locked = locked
        lock.unlock()
    }

    public var isActive: Bool {
        lock.lock()
        defer { lock.unlock() }
        return tap != nil
    }

    private var shouldBlock: Bool {
        lock.lock()
        defer { lock.unlock() }
        return locked
    }

    private func enable() {
        lock.lock()
        let tap = self.tap
        lock.unlock()
        if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
    }
}
