import Foundation
import os

/// Thin wrapper over `os.Logger` with a fixed subsystem and module-derived
/// category. Use instead of `print` so logs go to Console.app with the right
/// filter and never leak to `stdout`.
public struct ModuleLogger: Sendable {
    public let subsystem: String
    public let category: String
    private let logger: Logger

    public init(subsystem: String = "app.dropthings", category: String) {
        self.subsystem = subsystem
        self.category = category
        self.logger = Logger(subsystem: subsystem, category: category)
    }

    public func debug(_ message: @autoclosure () -> String) {
        let text = message()
        logger.debug("\(text, privacy: .public)")
    }

    public func info(_ message: @autoclosure () -> String) {
        let text = message()
        logger.info("\(text, privacy: .public)")
    }

    public func notice(_ message: @autoclosure () -> String) {
        let text = message()
        logger.notice("\(text, privacy: .public)")
    }

    public func warning(_ message: @autoclosure () -> String) {
        let text = message()
        logger.warning("\(text, privacy: .public)")
    }

    public func error(_ message: @autoclosure () -> String) {
        let text = message()
        logger.error("\(text, privacy: .public)")
    }
}
