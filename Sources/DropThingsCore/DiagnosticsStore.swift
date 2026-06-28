import Foundation
import Combine
import os

/// Severity used by `DiagnosticsStore`. Mirrors `os.log` levels minus `debug`
/// (kept out of the UI buffer to reduce noise).
public enum LogLevel: String, Codable, Sendable, CaseIterable {
    case info
    case notice
    case warning
    case error
}

public struct LogEntry: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let level: LogLevel
    public let category: String
    public let message: String

    public init(level: LogLevel, category: String, message: String, timestamp: Date = Date()) {
        self.id = UUID()
        self.timestamp = timestamp
        self.level = level
        self.category = category
        self.message = message
    }
}

/// Bounded ring buffer of recent log entries for the diagnostics screen.
/// Long-term logs still go to `os.Logger` and Console.app; this store is for
/// the in-app surface only.
@MainActor
public final class DiagnosticsStore: ObservableObject {
    public static let maxEntries = 500

    @Published public private(set) var entries: [LogEntry] = []

    private let logger = ModuleLogger(subsystem: "app.dropthings", category: "diagnostics")

    public init() {}

    public func record(level: LogLevel = .info, category: String, message: String) {
        let entry = LogEntry(level: level, category: category, message: message)
        entries.append(entry)
        if entries.count > Self.maxEntries {
            entries.removeFirst(entries.count - Self.maxEntries)
        }
    }

    public func clear() {
        entries.removeAll()
    }

    /// Mirror `record` into `os.Logger` so it also lands in Console.app.
    public func recordAndLog(level: LogLevel, category: String, message: String) {
        record(level: level, category: category, message: message)
        switch level {
        case .info: logger.info(message)
        case .notice: logger.notice(message)
        case .warning: logger.warning(message)
        case .error: logger.error(message)
        }
    }
}
