import AppKit
import ApplicationServices
import Carbon.HIToolbox
import CoreGraphics
import DropThingsCore

/// Errors that can occur while snapping a window via Accessibility APIs.
public enum WindowSnapError: Error, Equatable, Sendable {
    case accessibilityDenied
    case noFrontmostApplication
    case noFocusedWindow
    case cannotReadWindowFrame
    case cannotSetWindowFrame
    case noScreens
}

extension WindowSnapError {
    public var localizedDescription: String {
        switch self {
        case .accessibilityDenied:
            return "Accessibility access is required to move and resize windows."
        case .noFrontmostApplication:
            return "No frontmost application was found."
        case .noFocusedWindow:
            return "The frontmost application has no focused window."
        case .cannotReadWindowFrame:
            return "Could not read the window's current position or size."
        case .cannotSetWindowFrame:
            return "Could not move or resize the window."
        case .noScreens:
            return "No screens are available."
        }
    }
}

/// A window-snapping action. The pure `targetFrame(windowFrame:screenFrame:)`
/// function is testable; the platform adapter applies it to the frontmost
/// window using Accessibility APIs.
public enum WindowSnapAction: String, CaseIterable, Sendable, Codable, Identifiable {
    case maximize
    case leftHalf
    case rightHalf
    case topHalf
    case bottomHalf
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .maximize: return "Maximize"
        case .leftHalf: return "Left half"
        case .rightHalf: return "Right half"
        case .topHalf: return "Top half"
        case .bottomHalf: return "Bottom half"
        case .topLeft: return "Top left"
        case .topRight: return "Top right"
        case .bottomLeft: return "Bottom left"
        case .bottomRight: return "Bottom right"
        }
    }

    /// Default global shortcut for this action. Each action gets a distinct
    /// Carbon hotkey id so they never collide inside the event handler.
    public var defaultHotkey: GlobalHotkey.Definition? {
        switch self {
        case .maximize:
            return GlobalHotkey.Definition(
                keyCode: UInt32(kVK_ANSI_M),
                modifiers: UInt32(controlKey | optionKey),
                id: 20
            )
        case .leftHalf:
            return GlobalHotkey.Definition(
                keyCode: UInt32(kVK_LeftArrow),
                modifiers: UInt32(controlKey | optionKey),
                id: 21
            )
        case .rightHalf:
            return GlobalHotkey.Definition(
                keyCode: UInt32(kVK_RightArrow),
                modifiers: UInt32(controlKey | optionKey),
                id: 22
            )
        case .topHalf:
            return GlobalHotkey.Definition(
                keyCode: UInt32(kVK_UpArrow),
                modifiers: UInt32(controlKey | optionKey),
                id: 23
            )
        case .bottomHalf:
            return GlobalHotkey.Definition(
                keyCode: UInt32(kVK_DownArrow),
                modifiers: UInt32(controlKey | optionKey),
                id: 24
            )
        case .topLeft:
            return GlobalHotkey.Definition(
                keyCode: UInt32(kVK_ANSI_Q),
                modifiers: UInt32(controlKey | optionKey),
                id: 25
            )
        case .topRight:
            return GlobalHotkey.Definition(
                keyCode: UInt32(kVK_ANSI_W),
                modifiers: UInt32(controlKey | optionKey),
                id: 26
            )
        case .bottomLeft:
            return GlobalHotkey.Definition(
                keyCode: UInt32(kVK_ANSI_A),
                modifiers: UInt32(controlKey | optionKey),
                id: 27
            )
        case .bottomRight:
            return GlobalHotkey.Definition(
                keyCode: UInt32(kVK_ANSI_S),
                modifiers: UInt32(controlKey | optionKey),
                id: 28
            )
        }
    }

    /// Computes the target frame for a window on a given screen. macOS screen
    /// frames have their origin at the bottom-left, so "top" uses the upper
    /// half of the rectangle (larger y values).
    public func targetFrame(windowFrame: CGRect, screenFrame: CGRect) -> CGRect {
        let halfWidth = screenFrame.width / 2
        let halfHeight = screenFrame.height / 2

        switch self {
        case .maximize:
            return screenFrame
        case .leftHalf:
            return CGRect(
                x: screenFrame.minX,
                y: screenFrame.minY,
                width: halfWidth,
                height: screenFrame.height
            )
        case .rightHalf:
            return CGRect(
                x: screenFrame.minX + halfWidth,
                y: screenFrame.minY,
                width: halfWidth,
                height: screenFrame.height
            )
        case .topHalf:
            return CGRect(
                x: screenFrame.minX,
                y: screenFrame.minY + halfHeight,
                width: screenFrame.width,
                height: halfHeight
            )
        case .bottomHalf:
            return CGRect(
                x: screenFrame.minX,
                y: screenFrame.minY,
                width: screenFrame.width,
                height: halfHeight
            )
        case .topLeft:
            return CGRect(
                x: screenFrame.minX,
                y: screenFrame.minY + halfHeight,
                width: halfWidth,
                height: halfHeight
            )
        case .topRight:
            return CGRect(
                x: screenFrame.minX + halfWidth,
                y: screenFrame.minY + halfHeight,
                width: halfWidth,
                height: halfHeight
            )
        case .bottomLeft:
            return CGRect(
                x: screenFrame.minX,
                y: screenFrame.minY,
                width: halfWidth,
                height: halfHeight
            )
        case .bottomRight:
            return CGRect(
                x: screenFrame.minX + halfWidth,
                y: screenFrame.minY,
                width: halfWidth,
                height: halfHeight
            )
        }
    }
}

