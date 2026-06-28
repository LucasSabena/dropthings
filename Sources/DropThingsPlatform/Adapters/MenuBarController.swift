import Foundation
import AppKit
import ApplicationServices

/// Stable snapshot of one menu bar extra (the icon-and-text items in the
/// macOS menu bar other than application menus). Used by `MenuBarController`
/// and the `MenuBarCleaner` module.
public struct MenuBarItem: Identifiable, Hashable, Sendable {
    /// Stable identifier derived from `ownerBundleId:title` so the user's
    /// "hide" choice survives across launches even when the order of items
    /// in the bar changes.
    public let id: String
    public let title: String
    public let ownerBundleId: String?

    public init(id: String, title: String, ownerBundleId: String?) {
        self.id = id
        self.title = title
        self.ownerBundleId = ownerBundleId
    }
}

/// Discovers menu bar items via the Accessibility API and lets the caller
/// toggle each item's visibility. The macOS API does not give us a
/// notification when the menu bar composition changes — callers should
/// re-run `refresh()` after the user installs or removes menu bar apps.
@MainActor
public final class MenuBarController {
    public enum RefreshError: Error, Equatable {
        case accessibilityDenied
        case enumerationFailed
    }

    private var elementsById: [String: AXUIElement] = [:]

    public init() {}

    public var lastDiscoveredIds: [String] {
        Array(elementsById.keys)
    }

    public func refresh() throws -> [MenuBarItem] {
        let systemWide = AXUIElementCreateSystemWide()
        var itemsValue: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            systemWide,
            AXAttributeNames.menuBarExtras as CFString,
            &itemsValue
        )
        guard result == .success else {
            if result == .apiDisabled {
                throw RefreshError.accessibilityDenied
            }
            throw RefreshError.enumerationFailed
        }
        guard let axItems = itemsValue as? [AXUIElement] else {
            return []
        }

        var newCache: [String: AXUIElement] = [:]
        let discovered = axItems.compactMap { element -> MenuBarItem? in
            let title = readTitle(from: element) ?? "Untitled"
            let (pid, bundleId) = readOwner(from: element)
            let stableId = "\(bundleId ?? "pid:\(pid)"):\(title)"
            newCache[stableId] = element
            return MenuBarItem(id: stableId, title: title, ownerBundleId: bundleId)
        }

        elementsById = newCache
        return discovered
    }

    /// Apply the desired hidden state across every cached item. Items in
    /// `hidden` are made invisible; everything else is restored.
    public func applyHidden(_ hidden: Set<String>) {
        for (id, element) in elementsById {
            _ = setVisible(!hidden.contains(id), on: element)
        }
    }

    @discardableResult
    public func setHidden(_ id: String, hidden: Bool) -> Bool {
        guard let element = elementsById[id] else { return false }
        return setVisible(!hidden, on: element)
    }

    public var hasCachedItems: Bool {
        !elementsById.isEmpty
    }

    private func setVisible(_ visible: Bool, on element: AXUIElement) -> Bool {
        let result = AXUIElementSetAttributeValue(
            element,
            AXAttributeNames.visible as CFString,
            visible ? kCFBooleanTrue : kCFBooleanFalse
        )
        return result == .success
    }

    private func readTitle(from element: AXUIElement) -> String? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            element,
            AXAttributeNames.title as CFString,
            &value
        )
        guard result == .success, let value else { return nil }
        return value as? String
    }

    private func readOwner(from element: AXUIElement) -> (pid_t, String?) {
        var pidValue: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            element,
            AXAttributeNames.pid as CFString,
            &pidValue
        )
        guard result == .success else { return (0, nil) }
        guard let number = pidValue as? NSNumber else { return (0, nil) }
        let pid = pid_t(number.int32Value)
        guard pid > 0 else { return (0, nil) }
        let bundleId = NSRunningApplication(processIdentifier: pid)?.bundleIdentifier
        return (pid, bundleId)
    }
}

/// String constants for the Accessibility attributes we use. Declared as
/// plain `String` so we do not depend on the Swift overlay exposing the C
/// macros — they vary across SDK versions.
private enum AXAttributeNames {
    static let menuBarExtras = "AXMenuBarExtras"
    static let title = "AXTitle"
    static let pid = "AXPid"
    static let visible = "AXVisible"
}

private extension NSNumber {
    var pidValue: pid_t { pid_t(truncating: self) }
}
