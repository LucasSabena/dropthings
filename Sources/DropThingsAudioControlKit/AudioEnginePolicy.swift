import Foundation

public struct AudioEngineCrashPolicy: Sendable {
    public let maximumRestarts: Int
    public let window: TimeInterval
    public let initialDelay: TimeInterval
    public let maximumDelay: TimeInterval

    public init(maximumRestarts: Int = 3, window: TimeInterval = 60, initialDelay: TimeInterval = 0.5, maximumDelay: TimeInterval = 8) {
        self.maximumRestarts = maximumRestarts
        self.window = window
        self.initialDelay = initialDelay
        self.maximumDelay = maximumDelay
    }

    public func decision(after failures: [Date], now: Date = Date()) -> AudioEngineRestartDecision {
        let recent = failures.filter { now.timeIntervalSince($0) <= window }
        guard recent.count < maximumRestarts else { return .cutoff }
        let exponent = max(0, recent.count - 1)
        return .restart(after: min(maximumDelay, initialDelay * pow(2, Double(exponent))))
    }
}

public enum AudioEngineRestartDecision: Equatable, Sendable {
    case restart(after: TimeInterval)
    case cutoff
}

public enum OwnedAudioResource {
    public static let uidPrefix = "app.dropthings.audio."

    public static func isOwned(uid: String, sessionID: UUID? = nil) -> Bool {
        guard uid.hasPrefix(uidPrefix) else { return false }
        guard let sessionID else { return true }
        return uid.contains(sessionID.uuidString.lowercased())
    }
}