/// Narrow interface for moving and resizing the frontmost window. Production
/// uses Accessibility APIs; tests substitute a fake that records requests.
public protocol WindowSnapperProtocol: Sendable {
    @MainActor
    func snap(_ action: WindowSnapAction) -> Result<Void, WindowSnapError>
}

/// Accessibility-backed adapter that snaps the focused window of the
/// frontmost application to the frame computed by `WindowSnapAction`.
public final class WindowSnapper: WindowSnapperProtocol, @unchecked Sendable {
    public init() {}

    @MainActor
    public func snap(_ action: WindowSnapAction) -> Result<Void, WindowSnapError> {
        guard AXIsProcessTrusted() else {
            return .failure(.accessibilityDenied)
        }

        guard let frontmostApp = NSWorkspace.shared.frontmostApplication else {
            return .failure(.noFrontmostApplication)
        }

        let appRef = AXUIElementCreateApplication(frontmostApp.processIdentifier)
        var windowRef: CFTypeRef?
        let windowError = AXUIElementCopyAttributeValue(
            appRef,
            kAXFocusedWindowAttribute as CFString,
            &windowRef
        )
        guard windowError == .success, let windowRef else {
            return .failure(.noFocusedWindow)
        }
        let window = windowRef as! AXUIElement

        guard let currentFrame = currentFrame(of: window) else {
            return .failure(.cannotReadWindowFrame)
        }

        guard let screen = screenContaining(currentFrame) else {
            return .failure(.noScreens)
        }

        let targetFrame = action.targetFrame(
            windowFrame: currentFrame,
            screenFrame: screen.visibleFrame
        )
        return setFrame(targetFrame, for: window)
    }

    private func currentFrame(of window: AXUIElement) -> CGRect? {
        var positionValue: CFTypeRef?
        var sizeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &positionValue) == .success,
              AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeValue) == .success else {
            return nil
        }
        var position = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(positionValue as! AXValue, .cgPoint, &position),
              AXValueGetValue(sizeValue as! AXValue, .cgSize, &size) else {
            return nil
        }
        return CGRect(origin: position, size: size)
    }

    private func screenContaining(_ frame: CGRect) -> NSScreen? {
        let center = CGPoint(x: frame.midX, y: frame.midY)
        return NSScreen.screens.first { $0.frame.contains(center) }
            ?? NSScreen.main
            ?? NSScreen.screens.first
    }

    private func setFrame(_ frame: CGRect, for window: AXUIElement) -> Result<Void, WindowSnapError> {
        var position = frame.origin
        var size = frame.size
        guard let positionValue = AXValueCreate(.cgPoint, &position),
              let sizeValue = AXValueCreate(.cgSize, &size) else {
            return .failure(.cannotSetWindowFrame)
        }

        let positionResult = AXUIElementSetAttributeValue(
            window,
            kAXPositionAttribute as CFString,
            positionValue
        )
        let sizeResult = AXUIElementSetAttributeValue(
            window,
            kAXSizeAttribute as CFString,
            sizeValue
        )

        guard positionResult == .success, sizeResult == .success else {
            return .failure(.cannotSetWindowFrame)
        }
        return .success(())
    }
}
