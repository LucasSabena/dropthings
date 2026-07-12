import DropThingsCore

/// Tracks whether a module's degraded state came specifically from its global
/// shortcut. A later successful registration may then recover that exact
/// failure without accidentally clearing an unrelated platform or data error.
public struct HotkeyRegistrationHealth: Sendable {
    private var failureReason: String?

    public init() {}

    public mutating func failed(reason: String) -> ModuleState {
        failureReason = reason
        return .degraded(reason: reason)
    }

    public mutating func recovered(current state: ModuleState) -> ModuleState {
        guard let failureReason else { return state }
        self.failureReason = nil
        if case .degraded(let currentReason) = state,
           currentReason == failureReason {
            return .running
        }
        return state
    }
}
