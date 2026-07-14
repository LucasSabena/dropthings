import AppKit
import CoreGraphics
import ScreenCaptureKit

/// Metadata kept with a captured frame so consumers never need to guess its
/// pixel dimensions or coordinate origin. The image is immutable.
public struct CapturedImage: @unchecked Sendable {
    public let image: CGImage
    public let sourceRect: CGRect
    public let timestamp: Date

    public init(image: CGImage, sourceRect: CGRect, timestamp: Date = Date()) {
        self.image = image
        self.sourceRect = sourceRect
        self.timestamp = timestamp
    }

    public var pixelSize: CGSize { CGSize(width: image.width, height: image.height) }
}

public enum ScreenCaptureRequest: Sendable, Equatable {
    case region(CGRect)
    case display(CGDirectDisplayID)
    case window(CGWindowID, CGRect)
}

public enum ScreenCaptureError: Error, Equatable, LocalizedError {
    case invalidRegion
    case targetUnavailable
    case permissionDenied
    case protectedContent
    case captureFailed

    public var errorDescription: String? {
        switch self {
        case .invalidRegion: return "The capture area is empty."
        case .targetUnavailable: return "The selected display or window is no longer available."
        case .permissionDenied: return "Screen Recording permission is required to capture pixels."
        case .protectedContent: return "macOS did not provide pixels for this protected content."
        case .captureFailed: return "macOS could not capture the selected content."
        }
    }
}

/// Narrow capture seam. It is intentionally injectable so module tests can
/// exercise permission and output behavior without reading real screens.
public protocol ScreenCaptureService: Sendable {
    func capture(_ request: ScreenCaptureRequest) async throws -> CapturedImage
}

/// Public CoreGraphics single-frame capture adapter. ScreenCaptureKit can be
/// added behind this protocol without changing module code; this conservative
/// adapter remains necessary for selecting a CG window by ID on current builds.
public struct CoreGraphicsScreenCaptureService: ScreenCaptureService {
    public init() {}

    public func capture(_ request: ScreenCaptureRequest) async throws -> CapturedImage {
        let rect: CGRect
        let image: CGImage?
        switch request {
        case .region(let sourceRect):
            guard sourceRect.width > 0, sourceRect.height > 0 else {
                throw ScreenCaptureError.invalidRegion
            }
            rect = sourceRect
            image = CGWindowListCreateImage(sourceRect, .optionOnScreenOnly, kCGNullWindowID, [.bestResolution])
        case .display(let displayID):
            rect = CGDisplayBounds(displayID)
            guard !rect.isEmpty else { throw ScreenCaptureError.targetUnavailable }
            image = CGDisplayCreateImage(displayID)
        case .window(let windowID, let sourceRect):
            rect = sourceRect
            image = CGWindowListCreateImage(.null, .optionIncludingWindow, windowID, [.bestResolution])
        }
        guard let image else { throw ScreenCaptureError.captureFailed }
        return CapturedImage(image: image, sourceRect: rect)
    }
}

/// ScreenCaptureKit implementation used by Screenshot Studio on macOS 14+.
/// The Core Graphics adapter remains a narrow fallback for arbitrary regions on
/// macOS 14–15.1, where Apple's display-agnostic rectangle API is unavailable.
@available(macOS 14.0, *)
public struct ScreenCaptureKitService: ScreenCaptureService {
    private let fallback: any ScreenCaptureService

    public init(fallback: any ScreenCaptureService = CoreGraphicsScreenCaptureService()) {
        self.fallback = fallback
    }

    public func capture(_ request: ScreenCaptureRequest) async throws -> CapturedImage {
        switch request {
        case .region(let rect):
            guard rect.width > 0, rect.height > 0 else { throw ScreenCaptureError.invalidRegion }
            if #available(macOS 15.2, *) {
                let image = try await screenshot(in: rect)
                return CapturedImage(image: image, sourceRect: rect)
            }
            return try await fallback.capture(request)
        case .display(let displayID):
            let content = try await shareableContent()
            guard let display = content.displays.first(where: { $0.displayID == displayID }) else {
                throw ScreenCaptureError.targetUnavailable
            }
            let image = try await screenshot(filter: SCContentFilter(display: display, excludingWindows: []))
            return CapturedImage(image: image, sourceRect: CGDisplayBounds(displayID))
        case .window(let windowID, let rect):
            let content = try await shareableContent()
            guard let window = content.windows.first(where: { $0.windowID == windowID }) else {
                throw ScreenCaptureError.targetUnavailable
            }
            let image = try await screenshot(filter: SCContentFilter(desktopIndependentWindow: window))
            return CapturedImage(image: image, sourceRect: rect)
        }
    }

    private func shareableContent() async throws -> SCShareableContent {
        do { return try await SCShareableContent.current }
        catch { throw ScreenCaptureError.permissionDenied }
    }

    private func screenshot(filter: SCContentFilter) async throws -> CGImage {
        let configuration = SCStreamConfiguration()
        configuration.showsCursor = false
        let scale = max(1, CGFloat(filter.pointPixelScale))
        configuration.width = max(1, Int(filter.contentRect.width * scale))
        configuration.height = max(1, Int(filter.contentRect.height * scale))
        configuration.pixelFormat = kCVPixelFormatType_32BGRA
        return try await withCheckedThrowingContinuation { continuation in
            SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration) { image, error in
                if let image { continuation.resume(returning: image) }
                else { continuation.resume(throwing: error ?? ScreenCaptureError.captureFailed) }
            }
        }
    }

    @available(macOS 15.2, *)
    private func screenshot(in rect: CGRect) async throws -> CGImage {
        try await withCheckedThrowingContinuation { continuation in
            SCScreenshotManager.captureImage(in: rect) { image, error in
                if let image { continuation.resume(returning: image) }
                else { continuation.resume(throwing: error ?? ScreenCaptureError.captureFailed) }
            }
        }
    }
}

public struct ShareableDisplay: Identifiable, Sendable, Equatable {
    public let id: CGDirectDisplayID
    public let name: String
    public let bounds: CGRect

    public init(id: CGDirectDisplayID, name: String, bounds: CGRect) {
        self.id = id
        self.name = name
        self.bounds = bounds
    }
}

public enum ScreenCaptureTargets {
    public static func displays() -> [ShareableDisplay] {
        NSScreen.screens.compactMap { screen in
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
                return nil
            }
            let id = CGDirectDisplayID(number.uint32Value)
            return ShareableDisplay(id: id, name: screen.localizedName, bounds: CGDisplayBounds(id))
        }
    }

    /// Finds the front-most normal window under the cursor. Callers choose an
    /// excluded owner; Screenshot Studio can deliberately capture DropThings'
    /// own menu-bar controls while other modules may still exclude themselves.
    public static func window(at point: CGPoint, excludingOwnerPID pid: pid_t = getpid()) -> (id: CGWindowID, bounds: CGRect)? {
        let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        for info in list {
            guard let ownerPID = info[kCGWindowOwnerPID as String] as? NSNumber,
                  ownerPID.int32Value != pid,
                  let number = info[kCGWindowNumber as String] as? NSNumber,
                  let boundsDict = info[kCGWindowBounds as String] as? [String: Any],
                  let bounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary),
                  bounds.contains(point), bounds.width > 2, bounds.height > 2 else { continue }
            return (CGWindowID(number.uint32Value), bounds)
        }
        return nil
    }
}
