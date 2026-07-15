import Foundation

/// Reports free space on a volume. The protocol lets tests inject a fake that
/// simulates "disk full" conditions.
public protocol DiskSpaceChecking: AnyObject, Sendable {
    /// Bytes available for important-use on the volume holding `url`.
    func availableBytes(on url: URL) -> Int64
}

/// Production adapter using `URLResourceValues`.
public final class SystemDiskSpace: DiskSpaceChecking {
    public init() {}

    public func availableBytes(on url: URL) -> Int64 {
        let values = try? url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        return values?.volumeAvailableCapacityForImportantUsage ?? 0
    }
}

/// Fake for tests; returns a fixed value.
public final class FixedDiskSpace: DiskSpaceChecking {
    public let bytes: Int64
    public init(bytes: Int64) { self.bytes = bytes }
    public func availableBytes(on url: URL) -> Int64 { bytes }
}
