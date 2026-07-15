import Foundation

/// Wraps security-scoped resource access so the pipeline can be tested without
/// real bookmarks. The protocol is the narrow adapter; tests inject a fake.
public protocol SecurityScoping: AnyObject, Sendable {
    /// Begin accessing `url`. Returns `true` when access was granted. Always
    /// pair with `endAccess(_:)`.
    func startAccessing(_ url: URL) -> Bool
    /// Release a previously-granted access. Idempotent.
    func endAccess(_ url: URL)
}

/// Production adapter using `URL.startAccessingSecurityScopedResource`. For
/// app-selected files this is a no-op in practice (the app already has access),
/// but for files handed back from security-scoped bookmarks it is required.
public final class SystemSecurityScope: SecurityScoping {
    public init() {}

    public func startAccessing(_ url: URL) -> Bool {
        url.startAccessingSecurityScopedResource()
    }

    public func endAccess(_ url: URL) {
        url.stopAccessingSecurityScopedResource()
    }
}

/// A no-op scope used when the app already owns the URLs (its own containers)
/// or in tests. `startAccessing` always succeeds and `endAccess` does nothing.
public final class NullSecurityScope: SecurityScoping {
    public init() {}
    public func startAccessing(_ url: URL) -> Bool { true }
    public func endAccess(_ url: URL) {}
}
